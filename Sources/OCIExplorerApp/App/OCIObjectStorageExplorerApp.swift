import SwiftUI
import AppKit
import OCIExplorerCore
import OCIExplorerShared

@main
struct OCIObjectStorageExplorerApp: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        let container = AppContainer()
        _viewModel = StateObject(wrappedValue: AppViewModel(container: container))
    }

    var body: some Scene {
        WindowGroup(L10n.string("app.title")) {
            RootView(viewModel: viewModel)
                .frame(minWidth: 1160, minHeight: 760)
        }
        .defaultSize(width: 1280, height: 820)
    }
}

private struct RootView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var hasCompletedSplash = false

    var body: some View {
        ZStack {
            if hasCompletedSplash {
                if let explorerViewModel = viewModel.explorerViewModel {
                    ExplorerView(
                        viewModel: explorerViewModel,
                        onDisconnect: viewModel.disconnect
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.01)))
                } else {
                    AuthenticationView(
                        viewModel: viewModel.authenticationViewModel,
                        onConnect: {
                            Task { await viewModel.connect() }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.01)))
                }
            } else {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasCompletedSplash)
        .task {
            guard !hasCompletedSplash else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeInOut(duration: 0.35)) {
                hasCompletedSplash = true
            }
        }
    }
}

private struct SplashView: View {
    @State private var isVisible = false

    var body: some View {
        ZStack {
            AppGradients.brandHeroGradient
            .overlay(
                RadialGradient(
                    colors: [
                        BrandColors.brandBlueLight.opacity(0.18),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 20,
                    endRadius: 420
                )
            )

            VStack(spacing: 22) {
                SplashLogoView()

                VStack(spacing: 8) {
                    Text(L10n.string("app.splash.title"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    Text(L10n.string("app.splash.subtitle"))
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.9)
        }
        .ignoresSafeArea()
        .task {
            guard !isVisible else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = true
            }
        }
    }
}

private struct SplashLogoView: View {
    private let logoImage = NSImage(contentsOf: Bundle.module.url(forResource: "AppLogo", withExtension: "png") ?? URL(fileURLWithPath: ""))

    var body: some View {
        Group {
            if let logoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    )
            }
        }
        .frame(width: 112, height: 112)
        .shadow(color: AppShadows.softGlowBlue, radius: 18)
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
