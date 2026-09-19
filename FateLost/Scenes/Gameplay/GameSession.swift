import Observation
import SpriteKit

/// Owns one run's scene and exposes what SwiftUI needs to draw around it.
///
/// SwiftUI never reaches into the scene's internals: it reads `hud` and
/// `progression`, calls `pause`/`resume` and the skill tree methods, and the
/// scene reports changes back through callbacks.
@MainActor
@Observable
final class GameSession {
    /// Why the game is paused, which decides what's shown over it.
    enum PauseReason: Equatable {
        case menu
        case skillTree
        case developer
    }

    let run: RunConfiguration
    let realm: RealmDefinition
    let weapon: WeaponDefinition

    private(set) var hud = GameplayHUDState()
    private(set) var progression = ProgressionSnapshot()
    private(set) var pauseReason: PauseReason?
    /// Set once the run has ended and its summary should be shown.
    private(set) var summary: RunSummary?
    /// Levels gained since the tree was last opened.
    private(set) var pendingLevelUps = 0

    var isPaused: Bool { pauseReason != nil }
    var isSkillTreePresented: Bool { pauseReason == .skillTree }

    @ObservationIgnored let scene: GameScene
    @ObservationIgnored private let audio: AudioManager
    @ObservationIgnored private var levelUpTask: Task<Void, Never>?

    /// Seconds the level-up burst plays before the tree opens.
    private static let levelUpTreeDelay: Duration = .milliseconds(650)

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
        scene.onProgressionChange = { [weak self] snapshot in
            self?.progression = snapshot
        }
        scene.onLevelUp = { [weak self] _ in
            self?.levelGained()
        }
        scene.onRunEnded = { [weak self] summary in
            self?.levelUpTask?.cancel()
            self?.summary = summary
        }
    }

    /// Starts the realm's music and ambience. Called when the run appears.
    func beginPresentation() {
        audio.setMusicDucked(false)
        audio.playMusic(MusicDirector.battleTheme(for: realm.id))
        audio.playAmbience(MusicDirector.ambience(for: realm.id))
    }

    // MARK: - Pausing

    func pause() {
        pause(for: .menu)
    }

    func pause(for reason: PauseReason) {
        guard pauseReason == nil else { return }
        pauseReason = reason
        scene.resetInput()
        scene.isGameplayPaused = true
        audio.setMusicDucked(true)
    }

    func resume() {
        guard pauseReason != nil else { return }
        pauseReason = nil
        scene.isGameplayPaused = false
        audio.setMusicDucked(false)
    }

    // MARK: - Skill tree

    /// Let the level-up burst play, then open the tree (unless something
    /// else already has the screen).
    private func levelGained() {
        pendingLevelUps += 1
        guard levelUpTask == nil else { return }
        levelUpTask = Task { [weak self] in
            try? await Task.sleep(for: Self.levelUpTreeDelay)
            guard let self, !Task.isCancelled else { return }
            self.levelUpTask = nil
            guard self.summary == nil, self.pauseReason == nil, self.progression.unspentPoints > 0 else { return }
            self.openSkillTree()
        }
    }

    func openSkillTree() {
        guard summary == nil else { return }
        if pauseReason == .menu {
            pauseReason = nil
        }
        pause(for: .skillTree)
        audio.play(.skillTreeOpen)
    }

    /// Commits the tree screen's choices and returns to the fight.
    func closeSkillTree(committing draft: SkillAllocation, slots: [AbilityID?]) {
        if draft != progression.allocation || slots != progression.abilitySlots {
            scene.commitBuild(draft, slots: slots)
        }
        pendingLevelUps = 0
        resume()
    }
}
