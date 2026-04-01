import Combine
import Foundation
import OCIExplorerCore
import OCIExplorerServices

enum PARListState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case error(String)
}

struct PARToast: Equatable, Identifiable {
    let id = UUID()
    let message: String
    let actionTitle: String?
    let par: PARSummary?
}

enum PARDisplayScope: String, CaseIterable, Identifiable {
    case bucket
    case object

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bucket: return L10n.string("par.scope.bucket")
        case .object: return L10n.string("par.scope.object")
        }
    }
}

struct CreatePARDraft: Equatable {
    var scope: PARDisplayScope
    var name: String
    var accessType: PARAccessType
    var expiresAt: Date
    var objectName: String

    init(selectedObjectName: String?) {
        let object = selectedObjectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scope = object == nil ? .bucket : .object
        self.name = ""
        self.accessType = object == nil ? .anyObjectRead : .objectRead
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        self.objectName = object ?? ""
    }
}

@MainActor
final class PARManagementViewModel: ObservableObject {
    @Published private(set) var pars: [PARSummary] = []
    @Published private(set) var state: PARListState = .idle
    @Published var isCreateModalPresented = false
    @Published var isRefreshing = false
    @Published var isCreating = false
    @Published var draft: CreatePARDraft
    @Published var toast: PARToast?
    @Published var inlineErrorMessage: String?

    let bucketName: String
    let selectedObjectName: String?

    private let auth: OCIAuthenticationConfig
    private let service: OCIObjectStorageServiceProtocol
    private let historyStore: PARHistoryStoreProtocol
    private let logger: AppLogger

    init(
        bucketName: String,
        selectedObjectName: String?,
        auth: OCIAuthenticationConfig,
        service: OCIObjectStorageServiceProtocol,
        historyStore: PARHistoryStoreProtocol,
        logger: AppLogger
    ) {
        self.bucketName = bucketName
        self.selectedObjectName = selectedObjectName
        self.auth = auth
        self.service = service
        self.historyStore = historyStore
        self.logger = logger
        self.draft = CreatePARDraft(selectedObjectName: selectedObjectName)
        loadLocalState()
    }

    var title: String {
        L10n.string("par.title")
    }

    var subtitle: String {
        L10n.string("par.subtitle", bucketName)
    }

    var emptyTitle: String {
        L10n.string("par.empty.title")
    }

    var emptyMessage: String {
        L10n.string("par.empty.message")
    }

    var availableAccessTypes: [PARAccessType] {
        switch draft.scope {
        case .bucket:
            return [.anyObjectRead, .anyObjectWrite, .anyObjectReadWrite]
        case .object:
            return [.objectRead, .objectWrite, .objectReadWrite]
        }
    }

    var expirationDescription: String {
        let components = Calendar.current.dateComponents([.day, .hour], from: .now, to: draft.expiresAt)
        if let day = components.day, day > 0 {
            return day == 1 ? L10n.string("par.field.expiration.helper.one_day") : L10n.string("par.field.expiration.helper.days", day)
        }
        if let hour = components.hour, hour > 0 {
            return hour == 1 ? L10n.string("par.field.expiration.helper.one_hour") : L10n.string("par.field.expiration.helper.hours", hour)
        }
        return L10n.string("par.field.expiration.helper.imminent")
    }

    func openCreateModal() {
        inlineErrorMessage = nil
        draft = CreatePARDraft(selectedObjectName: selectedObjectName)
        isCreateModalPresented = true
    }

    func dismissCreateModal() {
        inlineErrorMessage = nil
        isCreateModalPresented = false
    }

    func refresh() async {
        isRefreshing = true
        if pars.isEmpty {
            state = .loading
        }
        defer { isRefreshing = false }

        do {
            let remote = try await service.listPreAuthenticatedRequests(bucketName: bucketName, using: auth)
            mergeAndPersist(remote)
            inlineErrorMessage = nil
        } catch {
            logger.log(.warning, category: "PAR", message: L10n.string("par.log.refresh_remote"), metadata: ["bucket": bucketName, "error": AppError.from(error).localizedDescription])
            loadLocalState()
            if pars.isEmpty {
                state = .empty
            }
        }
    }

    func createPAR() async {
        inlineErrorMessage = nil
        isCreating = true
        defer { isCreating = false }

        do {
            let request = try buildCreateRequest()
            let created = try await service.createPreAuthenticatedRequest(bucketName: bucketName, request: request, using: auth)
            upsert(created)
            toast = PARToast(message: L10n.string("par.toast.created"), actionTitle: L10n.string("par.toast.copy_link"), par: created)
            isCreateModalPresented = false
            await refresh()
        } catch {
            inlineErrorMessage = AppError.from(error).localizedDescription
        }
    }

