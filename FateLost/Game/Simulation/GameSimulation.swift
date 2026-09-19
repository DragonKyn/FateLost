import CoreGraphics
import Foundation

/// Identifies a run before it starts: where, with what, and from which seed.
struct RunConfiguration: Hashable {
    let realmID: RealmID
    let starterWeaponID: WeaponID
    let seed: UInt64

    static func new(realm: RealmID, weapon: WeaponID) -> RunConfiguration {
        RunConfiguration(realmID: realm, starterWeaponID: weapon, seed: UInt64.random(in: .min ... .max))
    }
}

/// Toggles that bend the rules for testing. Always off in normal play.
struct SimulationCheats: Equatable {
    var godMode = false
    var spawningEnabled = true
}

/// The authoritative game state for one run, advanced in fixed steps.
///
/// Deliberately free of SpriteKit: the scene feeds it intents and reads its
/// state to draw. That keeps game rules testable and lets rendering change
/// without touching them. Each phase adds systems here rather than to the
/// scene.
///
/// Order of a step:
/// 1. the player moves;
/// 2. new enemies arrive;
/// 3. enemies chase, crowd and strike (grid rebuilt first for crowding);
/// 4. the weapon attacks and projectiles fly (grid rebuilt again, so hits
///    test where enemies are now);
/// 5. the dead are removed.
struct GameSimulation {
    let run: RunConfiguration
    let realm: RealmDefinition
    let arena: ArenaLayout
    let weapon: WeaponDefinition
    let tuning: GameTuning

    private(set) var player: PlayerState
    private(set) var combat: CombatState
    /// Simulated seconds since the run began (excludes pauses).
    private(set) var elapsed: TimeInterval = 0
    /// Simulated seconds since the player fell, or nil while alive.
    private(set) var timeSinceDefeat: TimeInterval?
    var cheats = SimulationCheats()

    private let movement: MovementSystem
    private var spawner: SpawnSystem
    private var enemyAI: EnemyAISystem
    private var weaponSystem: WeaponSystem
    private let projectileSystem = ProjectileSystem()

    var world: ToroidalWorld { arena.world }
    var enemies: EnemyStore { combat.enemies }
    var projectiles: [Projectile] { combat.projectiles }
    var stats: RunStats { combat.stats }
    var isPlayerDefeated: Bool { player.isDefeated }
    /// Seconds until the weapon may attack again.
    var weaponCooldown: Double { weaponSystem.cooldown }

    init(run: RunConfiguration, tuning: GameTuning) {
        self.run = run
        self.tuning = tuning
        let realm = RealmCatalog.realm(run.realmID)
        self.realm = realm
        weapon = StarterWeapons.definition(for: run.starterWeaponID) ?? StarterWeapons.sword
        let arena = ArenaGenerator(definition: realm.arena, seed: run.seed).generate()
        self.arena = arena
        player = PlayerState(position: arena.playerSpawn, maxHealth: tuning.player.baseMaxHealth)
        // Combat randomness has its own stream so it never shifts the arena.
        combat = CombatState(world: arena.world, tuning: tuning.combat, gridCellSize: tuning.enemyAI.gridCellSize,
                             capacity: tuning.enemyAI.hardCap, seed: run.seed ^ 0xC0_4BA7)
        movement = MovementSystem(tuning: tuning.player)
        spawner = SpawnSystem(tuning: tuning.spawning, roster: EnemyCatalog.roster(for: run.realmID))
        enemyAI = EnemyAISystem(tuning: tuning.enemyAI, combatTuning: tuning.combat)
        weaponSystem = WeaponSystem(weapon: weapon, tuning: tuning.combat)
    }

    /// Distance from the player at which enemies appear.
    var spawnRadius: CGFloat {
        get { spawner.spawnRadius }
        set { spawner.spawnRadius = max(newValue, 1) }
    }

    /// Enemies per second the spawner is currently aiming for.
    var currentSpawnRate: Double { spawner.rate(atElapsed: elapsed) }

    mutating func step(dt: TimeInterval, intent: PlayerIntent) {
        elapsed += dt
        let alive = !player.isDefeated
        if !alive {
            timeSinceDefeat = (timeSinceDefeat ?? 0) + dt
        }

        player.invulnerability = max(0, player.invulnerability - dt)
        player.timeSinceHit += dt
        movement.step(&player, intent: alive ? intent : .idle, speedMultiplier: 1, world: world, dt: CGFloat(dt))

        spawner.isEnabled = alive && cheats.spawningEnabled
        spawner.step(&combat, player: player, elapsed: elapsed, dt: dt, hardCap: tuning.enemyAI.hardCap,
                     speedVariance: tuning.enemyAI.speedVariance)

        combat.rebuildGrid()
        enemyAI.step(&combat, player: &player, godMode: cheats.godMode, dt: dt)

        combat.rebuildGrid()
        if alive {
            weaponSystem.step(&combat, player: &player, dt: dt)
        }
        projectileSystem.step(&combat, dt: dt)
        combat.removeDefeatedEnemies()
    }

    /// Hands over everything that happened since the last call.
    mutating func drainEvents() -> [CombatEvent] {
        let drained = combat.events
        combat.events.removeAll(keepingCapacity: true)
        return drained
    }

    // MARK: - Developer commands

    mutating func spawnEnemies(_ count: Int) {
        spawner.spawnBurst(count, into: &combat, player: player, hardCap: tuning.enemyAI.hardCap,
                           speedVariance: tuning.enemyAI.speedVariance)
    }

    /// Kills every enemy, awarding the kills as if the player had landed them.
    mutating func defeatAllEnemies() {
        for index in 0..<combat.enemies.count {
            combat.enemies.health[index] = 0
        }
        combat.removeDefeatedEnemies()
    }

    mutating func restorePlayerHealth() {
        guard !player.isDefeated else { return }
        player.health = player.maxHealth
    }
}
