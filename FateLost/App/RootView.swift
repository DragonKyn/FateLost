import SwiftUI

/// Switches between top-level screens and hosts app-wide modals.
struct RootView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router

        ZStack {
            FLTheme.Palette.abyss.ignoresSafeArea()

            switch router.screen {
            case .launch:
                LaunchView()
                    .transition(.opacity)
            case .mainMenu:
                MainMenuView()
                    .transition(.opacity)
            case .realmSelect:
                RealmSelectView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .weaponSelect(let realmID):
                WeaponSelectView(realm: RealmCatalog.realm(realmID))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .gameplay:
                if let session = router.activeSession {
                    GameplayScreen(session: session)
                        .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $router.isSettingsPresented) {
            SettingsView()
        }
        .sheet(isPresented: $router.isDeveloperPanelPresented) {
            DeveloperPanelView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Never let the run continue unattended in the background.
            if phase != .active {
                router.activeSession?.pause()
            }
        }
    }
}
