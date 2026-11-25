import SwiftUI

@main
struct SuoxiaApp: App {
    @StateObject private var store = VaultStore()

    var body: some Scene {
        WindowGroup {
            RootContainerView(store: store)
                .preferredColorScheme(store.isDark ? .dark : .light)
        }
    }
}

struct RootContainerView: View {
    @ObservedObject var store: VaultStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            switch store.screen {
            case .onboarding:
                OnboardingView(store: store)
            case .unlock:
                UnlockView(store: store)
            case .home:
                MainTabView(store: store)
            }

            // Background Privacy Blur Overlay
            if store.privacyMask && scenePhase != .active {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    VStack(spacing: 10) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.brand)
                        Text(t("锁匣隐私保护中"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
                .transition(.opacity)
            }
        }
        .svToastOverlay(store: store, bottomPadding: 78)
        .onChange(of: scenePhase) { newPhase in
            store.handleScenePhaseChange(newPhase)
        }
        .confirmationDialog(
            t("发现同步冲突"),
            isPresented: Binding(
                get: { !store.isWebDavSheetOpen && store.showWebdavConflictSheet },
                set: { if !$0 { store.showWebdavConflictSheet = false } }
            ),
            titleVisibility: .visible
        ) {
            Button(t("用本机覆盖云端")) {
                Task { await store.resolveConflictKeepLocal() }
            }
            Button(t("用云端覆盖本机")) {
                Task { await store.resolveConflictUseRemote() }
            }
            Button(t("取消"), role: .cancel) {}
        } message: {
            Text(t("本机与云端的备份数据均有更新，请选择保留哪一份："))
        }
        .sheet(
            isPresented: Binding(
                get: { !store.isWebDavSheetOpen && store.showRemotePasswordPrompt },
                set: { if !$0 { store.cancelRemotePasswordPrompt() } }
            )
        ) {
            RemotePasswordPromptSheet(store: store)
                .svSheetPresentation(.compact(270))
                .interactiveDismissDisabled(true)
        }
    }
}

struct MainTabView: View {
    @ObservedObject var store: VaultStore

    var body: some View {
        TabView(selection: $store.activeTab) {
            VaultListView(store: store)
                .tabItem {
                    Label(HomeTab.vault.label, systemImage: store.activeTab == .vault ? "lock.fill" : "lock")
                }
                .tag(HomeTab.vault)

            TotpListView(store: store)
                .tabItem {
                    Label(HomeTab.totp.label, systemImage: store.activeTab == .totp ? "checkmark.shield.fill" : "checkmark.shield")
                }
                .tag(HomeTab.totp)

            GeneratorView(store: store)
                .tabItem {
                    Label(HomeTab.generator.label, systemImage: store.activeTab == .generator ? "key.fill" : "key")
                }
                .tag(HomeTab.generator)

            PreferencesView(store: store)
                .tabItem {
                    Label(HomeTab.settings.label, systemImage: store.activeTab == .settings ? "gearshape.fill" : "gearshape")
                }
                .tag(HomeTab.settings)
        }
        .tint(AppTheme.brand)
    }
}
