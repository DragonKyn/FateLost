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
        /// A find is waiting to be answered.
        case offer
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
    /// The find waiting for a choice, if any.
    private(set) var offer: RelicOffer?

    var isPaused: Bool { pauseReason != nil }
    var isSkillTreePresented: Bool { pauseReason == .skillTree }
    var isOfferPresented: Bool { pauseReason == .offer && offer != nil }

    @ObservationIgnored let scene: GameScene
    @ObservationIgnored private let audio: AudioManager
    @ObservationIgnored private var levelUpTask: Task<Void, Never>?

    /// Seconds the level-up burst plays before the tree opens.
    private static let levelUpTreeDelay: Duration = .milliseconds(650)

    init(run: RunConfiguration, services: AppServices, tuning: GameTuning = .standard) {
        self.run = run
        realm = RealmCatalog.realm(run.realmID)
        let starter = StarterWeapons.definition(for: run.starterWeaponID) ?? StarterWeapons.sword
        weapon = starter
        audio = services.audio
        scene = GameScene(run: run, dependencies: GameScene.Dependencies(
            tuning: tuning,
            settings: services.settings,
            developer: services.developer,
            audio: services.audio,
            haptics: services.haptics,
            legacy: services.modifiers(startingWith: starter),
            bonusRerolls: services.bonusRerolls,
            hero: services.hero
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
        scene.onOfferChange = { [weak self] offer in
            self?.offerChanged(offer)
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

    // MARK: - Finds

    private func offerChanged(_ offer: RelicOffer?) {
        self.offer = offer
        guard offer != nil, summary == nil, pauseReason == nil else { return }
        pause(for: .offer)
    }

    /// Takes the chosen card and goes back to the fight, or on to the skill
    /// tree if a level was earned while the chest was being opened.
    func chooseRelic(at index: Int) {
        guard scene.chooseRelic(at: index) else { return }
        offer = scene.currentOffer
        if pauseReason == .offer {
            resume()
        }
        if progression.unspentPoints > 0, pendingLevelUps > 0, pauseReason == nil {
            openSkillTree()
        }
    }

    /// Takes the weapon on offer, in place of the one in the hand.
    func chooseWeapon() {
        guard scene.chooseWeapon() else { return }
        offer = scene.currentOffer
        if pauseReason == .offer {
            resume()
        }
        if progression.unspentPoints > 0, pendingLevelUps > 0, pauseReason == nil {
            openSkillTree()
        }
    }

    func rerollOffer() {
        guard scene.rerollOffer() else { return }
        offer = scene.currentOffer
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

    /// Sends the player's summons away, or calls them back.
    func toggleSummons() {
        scene.toggleSummons()
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
