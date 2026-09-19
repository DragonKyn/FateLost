import Observation
import SpriteKit

/// Owns one run's scene and exposes what SwiftUI needs to draw around it.
///
/// SwiftUI never reaches into the scene's internals: it reads `hud`, calls
/// `pause`/`resume`, and the scene reports changes back through a callback.
@MainActor
@Observable
final class GameSession {
    let run: RunConfiguration
    let realm: RealmDefinition
    let weapon: WeaponDefinition

    private(set) var hud = GameplayHUDState()
    private(set) var isPaused = false

    @ObservationIgnored let scene: GameScene

    init(run: RunConfiguration, services: AppServices, tuning: GameTuning = .standard) {
        self.run = run
        realm = RealmCatalog.realm(run.realmID)
        weapon = StarterWeapons.definition(for: run.starterWeaponID) ?? StarterWeapons.sword
        scene = GameScene(run: run, dependencies: GameScene.Dependencies(
            tuning: tuning,
            settings: services.settings,
            developer: services.developer
        ))
        scene.onHUDStateChange = { [weak self] state in
            self?.hud = state
        }
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        scene.resetInput()
        scene.isGameplayPaused = true
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        scene.isGameplayPaused = false
    }
}
