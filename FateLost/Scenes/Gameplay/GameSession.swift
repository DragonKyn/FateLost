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
        /// Fate's Echo is asking whether to bank and leave or go on.
        case echoOffer
        /// The lone hero has fallen: watch an advert to rise, or accept fate.
        case secondChance
    }

    /// Where the second-chance choice stands.
    enum SecondChanceState: Equatable {
        /// Both choices on screen.
        case offered
        /// The player chose the advert; it is loading or playing.
        case watching
        /// The advert could not be shown or was closed before its reward.
        /// Both choices stay: try again, or accept fate.
        case failed(String)
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

    /// Fate's Echo waiting on bank-or-go-on, and what banking now would pay.
    private(set) var echoOffer: EchoOffer?
    private(set) var echoesAtRisk = 0
    var isEchoOfferPresented: Bool { pauseReason == .echoOffer && echoOffer != nil }

    /// The second-chance choice, while a lone hero's fall waits on it.
    private(set) var secondChance: SecondChanceState?
    var isSecondChancePresented: Bool { pauseReason == .secondChance && secondChance != nil }

    /// Whole seconds left on each boon, for the HUD. Updated only when a
    /// whole second changes, so the HUD is not redrawn every frame.
    private(set) var boonSeconds: [Boon: Int] = [:]
    /// Echoes Double Echoes added to this run, once it has been paid out.
    private(set) var boonEchoBonus = 0
    @ObservationIgnored private var echoTally = EchoBoostTally()

    @ObservationIgnored let scene: GameScene
    @ObservationIgnored private let audio: AudioManager
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let services: AppServices
    @ObservationIgnored private var levelUpTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    /// An advert for the second chance is in flight: further taps do nothing.
    @ObservationIgnored private var secondChanceInFlight = false
    @ObservationIgnored private var paidOut: Int?

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
        settings = services.settings
        self.services = services
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
            partyConfigs: party?.role == .host ? party?.info.partyConfigs() ?? [] : [],
            // A second chance is solo only, and only where adverts can exist.
            offersSecondChance: party == nil && services.ads.isSupported
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
        scene.onEchoOfferChange = { [weak self] offer in
            self?.echoOfferChanged(offer)
        }
        scene.onRunEnded = { [weak self] summary in
            self?.levelUpTask?.cancel()
            self?.summary = summary
        }
        scene.onSecondChanceChange = { [weak self] awaiting in
            self?.secondChanceChanged(awaiting)
        }
        scene.onPlayTime = { [weak self] seconds in
            self?.played(seconds)
        }
        refreshBoons()
        party?.onResults = { [weak self] results in
            self?.levelUpTask?.cancel()
            self?.partyResults = results
            self?.scene.resetInput()
        }
    }

    // MARK: - Boons

    /// Boons only run in solo play, and only while the run is being fought:
    /// this is called with seconds actually simulated, never while paused,
    /// backgrounded, in a menu or behind an advert.
    private func played(_ seconds: TimeInterval) {
        guard !isParty, summary == nil else { return }
        let echoesWereDoubled = services.boons.isActive(.doubleEchoes)
        services.consumeBoons(seconds)
        if echoesWereDoubled, !services.boons.isActive(.doubleEchoes) {
            // Ran out mid-run: what was earned up to here is doubled, and
            // nothing after.
            echoTally.close(at: payoutSoFar())
        }
        refreshBoons()
    }

    private func refreshBoons() {
        if isParty {
            if !boonSeconds.isEmpty { boonSeconds = [:] }
            scene.riftChanceBonus = 0
            return
        }
        var seconds: [Boon: Int] = [:]
        for boon in Boon.allCases where services.boons.isActive(boon) {
            seconds[boon] = services.boons.wholeSeconds(boon)
        }
        if seconds != boonSeconds { boonSeconds = seconds }
        scene.riftChanceBonus = services.boons.isActive(.riftCalling) ? BoonTuning.riftChanceBonus : 0
        if services.boons.isActive(.doubleEchoes), !echoTally.isOpen, summary == nil {
            echoTally.open(at: payoutSoFar())
        }
    }

    /// What the run would pay if it were banked now (before any boon).
    private func payoutSoFar() -> Int {
        services.profile.payout(for: scene.summarySoFar(outcome: .collected), realm: realm)
    }

    /// Pays the finished run out, once, with Double Echoes' share of what it
    /// earned while the boon ran. Returns the total paid.
    @discardableResult
    func payOut(_ summary: RunSummary) -> Int {
        if let paidOut { return paidOut }
        let base = services.profile.payout(for: summary, realm: realm)
        let bonus = isParty ? 0 : echoTally.bonus(finalPayout: base)
        boonEchoBonus = bonus
        let total = services.record(summary, boonBonus: bonus)
        services.saveBoons()
        paidOut = total
        return total
    }

    // MARK: - A second chance

    private func secondChanceChanged(_ awaiting: Bool) {
        guard !isParty else { return }
        if awaiting {
            levelUpTask?.cancel()
            levelUpTask = nil
            secondChance = .offered
            // Nothing can be open while the hero is falling, but make sure.
            if pauseReason != nil { pauseReason = nil }
            pause(for: .secondChance)
            // Get an advert on its way while the player reads the choice.
            let ads = services.ads
            Task { await ads.load() }
        } else if secondChance != nil {
            secondChance = nil
            if pauseReason == .secondChance { resume() }
        }
    }

    /// The player chose to watch an advert to rise again. The advert is only
    /// shown now, on their say-so; the hero only rises if the SDK confirms
    /// the reward. Repeated taps do nothing.
    func watchAdToRevive() {
        guard pauseReason == .secondChance, !secondChanceInFlight else { return }
        switch secondChance {
        case .offered, .failed: break
        default: return
        }
        secondChanceInFlight = true
        secondChance = .watching
        let ads = services.ads
        Task { [weak self] in
            let outcome = await ads.show()
            guard let self else { return }
            self.secondChanceInFlight = false
            // Accepted fate meanwhile, or the run is over: nothing to grant.
            guard self.pauseReason == .secondChance, self.secondChance == .watching else { return }
            switch outcome {
            case .earned:
                self.rise()
            case .closedEarly:
                self.secondChance = .failed("The ad was closed before it finished, so no revive was earned.")
            case .failed(let reason):
                self.secondChance = .failed(reason)
            case .busy:
                self.secondChance = .offered
            }
        }
    }

    private func rise() {
        guard scene.takeSecondChance() else {
            secondChance = nil
            if pauseReason == .secondChance { resume() }
            return
        }
        secondChance = nil
        // The fall silenced the fight; it comes back with the hero.
        audio.playMusic(MusicDirector.battleTheme(for: realm.id), fadeDuration: 0.8)
        audio.playAmbience(MusicDirector.ambience(for: realm.id))
        if pauseReason == .secondChance { resume() }
    }

    /// The player lets the fall stand: the run ends as it always has.
    func acceptFate() {
        guard pauseReason == .secondChance, !secondChanceInFlight else { return }
        scene.acceptFate()
        secondChance = nil
        resume()
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
        // A fall still waiting on its choice keeps the screen.
        if !isParty, secondChance != nil, summary == nil {
            pause(for: .secondChance)
            return
        }
        // A bank-or-go-on question that arrived while something else had the
        // screen (the skill tree, say) is still waiting: ask it now.
        if !isParty, echoOffer != nil, summary == nil {
            pause(for: .echoOffer)
        }
    }

    // MARK: - Fate's Echo

    private func echoOfferChanged(_ offer: EchoOffer?) {
        echoOffer = offer
        if offer != nil {
            echoesAtRisk = services.profile.payout(for: scene.collectedSummary(), realm: realm)
        }
        if offer == nil, pauseReason == .echoOffer {
            // Banked and leaving: stay still behind the summary.
            if summary == nil { resume() }
            return
        }
        guard offer != nil, summary == nil, pauseReason == nil else { return }
        levelUpTask?.cancel()
        levelUpTask = nil
        pause(for: .echoOffer)
    }

    /// Keeps the echoes at risk and goes on to the next wave.
    func continueEchoes() {
        scene.continueFromEchoOffer()
        echoOffer = scene.currentEchoOffer
        if pauseReason == .echoOffer { resume() }
    }

    /// Banks what the run has earned and ends it through the ordinary summary.
    func collectEchoes() {
        scene.collectEchoes()
        echoOffer = nil
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
        if !isParty, settings.settings.pauseOnLevelUp, progression.unspentPoints > 0, pendingLevelUps > 0,
           pauseReason == nil {
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
        if !isParty, settings.settings.pauseOnLevelUp, progression.unspentPoints > 0, pendingLevelUps > 0,
           pauseReason == nil {
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
        // Off `pauseOnLevelUp`, a solo run gets the same treatment: points
        // bank up and the button glows until the player opens the tree.
        guard !isParty, settings.settings.pauseOnLevelUp, levelUpTask == nil else { return }
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
