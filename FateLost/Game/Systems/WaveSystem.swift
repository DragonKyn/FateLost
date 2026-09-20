import CoreGraphics
import Foundation

/// Where a run has got to: which wave, and whether a champion is on the field.
struct WaveState: Equatable {
    enum Phase: Equatable {
        /// An ordinary wave, counting down to the next.
        case fighting
        /// The champion has been announced and is about to land.
        case bossIncoming
        /// The champion is up; the wave will not advance until it falls.
        case bossFight
        /// The realm's conquest boss has fallen. The run is won.
        case conquered
        /// A party's breather: the horde stops arriving so the fallen can be
        /// raised and builds set, until the clock runs out or everyone is ready.
        case resting
    }

    var index = 1
    var phase: Phase = .fighting
    var timeInWave: Double = 0
    /// Stable id of the champion on the field.
    var bossID: Int?
    var bossTitle = ""
    var bossHealth: Double = 0
    var bossMaxHealth: Double = 0
    /// Seconds of breather left (only while `resting`).
    var restRemaining: Double = 0
    /// How many heroes have asked to go on, and how many are asked.
    var restVotes = 0
    var restVoters = 0

    var isBossActive: Bool { phase == .bossFight && bossID != nil }
    var bossHealthFraction: Double {
        bossMaxHealth > 0 ? max(0, min(1, bossHealth / bossMaxHealth)) : 0
    }
}

/// Runs the wave clock, sends in champions and notices when one falls.
///
/// The system owns *when* things arrive; `SpawnSystem` owns *what* and
/// *where*. Keeping them apart means the wave clock can be tested without a
/// world, and a realm can change its pacing without touching spawn logic.
struct WaveSystem {
    let plan: WavePlan
    /// The wave whose champion ends the realm, or nil for an endless one.
    let conquestWave: Int?
    private(set) var state = WaveState()
    /// Seconds left before the announced champion lands.
    private var graceRemaining: Double = 0
    private var pendingBoss: EnemyKindID?

    /// A party stops the horde for a breather after every this-many waves (0: never).
    var restEvery = 0
    var restSeconds: Double = 30
    private enum AfterRest { case advance, resume }
    private var afterRest = AfterRest.advance
    /// The wave a breather was last taken after, so one wave never rests twice.
    private var lastRestWave = 0
    private var restVoted: Set<Int> = []
    private var electorate: Set<Int> = []

    init(plan: WavePlan, conquestWave: Int?) {
        self.plan = plan
        self.conquestWave = conquestWave
    }

    /// Adopts a wave state reported by the host (a guest only watches).
    mutating func mirror(_ state: WaveState) {
        self.state = state
    }

    /// Share of the ordinary spawn rate the current phase allows.
    var spawnShare: Double {
        switch state.phase {
        case .fighting: return 1
        case .bossIncoming: return 0.5
        case .bossFight: return plan.bossSpawnShare
        case .conquered, .resting: return 0
        }
    }

    /// Who may vote to end the breather early (the heroes still in the party).
    mutating func setElectorate(_ heroes: Set<Int>) {
        electorate = heroes
        refreshVotes()
    }

    /// A hero asks to go on. Once every hero has, the breather ends.
    mutating func voteToProceed(hero: Int) {
        guard state.phase == .resting, electorate.contains(hero) else { return }
        restVoted.insert(hero)
        refreshVotes()
    }

    private mutating func refreshVotes() {
        state.restVoters = electorate.count
        state.restVotes = restVoted.intersection(electorate).count
    }

    private func restFollows(wave: Int) -> Bool {
        restEvery > 0 && wave % restEvery == 0 && wave != lastRestWave
    }

    private mutating func beginRest(then next: AfterRest) {
        afterRest = next
        lastRestWave = state.index
        state.phase = .resting
        state.restRemaining = restSeconds
        restVoted.removeAll()
        refreshVotes()
    }

    private mutating func endRest(_ combat: inout CombatState) {
        state.restRemaining = 0
        restVoted.removeAll()
        refreshVotes()
        state.phase = .fighting
        switch afterRest {
        case .advance: advanceWave(&combat)
        case .resume: state.timeInWave = 0
        }
    }

    /// How much harder the horde pushes right now.
    var pressure: Double { plan.pressure(atWave: state.index) }

    /// Advances the clock. Returns the champion to place this step, if one
    /// is due; the caller spawns it and reports back with `bossArrived`.
    mutating func step(_ combat: inout CombatState, dt: TimeInterval) -> EnemyKindID? {
        switch state.phase {
        case .conquered:
            return nil

        case .fighting:
            state.timeInWave += dt
            guard state.timeInWave >= plan.waveSeconds else { return nil }
            if restFollows(wave: state.index) {
                beginRest(then: .advance)
            } else {
                advanceWave(&combat)
            }
            return nil

        case .resting:
            state.restRemaining -= dt
            let everyoneReady = state.restVoters > 0 && state.restVotes >= state.restVoters
            if state.restRemaining <= 0 || everyoneReady { endRest(&combat) }
            return nil

        case .bossIncoming:
            graceRemaining -= dt
            guard graceRemaining <= 0, let boss = pendingBoss else { return nil }
            pendingBoss = nil
            return boss

        case .bossFight:
            trackBoss(&combat)
            return nil
        }
    }

    /// Called once the champion is actually on the field.
    mutating func bossArrived(id: Int, title: String, health: Double, _ combat: inout CombatState) {
        state.phase = .bossFight
        state.bossID = id
        state.bossTitle = title
        state.bossHealth = health
        state.bossMaxHealth = health
        combat.events.append(.bossArrived(title: title))
    }

    /// Moves to the next wave, announcing a champion when one is due.
    private mutating func advanceWave(_ combat: inout CombatState) {
        state.timeInWave = 0
        state.index += 1
        combat.events.append(.waveBegan(wave: state.index))
        guard let boss = plan.boss(forWave: state.index) else { return }
        pendingBoss = boss
        graceRemaining = plan.bossGraceSeconds
        state.phase = .bossIncoming
    }

    /// Watches the champion's health, and notices the moment it is gone.
    private mutating func trackBoss(_ combat: inout CombatState) {
        guard let id = state.bossID else {
            finishBossWave(&combat)
            return
        }
        guard let index = combat.index(ofEnemy: id), combat.enemies.health[index] > 0 else {
            finishBossWave(&combat)
            return
        }
        state.bossHealth = combat.enemies.health[index]
        state.bossMaxHealth = combat.enemies.maxHealth[index]
    }

    private mutating func finishBossWave(_ combat: inout CombatState) {
        let title = state.bossTitle
        state.bossID = nil
        state.bossHealth = 0
        state.bossMaxHealth = 0
        combat.events.append(.bossDefeated(title: title))

        if let conquestWave, state.index >= conquestWave {
            state.phase = .conquered
            combat.events.append(.realmConquered)
            return
        }
        state.phase = .fighting
        state.timeInWave = 0
        if restFollows(wave: state.index) { beginRest(then: .resume) }
    }

    /// Gives up on a champion that could not be placed, so a run is never
    /// left waiting on a fight that cannot happen.
    mutating func abandonBossWave() {
        guard state.phase == .bossIncoming || state.phase == .bossFight else { return }
        state.bossID = nil
        state.bossHealth = 0
        state.bossMaxHealth = 0
        state.phase = .fighting
        state.timeInWave = 0
    }

    /// Developer tooling: jump straight to the next wave.
    mutating func skipToNextWave(_ combat: inout CombatState) {
        guard state.phase == .fighting || state.phase == .resting else { return }
        state.phase = .fighting
        advanceWave(&combat)
    }
}
