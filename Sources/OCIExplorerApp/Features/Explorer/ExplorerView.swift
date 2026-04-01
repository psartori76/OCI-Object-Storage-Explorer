import SwiftUI
import OCIExplorerCore
import UniformTypeIdentifiers

struct ExplorerView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    let onDisconnect: () -> Void

    @State private var showingCreateBucketSheet = false
    @State private var showingCreateFolderSheet = false
    @State private var parManagementSheet: PARSheetContext?
    @State private var showingTransferSheet = false
    @State private var showingDiagnostics = false
    @State private var newBucketRequest = CreateBucketRequestModel()
    @State private var newFolderName = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        HSplitView {
            BucketSidebarView(
                viewModel: viewModel,
                showingCreateBucketSheet: $showingCreateBucketSheet
            )
            .frame(minWidth: 272, idealWidth: 292, maxWidth: 340)

            explorerContent
                .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.appBackground)

            InspectorPanelView(viewModel: viewModel)
                .frame(minWidth: 308, idealWidth: 330, maxWidth: 380)
        }
        .navigationTitle(viewModel.currentLocationTitle)
        .toolbar { explorerToolbar }
        .sheet(isPresented: $showingCreateBucketSheet) {
            createBucketSheet
        }
        .sheet(isPresented: $showingCreateFolderSheet) {
            createFolderSheet
        }
        .sheet(item: $parManagementSheet) { context in
            PARManagementSheet(viewModel: context.viewModel)
                .frame(minWidth: 920, idealWidth: 980, minHeight: 620)
        }
        .sheet(isPresented: $showingTransferSheet) {
            TransferQueueView(coordinator: viewModel.transferCoordinator)
                .frame(minWidth: 720, minHeight: 420)
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView(logger: viewModel.diagnosticLogger)
                .frame(minWidth: 840, minHeight: 540)
        }
        .sheet(isPresented: $viewModel.isShowingVersionsSheet) {
            ObjectVersionsSheet(viewModel: viewModel)
                .frame(minWidth: 760, minHeight: 460)
        }
        .overlay(alignment: .bottom) {
            if let toastMessage = viewModel.toastMessage {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BrandColors.success)
                    Text(toastMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colorScheme == .dark ? BrandColors.successToastText : BrandColors.successToastText)
                        .lineLimit(2)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(colorScheme == .dark ? BrandColors.successToastDark : BrandColors.successToastLight, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(theme.borderSubtle, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 20, y: 8)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(ExplorerBackgroundView())
        .animation(.snappy(duration: 0.24, extraBounce: 0.05), value: viewModel.toastMessage)
        .animation(.snappy(duration: 0.24, extraBounce: 0.03), value: viewModel.banner)
    }

    private var explorerContent: some View {
        VStack(spacing: 0) {
            ExplorerHeaderView(viewModel: viewModel)

            if let banner = viewModel.banner {
                ErrorBannerView(
                    title: banner.title,
                    message: banner.message,
                    retryTitle: L10n.string("explorer.banner.retry")
                ) {
                    Task { await viewModel.retryAfterError() }
                } onDismiss: {
                    viewModel.clearBanner()
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Group {
                switch viewModel.contentState {
                case .idle:
                    EmptyStateView(
                        systemImage: "externaldrive",
                        title: L10n.string("explorer.empty.select_bucket.title"),
                        message: L10n.string("explorer.empty.select_bucket.message")
                    )
                case .loading:
                    ExplorerLoadingView(title: L10n.string("explorer.loading.bucket"))
                case .error:
                    EmptyStateView(
                        systemImage: "exclamationmark.triangle",
                        title: L10n.string("explorer.error.load_objects.title"),
                        message: L10n.string("explorer.error.load_objects.message")
                    )
                case .empty:
                    if viewModel.buckets.isEmpty {
                        RegionWithoutBucketsView(
                            viewModel: viewModel,
                            onCreateBucket: { showingCreateBucketSheet = true }
                        )
                    } else {
                        EmptyStateView(
                            systemImage: viewModel.searchText.isEmpty ? "folder" : "magnifyingglass",
                            title: viewModel.emptyStateTitle,
                            message: viewModel.emptyStateMessage
                        )
                    }
                case .loaded:
                    ObjectListView(viewModel: viewModel) {
                        if let manager = viewModel.makePARManagementViewModel() {
                            parManagementSheet = PARSheetContext(viewModel: manager)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    @ToolbarContentBuilder
    private var explorerToolbar: some ToolbarContent {
        ToolbarItemGroup {
            ControlGroup {
                Button {
                    Task { await viewModel.queueUploads() }
                } label: {
                    Label(L10n.string("common.upload"), systemImage: "arrow.up")
                }
                .help(L10n.string("explorer.toolbar.upload.help"))
                .disabled(viewModel.selectedBucket == nil)

                Button {
                    Task { await viewModel.queueDownloads() }
                } label: {
                    Label(L10n.string("common.download"), systemImage: "arrow.down")
                }
                .help(L10n.string("explorer.toolbar.download.help"))
                .disabled(!viewModel.canDownloadSelection)

                Button {
                    showingCreateFolderSheet = true
                } label: {
                    Label(L10n.string("explorer.toolbar.new_folder"), systemImage: "folder.badge.plus")
                }
                .help(L10n.string("explorer.toolbar.new_folder.help"))
                .disabled(viewModel.selectedBucket == nil)

                Button(role: .destructive) {
                    Task { await viewModel.deleteSelectedObjects() }
                } label: {
                    Label(L10n.string("explorer.toolbar.delete"), systemImage: "trash")
                }
                .help(L10n.string("explorer.toolbar.delete.help"))
                .disabled(!viewModel.canDeleteSelection)

                Button {
                    Task { await viewModel.showVersionsForSelectedObject() }
                } label: {
                    Label(L10n.string("explorer.toolbar.view_versions"), systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
                .help(L10n.string("explorer.toolbar.view_versions.help"))
                .disabled(!viewModel.canShowVersionsForSelection)
            }

            ControlGroup {
                Button {
                    Task { await viewModel.refreshCurrentPrefix() }
                } label: {
                    Label(L10n.string("common.refresh"), systemImage: "arrow.clockwise")
                }
                .help(L10n.string("explorer.toolbar.refresh.help"))
                .disabled(viewModel.selectedBucket == nil)
            }

            ControlGroup {
                Button {
                    if let manager = viewModel.makePARManagementViewModel() {
                        parManagementSheet = PARSheetContext(viewModel: manager)
                    }
                } label: {
                    Label(L10n.string("explorer.toolbar.create_par"), systemImage: "link.badge.plus")
                }
                .help(L10n.string("explorer.toolbar.create_par.help"))
                .disabled(!viewModel.canCreatePARForSelection && viewModel.selectedBucket == nil)
            }

            Menu {
                Button {
                    showingTransferSheet = true
                } label: {
                    Label(L10n.string("explorer.toolbar.transfer_queue"), systemImage: "tray.full")
                }

                Button {
                    showingDiagnostics = true
                } label: {
                    Label(L10n.string("common.diagnostics"), systemImage: "waveform.path.ecg")
                }
            } label: {
                Label(L10n.string("common.more"), systemImage: "ellipsis.circle")
            }
            .help(L10n.string("explorer.toolbar.more.help"))
        }

        ToolbarItem(placement: .automatic) {
            Button(L10n.string("common.disconnect")) {
                onDisconnect()
            }
            .help(L10n.string("explorer.toolbar.disconnect.help"))
        }
    }

    private var createBucketSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.string("explorer.create_bucket.title"))
                .font(.title2.weight(.semibold))

            AppSectionCard(title: L10n.string("explorer.create_bucket.section")) {
                VStack(spacing: 14) {
                    AppTextField(
                        L10n.string("explorer.create_bucket.name"),
                        placeholder: L10n.string("explorer.create_bucket.name.placeholder"),
                        text: $newBucketRequest.name
                    )
                    AppTextField(
                        L10n.string("explorer.create_bucket.compartment"),
                        placeholder: "ocid1.compartment.oc1...",
                        text: $newBucketRequest.compartmentID
                    )
                    AppPickerField(L10n.string("bucket.storage_tier"), selection: $newBucketRequest.storageTier) {
                        ForEach(BucketStorageTier.allCases) { tier in
                            Text(LocalizedDisplayValue.bucketStorageTier(tier)).tag(tier)
                        }
                    }
                    AppPickerField(L10n.string("bucket.public_access"), selection: $newBucketRequest.publicAccessType) {
                        Text(LocalizedDisplayValue.publicAccess("NoPublicAccess")).tag("NoPublicAccess")
                        Text(LocalizedDisplayValue.publicAccess("ObjectRead")).tag("ObjectRead")
                    }
                }
            }

            HStack {
                Spacer()
                Button(L10n.string("common.cancel")) {
                    showingCreateBucketSheet = false
                    newBucketRequest = CreateBucketRequestModel()
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
                Button(L10n.string("explorer.create_bucket.submit")) {
                    Task {
                        if newBucketRequest.compartmentID.isEmpty {
                            newBucketRequest.compartmentID = viewModel.currentAuth.compartmentOCID
                        }
                        await viewModel.createBucket(request: newBucketRequest)
                        newBucketRequest = CreateBucketRequestModel()
                        showingCreateBucketSheet = false
                    }
                }
                .buttonStyle(AppButtonStyle(kind: .primary))
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private var createFolderSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.string("explorer.create_folder.title"))
                .font(.title2.weight(.semibold))

            AppSectionCard(title: L10n.string("explorer.create_folder.section")) {
                AppTextField(
                    L10n.string("explorer.create_folder.name"),
                    placeholder: L10n.string("explorer.create_folder.name.placeholder"),
                    text: $newFolderName
                )
            }

            HStack {
                Spacer()
                Button(L10n.string("common.cancel")) {
                    newFolderName = ""
                    showingCreateFolderSheet = false
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
                Button(L10n.string("explorer.create_folder.submit")) {
                    Task {
                        await viewModel.createFolder(named: newFolderName)
                        newFolderName = ""
                        showingCreateFolderSheet = false
                    }
                }
                .buttonStyle(AppButtonStyle(kind: .primary))
                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct PARSheetContext: Identifiable {
    let id = UUID()
    let viewModel: PARManagementViewModel
}

private struct ExplorerBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        ZStack {
            theme.appBackground
            AppGradients.brandHeroGradient
                .opacity(0.05)
                .blur(radius: 50)
        }
        .ignoresSafeArea()
    }
}

private struct RegionWithoutBucketsView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    let onCreateBucket: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(theme.elevatedBackground)
                        .frame(width: 76, height: 76)
                    Image(systemName: "shippingbox")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }

                VStack(spacing: 8) {
                    Text(L10n.string("explorer.region.empty.title"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(L10n.string("explorer.region.empty.message"))
                        .font(.body)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Picker(L10n.string("common.region"), selection: Binding(
                        get: { viewModel.selectedRegionCode },
                        set: { newValue in
                            Task { await viewModel.changeRegion(to: newValue) }
                        }
                    )) {
                        ForEach(viewModel.availableRegions) { region in
                            Text(region.displayName).tag(region.regionCode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.elevatedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.borderSubtle, lineWidth: 1)
                    )
                }
                .frame(maxWidth: 360, alignment: .leading)

                HStack(spacing: 12) {
                    Button(L10n.string("explorer.create_bucket.submit")) {
                        onCreateBucket()
                    }
                    .buttonStyle(AppButtonStyle(kind: .primary))

                    Button(L10n.string("explorer.region.refresh")) {
                        Task { await viewModel.refreshBuckets() }
                    }
                    .buttonStyle(AppButtonStyle(kind: .secondary))
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct BucketSidebarView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    @Binding var showingCreateBucketSheet: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Picker(L10n.string("common.region"), selection: Binding(
                    get: { viewModel.selectedRegionCode },
                    set: { newValue in
                        Task { await viewModel.changeRegion(to: newValue) }
                    }
                )) {
                    ForEach(viewModel.availableRegions) { region in
                        Text(region.displayName).tag(region.regionCode)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(viewModel.currentRegionDisplayName)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.elevatedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.borderSubtle, lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("explorer.sidebar.buckets"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(L10n.plural("count.available_buckets", count: viewModel.buckets.count))
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                if viewModel.isLoadingBuckets {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    showingCreateBucketSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(BrandColors.brandBluePrimary)
                }
                .buttonStyle(.plain)
                .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(theme.borderSubtle, lineWidth: 1)
                )
                .help(L10n.string("explorer.sidebar.create_bucket.help"))
            }
            .padding(.horizontal, 16)

            List(selection: Binding(
                get: { viewModel.selectedBucketID },
                set: { newValue in
                    Task { await viewModel.selectBucket(id: newValue) }
                }
            )) {
                ForEach(viewModel.buckets) { bucket in
                    HStack(spacing: 10) {
                        Image(systemName: "shippingbox.fill")
                            .foregroundStyle(viewModel.selectedBucketID == bucket.id ? (colorScheme == .dark ? BrandColors.brandBlueLight : BrandColors.brandBluePrimary) : theme.textTertiary)
                        Text(bucket.name)
                            .font(.body.weight(viewModel.selectedBucketID == bucket.id ? .semibold : .regular))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(.vertical, 4)
                    .tag(bucket.id)
                    .contextMenu {
                        Button(L10n.string("common.copy_name")) {
                            NativeDialogs.copyToPasteboard(bucket.name)
                        }
                        Button(L10n.string("common.refresh")) {
                            Task { await viewModel.refreshBuckets() }
                        }
                        Button(L10n.string("explorer.sidebar.delete_bucket"), role: .destructive) {
                            viewModel.selectedBucketID = bucket.id
                            Task { await viewModel.deleteSelectedBucket() }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .overlay {
                if !viewModel.isLoadingBuckets && viewModel.buckets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                        Text(L10n.string("explorer.region.empty.title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                        Text(L10n.string("explorer.sidebar.empty.message"))
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(minWidth: 240)
        .background(theme.sidebarBackground)
    }
}

private struct ExplorerHeaderView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                BreadcrumbView(viewModel: viewModel)

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(theme.textTertiary)
                        TextField(viewModel.currentSearchPlaceholder, text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .frame(width: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.searchBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.borderSubtle, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .background(
            Rectangle()
                .fill(theme.toolbarBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.borderSubtle)
                        .frame(height: 1)
                }
        )
    }
}

private struct BreadcrumbView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        HStack(spacing: 6) {
            if let bucket = viewModel.selectedBucket {
                Button(bucket.name) {
                    Task { await viewModel.navigateToRoot() }
                }
                .buttonStyle(.link)
                .foregroundStyle(BrandColors.brandBluePrimary)

                ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.offset) { index, breadcrumb in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(theme.textTertiary)
                    Button(breadcrumb) {
                        Task { await viewModel.navigateToBreadcrumb(index: index) }
                    }
                    .buttonStyle(.link)
                    .foregroundStyle(BrandColors.brandBluePrimary)
                }
            } else {
                Text(L10n.string("explorer.breadcrumb.choose_bucket"))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .font(.subheadline.weight(.medium))
    }
}

private struct ObjectNameCell: View {
    let item: ObjectBrowserItem
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconBackgroundColor)
                    .frame(width: 28, height: 28)
                Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.isFolder ? BrandColors.brandBluePrimary : theme.textSecondary)
            }

            Text(item.name)
                .font(.body.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(theme.textPrimary)
                .help(item.name)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var iconBackgroundColor: Color {
        let theme = AppTheme.current(for: colorScheme)
        return isHovered ? theme.tableHover : theme.elevatedBackground
    }
}

private struct StorageTierTag: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(title == "—" ? theme.textTertiary : theme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.elevatedBackground)
            )
    }
}

private struct ObjectListView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    let onCreatePAR: () -> Void

    @State private var isDropTargeted = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        ZStack {
            Table(
                viewModel.filteredItems,
                selection: Binding(
                    get: { viewModel.selectedItemIDs },
                    set: { viewModel.updateSelection($0) }
                )
            ) {
                TableColumn(L10n.string("explorer.table.name")) { item in
                    ObjectNameCell(item: item)
                }
                .width(min: 320, ideal: 420)

                TableColumn(L10n.string("explorer.table.size")) { item in
                    HStack {
                        Spacer(minLength: 0)
                        Text(item.size.friendlyByteText)
                            .monospacedDigit()
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .width(min: 100, ideal: 120)

                TableColumn(L10n.string("explorer.table.type")) { item in
                    Text(LocalizedDisplayValue.fileKind(isFolder: item.isFolder))
                        .foregroundStyle(theme.textSecondary)
                }
                .width(min: 100, ideal: 120)

                TableColumn(L10n.string("explorer.table.modified")) { item in
                    HStack {
                        Spacer(minLength: 0)
                        Text(item.modifiedAt.friendlyDateText)
                            .monospacedDigit()
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .width(min: 160, ideal: 190)

                TableColumn(L10n.string("explorer.table.tier")) { item in
                    StorageTierTag(title: LocalizedDisplayValue.bucketStorageTier(rawValue: item.storageTier))
                }
                .width(min: 90, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
            .contextMenu(forSelectionType: String.self) { selectedIDs in
                contextMenu(for: selectedIDs)
            } primaryAction: { selectedIDs in
                guard selectedIDs.count == 1,
                      let selectedID = selectedIDs.first,
                      let item = viewModel.items.first(where: { $0.id == selectedID }) else { return }
                if item.isFolder {
                    Task { await viewModel.navigate(to: item) }
                }
            }
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                handleFileDrop(providers: providers)
            }

            if isDropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .fill(BrandColors.brandBluePrimary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(BrandColors.brandBluePrimary.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    )
                    .padding(12)
                    .allowsHitTesting(false)

                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(BrandColors.brandBluePrimary)
                    Text(L10n.string("explorer.drop_target"))
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                }
                .padding(24)
                .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.borderSubtle, lineWidth: 1)
                )
                .allowsHitTesting(false)
            }
        }
        .animation(.snappy(duration: 0.22, extraBounce: 0.02), value: isDropTargeted)
    }

    @ViewBuilder
    private func contextMenu(for selection: Set<String>) -> some View {
        let effectiveSelection = selection.isEmpty ? viewModel.selectedItemIDs : selection
        let selectedItems = viewModel.items.filter { effectiveSelection.contains($0.id) }
        let selectedFiles = selectedItems.filter { !$0.isFolder }

        if !selectedFiles.isEmpty {
            Button(selectedFiles.count == 1 ? L10n.string("common.download") : L10n.plural("count.download_action", count: selectedFiles.count)) {
                viewModel.updateSelection(Set(selectedFiles.map(\.id)))
                Task { await viewModel.queueDownloads() }
            }

            Button(selectedFiles.count == 1 ? L10n.string("common.copy_name") : L10n.string("common.copy_names")) {
                viewModel.updateSelection(effectiveSelection)
                viewModel.copySelectedObjectName()
            }

            Button(selectedFiles.count == 1 ? L10n.string("common.copy_path") : L10n.string("common.copy_paths")) {
                viewModel.updateSelection(effectiveSelection)
                viewModel.copySelectedObjectPath()
            }

            if selectedFiles.count == 1 {
                Button(L10n.string("explorer.toolbar.create_par")) {
                    viewModel.updateSelection(effectiveSelection)
                    onCreatePAR()
                }

                Button(L10n.string("explorer.toolbar.view_versions")) {
                    viewModel.updateSelection(effectiveSelection)
                    Task { await viewModel.showVersionsForSelectedObject() }
                }
            }

            Divider()

            Button(selectedFiles.count == 1 ? L10n.string("explorer.toolbar.delete") : L10n.string("explorer.context.delete_selected"), role: .destructive) {
                viewModel.updateSelection(effectiveSelection)
                Task { await viewModel.deleteSelectedObjects() }
            }
        }
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        Task {
            let urls = await loadFileURLs(from: providers)
            await viewModel.queueUploads(from: urls)
        }
        return true
    }

    private func loadFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        return urls
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            if provider.canLoadObject(ofClass: NSURL.self) {
                provider.loadObject(ofClass: NSURL.self) { object, _ in
                    let url = (object as? NSURL).map { $0 as URL }
                    continuation.resume(returning: url)
                }
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}

private struct InspectorPanelView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let bucket = viewModel.selectedBucket, let details = viewModel.bucketDetails {
                    InspectorSectionView(title: L10n.string("explorer.inspector.bucket")) {
                        InspectorValueRow(title: L10n.string("common.name"), value: bucket.name)
                        InspectorValueRow(title: L10n.string("common.namespace"), value: details.namespace)
                        InspectorValueRow(title: L10n.string("common.region"), value: viewModel.currentRegionDisplayName)
                        InspectorValueRow(title: L10n.string("common.created_at"), value: details.createdAt.friendlyDateText)
                    }

                    InspectorSectionView(title: L10n.string("explorer.inspector.configuration")) {
                        InspectorValueRow(title: L10n.string("bucket.storage_tier"), value: LocalizedDisplayValue.bucketStorageTier(rawValue: details.storageTier))
                        InspectorValueRow(title: L10n.string("common.versioning"), value: LocalizedDisplayValue.versioning(details.versioning))
                        InspectorValueRow(title: L10n.string("common.public_access"), value: LocalizedDisplayValue.publicAccess(details.publicAccessType))
                        InspectorValueRow(
                            title: L10n.string("common.compartment"),
                            value: viewModel.abbreviated(details.compartmentID),
                            copyValue: details.compartmentID
                        )
                    }
                }

                InspectorSectionView(title: L10n.string("explorer.inspector.object_selected")) {
                    if viewModel.objectDetailsState == .loading {
                        VStack(alignment: .leading, spacing: 10) {
                            ProgressView()
                            Text(L10n.string("explorer.inspector.loading_details"))
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                        }
                    } else if viewModel.selectedObjects.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.plural("count.selected_items", count: viewModel.selectedObjects.count))
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                            Text(L10n.string("explorer.inspector.multiple_actions"))
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)

                            HStack(spacing: 10) {
                                Button(L10n.string("common.copy_names")) {
                                    viewModel.copySelectedObjectName()
                                }
                                .buttonStyle(AppButtonStyle(kind: .secondary))

                                Button(L10n.string("common.copy_paths")) {
                                    viewModel.copySelectedObjectPath()
                                }
                                .buttonStyle(AppButtonStyle(kind: .secondary))

                                Button(L10n.string("common.delete"), role: .destructive) {
                                    Task { await viewModel.deleteSelectedObjects() }
                                }
                                .buttonStyle(AppButtonStyle(kind: .destructive))
                            }
                        }
                    } else if let selectedObject = viewModel.selectedPrimaryItem, let metadata = viewModel.selectedObjectMetadata {
                        InspectorValueRow(title: L10n.string("common.name"), value: selectedObject.name, copyValue: selectedObject.name)
                        InspectorValueRow(title: L10n.string("explorer.inspector.path"), value: selectedObject.fullPath, copyValue: selectedObject.fullPath)
                        InspectorValueRow(title: L10n.string("common.size"), value: metadata.size.friendlyByteText)
                        InspectorValueRow(title: L10n.string("common.type"), value: metadata.contentType ?? L10n.string("common.file"))
                        InspectorValueRow(title: L10n.string("explorer.inspector.last_modified"), value: metadata.modifiedAt.friendlyDateText)
                        InspectorValueRow(title: L10n.string("explorer.inspector.etag"), value: viewModel.abbreviated(metadata.etag), copyValue: metadata.etag)
                        InspectorValueRow(title: L10n.string("explorer.table.tier"), value: LocalizedDisplayValue.bucketStorageTier(rawValue: metadata.storageTier ?? selectedObject.storageTier))
                        InspectorValueRow(title: L10n.string("common.versioning"), value: viewModel.isBucketVersioningEnabled ? L10n.string("common.enabled") : L10n.string("common.disabled"))
                        InspectorValueRow(title: L10n.string("common.versions"), value: viewModel.selectedObjectVersionsCountText)

                        HStack(spacing: 10) {
                            Button(L10n.string("common.copy_name")) {
                                viewModel.copySelectedObjectName()
                            }
                            .buttonStyle(AppButtonStyle(kind: .secondary))

                            Button(L10n.string("common.copy_path")) {
                                viewModel.copySelectedObjectPath()
                            }
                            .buttonStyle(AppButtonStyle(kind: .secondary))

                            Button(L10n.string("explorer.toolbar.view_versions")) {
                                Task { await viewModel.showVersionsForSelectedObject() }
                            }
                            .buttonStyle(AppButtonStyle(kind: .secondary))

                            Button(L10n.string("common.delete"), role: .destructive) {
                                Task { await viewModel.deleteSelectedObjects() }
                            }
                            .buttonStyle(AppButtonStyle(kind: .destructive))
                        }
                        .padding(.top, 4)
                    } else if let objectDetailsError = viewModel.objectDetailsError {
                        Text(objectDetailsError)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    } else {
                        Text(L10n.string("explorer.inspector.select_file"))
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 300)
        .background(theme.inspectorBackground)
    }
}

private struct ObjectVersionsSheet: View {
    @ObservedObject var viewModel: ExplorerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("explorer.versions.title"))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(viewModel.selectedObject?.name ?? L10n.string("common.object_selected"))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Button(L10n.string("common.close")) {
                    dismiss()
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
            }

            Group {
                switch viewModel.objectVersionsState {
                case .idle, .loading:
                    ExplorerLoadingView(title: L10n.string("explorer.versions.loading"))
                case .disabled:
                    EmptyStateView(
                        systemImage: "clock.badge.xmark",
                        title: L10n.string("explorer.versions.disabled.title"),
                        message: L10n.string("explorer.versions.disabled.message")
                    )
                case .empty:
                    EmptyStateView(
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        title: L10n.string("explorer.versions.empty.title"),
                        message: L10n.string("explorer.versions.empty.message")
                    )
                case let .error(message):
                    EmptyStateView(
                        systemImage: "exclamationmark.triangle",
                        title: L10n.string("explorer.versions.error.title"),
                        message: message
                    )
                case .loaded:
                    Table(viewModel.objectVersions) {
                        TableColumn(L10n.string("common.version_id")) { version in
                            Text(viewModel.abbreviated(version.versionID, prefix: 12, suffix: 8))
                                .help(version.versionID)
                        }
                        .width(min: 150, ideal: 210)

                        TableColumn(L10n.string("explorer.table.modified")) { version in
                            Text(version.modifiedAt.friendlyDateText)
                                .foregroundStyle(theme.textSecondary)
                        }
                        .width(min: 170, ideal: 190)

                        TableColumn(L10n.string("explorer.table.size")) { version in
                            Text(version.size.friendlyByteText)
                                .foregroundStyle(theme.textSecondary)
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn(L10n.string("explorer.inspector.etag")) { version in
                            Text(viewModel.abbreviated(version.etag, prefix: 10, suffix: 6))
                                .foregroundStyle(theme.textSecondary)
                                .help(version.etag ?? L10n.string("common.not_available"))
                        }
                        .width(min: 110, ideal: 150)

                        TableColumn(L10n.string("common.current")) { version in
                            Text(LocalizedDisplayValue.yesNo(version.isCurrent, falseUsesDash: true))
                                .foregroundStyle(version.isCurrent ? BrandColors.success : theme.textSecondary)
                        }
                        .width(min: 60, ideal: 70)

                        TableColumn(L10n.string("common.delete_marker")) { version in
                            Text(LocalizedDisplayValue.yesNo(version.isDeleteMarker))
                                .foregroundStyle(version.isDeleteMarker ? BrandColors.warning : theme.textSecondary)
                        }
                        .width(min: 100, ideal: 120)
                    }
                    .tableStyle(.inset(alternatesRowBackgrounds: false))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
        .background(theme.appBackground)
    }
}

private struct InspectorSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        let shadow = AppShadows.card(for: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.8)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
        }
    }
}

private struct InspectorValueRow: View {
    let title: String
    let value: String
    var copyValue: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.7)
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                if let copyValue {
                    Button {
                        NativeDialogs.copyToPasteboard(copyValue)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help(L10n.string("common.copy_full_value"))
                }
            }
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ErrorBannerView: View {
    let title: String
    let message: String?
    let retryTitle: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let background = colorScheme == .dark ? BrandColors.warningToastDark : BrandColors.warningToastLight
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(BrandColors.warning.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandColors.warning)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.warningToastText)
                }
            }
            Spacer()
            Button(retryTitle, action: onRetry)
                .buttonStyle(AppButtonStyle(kind: .secondary))
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandColors.warning.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ExplorerLoadingView: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
