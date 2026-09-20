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
            case .legacy:
                LegacyView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .statistics:
                StatisticsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .character:
                CharacterView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .weaponSelect(let realmID):
                WeaponSelectView(realm: RealmCatalog.realm(realmID))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .multiplayer:
                MultiplayerMenuView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .hostGame:
                HostGameView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .joinGame:
                JoinGameView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .lobby:
                LobbyView()
                    .transition(.opacity)
            case .partyRun:
                if let run = router.activePartyRun {
                    PartyRunScreen(run: run)
                        .id(ObjectIdentifier(run))
                        .transition(.opacity)
                }
            case .gameplay:
                if let session = router.activeSession {
                    GameplayScreen(session: session)
                        // A restarted run is a new screen, with fresh state.
                        .id(ObjectIdentifier(session))
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
        .onAppear {
            updateMusic(for: router.screen)
            services.multiplayer.attach(router: router)
        }
        .onChange(of: router.screen) { _, screen in updateMusic(for: screen) }
        .onChange(of: scenePhase) { _, phase in
            // Never let the run continue unattended in the background.
            if phase != .active {
                router.activeSession?.pause()
            } else {
                // Back from the background: make sure the party connection is alive.
                services.multiplayer.client.resume()
            }
        }
    }

    /// Menus share one theme; the gameplay screen starts its realm's music
    /// itself when the run appears.
    private func updateMusic(for screen: AppScreen) {
        guard screen != .gameplay, screen != .partyRun else { return }
        // Leaving a paused run must not leave the menu music ducked.
        services.audio.setMusicDucked(false)
        services.audio.stopAmbience()
        services.audio.playMusic(MusicDirector.menuTheme, fadeDuration: 2)
    }
}
