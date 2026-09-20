import Observation
import SwiftUI

/// Top-level screens. Modal panels (settings, pause) are presented over
/// these rather than being screens of their own.
enum AppScreen: Equatable {
    case launch
    case mainMenu
    case realmSelect
    case weaponSelect(RealmID)
    case legacy
    case statistics
    case character
    case gameplay
}

/// Owns navigation between top-level screens and the active run.
///
/// Full-screen swaps rather than a `NavigationStack`: a game moves between
/// distinct modes, not a drill-down hierarchy, and every screen wants the
/// whole display.
@MainActor
@Observable
final class AppRouter {
    private(set) var screen: AppScreen = .launch
    private(set) var activeSession: GameSession?
    var isSettingsPresented = false
    var isDeveloperPanelPresented = false

    func show(_ destination: AppScreen) {
        withAnimation(.easeInOut(duration: 0.35)) {
            screen = destination
        }
    }

    func startRun(_ run: RunConfiguration, services: AppServices) {
        activeSession = GameSession(run: run, services: services)
        show(.gameplay)
    }

    /// Starts a fresh run in the same realm with the same weapon.
    func restartRun(services: AppServices) {
        guard let previous = activeSession?.run else { return }
        activeSession = nil
        startRun(.new(realm: previous.realmID, weapon: previous.starterWeaponID), services: services)
    }

    /// Leaves the current run and returns to the menu.
    func endRun() {
        activeSession = nil
        show(.mainMenu)
    }
}
