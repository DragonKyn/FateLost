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
    /// The page of the skill tree the player was on when they last spent a
    /// point, so the tree opens where they left off.
    var lastSkillBoard: TreeBoard?
    /// The find waiting for a choice, if any.
    private(set) var offer: RelicOffer?
    /// The party this run is played with, in a multiplayer run.
    let party: PartyRunController?
    /// How a party's run ended, once it has.
    private(set) var partyResults: PartyResults?

    var isParty: Bool { party != nil }

    var isPaused: Bool { pauseReason != nil }
    var isSkillTreePresented: Bool { pauseReason == .skillTree }
    var isOfferPresented: Bool { pauseReason == .offer && offer != nil }

    @ObservationIgnored let scene: GameScene
    @ObservationIgnored private let audio: AudioManager
    @ObservationIgnored private var levelUpTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?

    /// Seconds the level-up burst plays before the tree opens.
    private static let levelUpTreeDelay: Duration = .milliseconds(650)

    init(run: RunConfiguration, services: AppServices, tuning: GameTuning = .standard,
         party: PartyRunController? = nil) {
        self.run = run
        self.party = party
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
            // In a party the host builds every hero, from what each player sent.
            legacy: party == nil ? services.modifiers(startingWith: starter) : [],
            bonusRerolls: party == nil ? services.bonusRerolls : 0,
            hero: services.hero,
            party: party,
            partyConfigs: party?.role == .host ? party?.info.partyConfigs() ?? [] : []
        ))
        party?.scene = scene
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
        party?.onResults = { [weak self] results in
            self?.levelUpTask?.cancel()
            self?.partyResults = results
            self?.scene.resetInput()
        }
    }

    /// Starts the realm's music and ambience. Called when the run appears.
    func beginPresentation() {
        audio.setMusicDucked(false)
        audio.playMusic(MusicDirector.battleTheme(for: realm.id))
        audio.playAmbience(MusicDirector.ambience(for: realm.id))
        beginWatchingParty()
    }

    /// Keeps the party's connection status (reconnecting, host away) fresh.
    private func beginWatchingParty() {
        guard let party, statusTask == nil else { return }
        statusTask = Task { [weak self, weak party] in
            while !Task.isCancelled {
                guard let party, let hub = party.hub else { return }
                party.updateStatus(hostAwayUntil: hub.client.hostAwayUntil, state: hub.client.state)
                try? await Task.sleep(for: .seconds(1))
                _ = self
            }
        }
    }

    /// Tears down what a party run left running.
    func endPresentation() {
        statusTask?.cancel()
        statusTask = nil
        levelUpTask?.cancel()
    }

    // MARK: - Pausing

    func pause() {
        pause(for: .menu)
    }

    func pause(for reason: PauseReason) {
        guard pauseReason == nil else { return }
        pauseReason = reason
        scene.resetInput()
        if isParty {
            // The world does not wait for one player: their hero is sheltered
            // for as long as the menu is open (and for a while at most).
            scene.setMenuShelter(true)
        } else {
            scene.isGameplayPaused = true
            audio.setMusicDucked(true)
        }
    }

    func resume() {
        guard pauseReason != nil else { return }
        pauseReason = nil
        if isParty {
            scene.setMenuShelter(false)
        } else {
            scene.isGameplayPaused = false
            audio.setMusicDucked(false)
        }
    }

    // MARK: - Finds

    private func offerChanged(_ offer: RelicOffer?) {
        self.offer = offer
        if offer == nil, pauseReason == .offer {
            // The find is gone (answered, or taken back by the host). Left as
            // it was, nothing would show and the hero would stay sheltered
            // and frozen on the host with no way to close anything.
            resume()
            return
        }
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
        if !isParty, progression.unspentPoints > 0, pendingLevelUps > 0, pauseReason == nil {
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
        if !isParty, progression.unspentPoints > 0, pendingLevelUps > 0, pauseReason == nil {
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
        // In a party the world does not stop for one player's menu, so a level
        // never throws the tree open mid-fight: the button glows instead.
        guard !isParty, levelUpTask == nil else { return }
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
