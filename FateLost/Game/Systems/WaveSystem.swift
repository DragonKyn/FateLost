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
    }

    var index = 1
    var phase: Phase = .fighting
    var timeInWave: Double = 0
    /// Stable id of the champion on the field.
    var bossID: Int?
    var bossTitle = ""
    var bossHealth: Double = 0
    var bossMaxHealth: Double = 0

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

    init(plan: WavePlan, conquestWave: Int?) {
        self.plan = plan
        self.conquestWave = conquestWave
    }

    /// Share of the ordinary spawn rate the current phase allows.
    var spawnShare: Double {
        switch state.phase {
        case .fighting: return 1
        case .bossIncoming: return 0.5
        case .bossFight: return plan.bossSpawnShare
        case .conquered: return 0
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
            advanceWave(&combat)
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
    }

    /// Developer tooling: jump straight to the next wave.
    mutating func skipToNextWave(_ combat: inout CombatState) {
        guard state.phase == .fighting else { return }
        advanceWave(&combat)
    }
}