    func deletePAR(_ par: PARSummary) async {
        do {
            try await service.deletePreAuthenticatedRequest(bucketName: bucketName, parID: par.id, using: auth)
            pars.removeAll { $0.id == par.id }
            try? historyStore.remove(id: par.id)
            updateState()
            toast = PARToast(message: L10n.string("par.toast.removed"), actionTitle: nil, par: nil)
        } catch {
            inlineErrorMessage = AppError.from(error).localizedDescription
        }
    }

    func copyURL(for par: PARSummary) {
        guard let url = par.fullPath else { return }
        NativeDialogs.copyToPasteboard(url)
        toast = PARToast(message: L10n.string("par.toast.copied"), actionTitle: nil, par: nil)
    }

    func consumeToast() {
        toast = nil
    }

    private func loadLocalState() {
        let history = (try? historyStore.loadHistory()) ?? []
        pars = history
            .filter { $0.bucketName == bucketName || $0.bucketName == nil }
            .sorted { ($0.timeCreated ?? .distantPast) > ($1.timeCreated ?? .distantPast) }
        updateState()
    }

    private func updateState() {
        if pars.isEmpty {
            state = .empty
        } else {
            state = .loaded
        }
    }

    private func buildCreateRequest() throws -> CreatePARRequestModel {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AppError.validation(L10n.string("par.validation.name_required"))
        }

        let objectName = draft.objectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.scope == .object, objectName.isEmpty {
            throw AppError.validation(L10n.string("par.validation.object_required"))
        }

        let accessType = availableAccessTypes.contains(draft.accessType) ? draft.accessType : defaultAccessType
        let bucketListingAction: String?
        if draft.scope == .bucket, accessType == .anyObjectRead || accessType == .anyObjectReadWrite {
            bucketListingAction = "ListObjects"
        } else {
            bucketListingAction = nil
        }

        return CreatePARRequestModel(
            name: trimmedName,
            accessType: accessType,
            expiresAt: draft.expiresAt,
            objectName: draft.scope == .object ? objectName : nil,
            bucketListingAction: bucketListingAction
        )
    }

    private var defaultAccessType: PARAccessType {
        switch draft.scope {
        case .bucket: return .anyObjectRead
        case .object: return .objectRead
        }
    }

    private func mergeAndPersist(_ remote: [PARSummary]) {
        var merged = Dictionary(uniqueKeysWithValues: pars.map { ($0.id, $0) })
        for item in remote {
            merged[item.id] = item
        }
        let values = Array(merged.values)
            .filter { $0.bucketName == bucketName || $0.bucketName == nil }
            .sorted { ($0.timeCreated ?? .distantPast) > ($1.timeCreated ?? .distantPast) }
        pars = values
        persistBucketScoped(values)
        updateState()
    }

    private func upsert(_ par: PARSummary) {
        if let index = pars.firstIndex(where: { $0.id == par.id }) {
            pars[index] = par
        } else {
            pars.insert(par, at: 0)
        }
        persistBucketScoped(pars)
        updateState()
    }

    private func persistBucketScoped(_ bucketItems: [PARSummary]) {
        let existing = (try? historyStore.loadHistory()) ?? []
        let retained = existing.filter { $0.bucketName != bucketName && $0.bucketName != nil }
        try? historyStore.save(retained + bucketItems)
    }
}

extension PARSummary {
    var scopeTitle: String {
        if let objectName, !objectName.isEmpty {
            return L10n.string("par.scope.object")
        }
        return L10n.string("par.scope.bucket")
    }

    var accessTitle: String {
        switch accessType {
        case PARAccessType.objectRead.rawValue, PARAccessType.anyObjectRead.rawValue:
            return L10n.string("par.access.read")
        case PARAccessType.objectWrite.rawValue, PARAccessType.anyObjectWrite.rawValue:
            return L10n.string("par.access.write")
        default:
            return L10n.string("par.access.read_write")
        }
    }

    var isExpired: Bool {
        guard let timeExpires else { return false }
        return timeExpires < .now
    }

    var statusTitle: String {
        isExpired ? L10n.string("par.status.expired") : L10n.string("par.status.active")
    }

    var truncatedURL: String {
        guard let fullPath else { return accessURI }
        guard fullPath.count > 72 else { return fullPath }
        return "\(fullPath.prefix(48))...\(fullPath.suffix(18))"
    }
}
