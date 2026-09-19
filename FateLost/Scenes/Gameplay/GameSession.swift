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
    /// Set once the run has ended and its summary should be shown.
    private(set) var summary: RunSummary?

    @ObservationIgnored let scene: GameScene
    @ObservationIgnored private let audio: AudioManager

    init(run: RunConfiguration, services: AppServices, tuning: GameTuning = .standard) {
        self.run = run
        realm = RealmCatalog.realm(run.realmID)
        weapon = StarterWeapons.definition(for: run.starterWeaponID) ?? StarterWeapons.sword
        audio = services.audio
        scene = GameScene(run: run, dependencies: GameScene.Dependencies(
            tuning: tuning,
            settings: services.settings,
            developer: services.developer,
            audio: services.audio,
            haptics: services.haptics
        ))
        scene.onHUDStateChange = { [weak self] state in
            self?.hud = state
        }
        scene.onRunEnded = { [weak self] summary in
            self?.summary = summary
        }
    }

    /// Starts the realm's music and ambience. Called when the run appears.
    func beginPresentation() {
        audio.setMusicDucked(false)
        audio.playMusic(MusicDirector.battleTheme(for: realm.id))
        audio.playAmbience(MusicDirector.ambience(for: realm.id))
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        scene.resetInput()
        scene.isGameplayPaused = true
        audio.setMusicDucked(true)
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        scene.isGameplayPaused = false
        audio.setMusicDucked(false)
    }
}
