import SwiftUI
import OCIExplorerCore

struct IOSBucketListView: View {
    @ObservedObject var viewModel: IOSBucketListViewModel
    let onDisconnect: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.session.profile.name)
                            .font(.headline)
                        Text("\(viewModel.session.auth.region) • \(viewModel.session.auth.namespace ?? "Namespace pendente")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section("Buckets") {
                    if viewModel.isLoading && viewModel.buckets.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Carregando buckets…")
                            Spacer()
                        }
                    } else if viewModel.buckets.isEmpty {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("Nenhum bucket encontrado")
                                .font(.headline)
                            Text("Quando a conta retornar buckets nesta região, eles aparecerão aqui.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(viewModel.buckets) { bucket in
                            NavigationLink {
                                IOSBucketPlaceholderDetailView(bucket: bucket)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bucket.name)
                                    Text(bucket.namespace)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Buckets")
            .toolbar {
                ToolbarItem(placement: toolbarLeadingPlacement) {
                    Button("Sair", action: onDisconnect)
                }
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task {
                if viewModel.buckets.isEmpty {
                    await viewModel.refresh()
                }
            }
        }
    }
}

private var toolbarLeadingPlacement: ToolbarItemPlacement {
    #if os(iOS)
    .topBarLeading
    #else
    .automatic
    #endif
}

private var toolbarTrailingPlacement: ToolbarItemPlacement {
    #if os(iOS)
    .topBarTrailing
    #else
    .automatic
    #endif
}

private struct IOSBucketPlaceholderDetailView: View {
    let bucket: BucketSummary

    var body: some View {
        List {
            Section("Bucket") {
                LabeledContent("Nome", value: bucket.name)
                LabeledContent("Namespace", value: bucket.namespace)
                LabeledContent("Tier", value: bucket.storageTier ?? "—")
                LabeledContent("Acesso público", value: bucket.publicAccessType ?? "—")
            }

            Section("Próxima etapa") {
                Text("Aqui entraremos com a navegação de objetos e ações do explorer mobile.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(bucket.name)
    }
}
