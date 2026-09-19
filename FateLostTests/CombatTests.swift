import CoreGraphics
import XCTest
@testable import FateLost

/// Shared fixtures for combat tests.
private enum Fixture {
    static let world = ToroidalWorld(width: 128, height: 128)
    static let dt: TimeInterval = 1.0 / 60.0

    static func combat(tuning: CombatTuning = CombatTuning(), seed: UInt64 = 1) -> CombatState {
        CombatState(world: world, tuning: tuning, gridCellSize: 1.5, capacity: 64, seed: seed)
    }

    /// Adds a goblin (or a custom definition) at a position and returns its index.
    @discardableResult
    static func addEnemy(_ combat: inout CombatState, at position: CGPoint,
                         definition: EnemyDefinition = EnemyCatalog.goblin) -> Int {
        let kind = combat.enemies.kindIndex(for: definition)
        let id = combat.makeEntityID()
        combat.enemies.append(id: id, kind: kind, position: position, speedScale: 1)
        return combat.enemies.count - 1
    }

    /// A goblin that neither moves nor strikes, for weapon tests.
    static let dummy = EnemyDefinition(
        id: "test.dummy", name: "Dummy", maxHealth: 1000, moveSpeed: 0, radius: 0.3, attackDamage: 0,
        attackReach: 0, attackWindup: 1, attackCooldown: 1000, knockbackResistance: 1, damageType: .physical,
        behavior: .melee, experience: 0, spawnWeight: 0, earliestMinute: 0, spriteVariants: [.enemyGoblin]
    )

    static func noCrits() -> CombatTuning {
        var tuning = CombatTuning()
        tuning.critChance = 0
        tuning.damageVariance = 0
        return tuning
    }
}

final class EnemyStoreTests: XCTestCase {
    func testRemovalKeepsParallelArraysAligned() {
        var combat = Fixture.combat()
        for index in 0..<5 {
            Fixture.addEnemy(&combat, at: CGPoint(x: CGFloat(index), y: 0))
        }
        let lastID = combat.enemies.ids[4]
        combat.enemies.remove(at: 1)

        XCTAssertEqual(combat.enemies.count, 4)
        // The last enemy moved into the freed slot, with all of its fields.
        XCTAssertEqual(combat.enemies.ids[1], lastID)
        XCTAssertEqual(combat.enemies.positions[1], CGPoint(x: 4, y: 0))
        XCTAssertEqual(combat.enemies.health.count, 4)
        XCTAssertEqual(combat.enemies.windup.count, 4)
    }

    func testKindsAreRegisteredOnce() {
        var combat = Fixture.combat()
        Fixture.addEnemy(&combat, at: .zero)
        Fixture.addEnemy(&combat, at: .zero)
        XCTAssertEqual(combat.enemies.definitions.count, 1)
        XCTAssertEqual(combat.enemies.largestRadius, EnemyCatalog.goblin.radius)
    }

    func testDefeatedEnemiesAreRemovedAndCounted() {
        var combat = Fixture.combat()
        Fixture.addEnemy(&combat, at: .zero)
        Fixture.addEnemy(&combat, at: CGPoint(x: 5, y: 5))
        combat.enemies.health[0] = 0
        combat.removeDefeatedEnemies()

        XCTAssertEqual(combat.enemies.count, 1)
        XCTAssertEqual(combat.stats.kills, 1)
        XCTAssertTrue(combat.events.contains { if case .enemyKilled = $0 { return true } else { return false } })
    }
}

final class SpawnSystemTests: XCTestCase {
    private let tuning = SpawnTuning()

    func testNoSpawnsDuringOpeningDelay() {
        let spawner = SpawnSystem(tuning: tuning, roster: [EnemyCatalog.goblin])
        XCTAssertEqual(spawner.rate(atElapsed: tuning.initialDelay - 0.1), 0)
    }

    func testRateClimbsAndIsCapped() {
        let spawner = SpawnSystem(tuning: tuning, roster: [EnemyCatalog.goblin])
        let early = spawner.rate(atElapsed: tuning.initialDelay + 10)
        let later = spawner.rate(atElapsed: tuning.initialDelay + 180)
        XCTAssertGreaterThan(later, early)
        XCTAssertEqual(spawner.rate(atElapsed: 60 * 60 * 10), tuning.maximumRate)
    }

    func testEnemiesAppearOnTheRingAcrossTheSeam() {
        var spawner = SpawnSystem(tuning: tuning, roster: [EnemyCatalog.goblin])
        spawner.spawnRadius = 12
        var combat = Fixture.combat()
        // Standing in a corner, most of the ring lies across the seam.
        let player = PlayerState(position: CGPoint(x: 0.5, y: 0.5), maxHealth: 100)
        spawner.spawnBurst(50, into: &combat, player: player, hardCap: 800, speedVariance: 0)

        XCTAssertEqual(combat.enemies.count, 50)
        for position in combat.enemies.positions {
            XCTAssertTrue((0..<128).contains(position.x) && (0..<128).contains(position.y))
            let distance = Fixture.world.distance(position, player.position)
            XCTAssertGreaterThanOrEqual(distance, 12 - 0.001)
            XCTAssertLessThanOrEqual(distance, 13.5 + 0.001)
        }
    }

    func testNaturalSpawningStopsAtTheCap() {
        var limited = tuning
        limited.maximumAlive = 20
        limited.initialDelay = 0
        limited.baseRate = 1000
        limited.maximumRate = 1000
        var spawner = SpawnSystem(tuning: limited, roster: [EnemyCatalog.goblin])
        var combat = Fixture.combat()
        let player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        for step in 0..<30 {
            spawner.step(&combat, player: player, elapsed: Double(step) * Fixture.dt, dt: Fixture.dt,
                         hardCap: 800, speedVariance: 0)
        }
        XCTAssertEqual(combat.enemies.count, 20)
    }

    func testBurstRespectsHardCap() {
        var spawner = SpawnSystem(tuning: tuning, roster: [EnemyCatalog.goblin])
        var combat = Fixture.combat()
        let player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        spawner.spawnBurst(100, into: &combat, player: player, hardCap: 30, speedVariance: 0)
        XCTAssertEqual(combat.enemies.count, 30)
    }

    func testStragglersAreBroughtBack() {
        var spawner = SpawnSystem(tuning: tuning, roster: [EnemyCatalog.goblin])
        spawner.spawnRadius = 12
        spawner.isEnabled = false
        var combat = Fixture.combat()
        let player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        Fixture.addEnemy(&combat, at: player.position + CGPoint(x: 40, y: 0))
        spawner.step(&combat, player: player, elapsed: 100, dt: Fixture.dt, hardCap: 800, speedVariance: 0)
        XCTAssertLessThanOrEqual(Fixture.world.distance(combat.enemies.positions[0], player.position), 13.6)
    }
}

final class EnemyAISystemTests: XCTestCase {
    private func step(_ ai: inout EnemyAISystem, _ combat: inout CombatState, _ player: inout PlayerState,
                      ticks: Int, godMode: Bool = false) {
        for _ in 0..<ticks {
            player.invulnerability = max(0, player.invulnerability - Fixture.dt)
            combat.rebuildGrid()
            ai.step(&combat, player: &player, godMode: godMode, dt: Fixture.dt)
        }
    }

    func testChasesTheShortWayAcrossTheSeam() {
        var ai = EnemyAISystem(tuning: EnemyAITuning(), combatTuning: CombatTuning())
        var combat = Fixture.combat()
        var player = PlayerState(position: CGPoint(x: 1, y: 64), maxHealth: 100)
        Fixture.addEnemy(&combat, at: CGPoint(x: 125, y: 64))
        step(&ai, &combat, &player, ticks: 30)

        // It crossed the seam toward the player instead of walking the long way.
        let x = combat.enemies.positions[0].x
        XCTAssertTrue(x > 125 || x < 1, "enemy at \(x)")
    }

    func testCrowdedEnemiesSeparate() {
        var ai = EnemyAISystem(tuning: EnemyAITuning(), combatTuning: CombatTuning())
        var combat = Fixture.combat()
        var player = PlayerState(position: CGPoint(x: 10, y: 10), maxHealth: 100)
        let spot = CGPoint(x: 64, y: 64)
        Fixture.addEnemy(&combat, at: spot)
        Fixture.addEnemy(&combat, at: spot)
        step(&ai, &combat, &player, ticks: 90)

        let gap = Fixture.world.distance(combat.enemies.positions[0], combat.enemies.positions[1])
        XCTAssertGreaterThan(gap, EnemyCatalog.goblin.radius)
    }

    func testTelegraphedStrikeLandsOnce() {
        var ai = EnemyAISystem(tuning: EnemyAITuning(), combatTuning: CombatTuning())
        var combat = Fixture.combat()
        var player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        Fixture.addEnemy(&combat, at: player.position + CGPoint(x: 0.7, y: 0))
        // Initial cooldown (half of 1.1 s) plus the 0.32 s windup, with margin.
        step(&ai, &combat, &player, ticks: 60)

        XCTAssertEqual(player.health, 100 - EnemyCatalog.goblin.attackDamage, accuracy: 0.001)
        XCTAssertTrue(combat.events.contains { if case .enemyWindup = $0 { return true } else { return false } })
        XCTAssertTrue(combat.events.contains { if case .playerHit = $0 { return true } else { return false } })
    }

    func testSteppingAwayDuringWindupDodges() {
        var ai = EnemyAISystem(tuning: EnemyAITuning(), combatTuning: CombatTuning())
        var combat = Fixture.combat()
        var player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        Fixture.addEnemy(&combat, at: player.position + CGPoint(x: 0.7, y: 0))
        // Run until the strike starts, then leap away.
        for _ in 0..<120 where combat.enemies.windup[0] == 0 {
            step(&ai, &combat, &player, ticks: 1)
        }
        XCTAssertGreaterThan(combat.enemies.windup[0], 0)
        player.position = player.position + CGPoint(x: -4, y: 0)
        step(&ai, &combat, &player, ticks: 25)

        XCTAssertEqual(player.health, 100)
    }

    func testGodModePreventsDamage() {
        var ai = EnemyAISystem(tuning: EnemyAITuning(), combatTuning: CombatTuning())
        var combat = Fixture.combat()
        var player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        Fixture.addEnemy(&combat, at: player.position + CGPoint(x: 0.7, y: 0))
        step(&ai, &combat, &player, ticks: 240, godMode: true)
        XCTAssertEqual(player.health, 100)
    }

    func testDefeatIsReportedOnce() {
        var ai = EnemyAISystem(tuning: EnemyAITuning(), combatTuning: CombatTuning())
        var combat = Fixture.combat()
        var player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        player.health = 1
        for offset in [CGPoint(x: 0.7, y: 0), CGPoint(x: -0.7, y: 0), CGPoint(x: 0, y: 0.7)] {
            Fixture.addEnemy(&combat, at: player.position + offset)
        }
        step(&ai, &combat, &player, ticks: 240)

        XCTAssertTrue(player.isDefeated)
        let defeats = combat.events.filter { $0 == .playerDefeated }.count
        XCTAssertEqual(defeats, 1)
    }
}

final class WeaponSystemTests: XCTestCase {
    private func swingOnce(_ weapon: WeaponDefinition, _ combat: inout CombatState, _ player: inout PlayerState) {
        var system = WeaponSystem(weapon: weapon, tuning: combat.tuning)
        combat.rebuildGrid()
        system.step(&combat, player: &player, form: nil, dt: Fixture.dt)
    }

    func testSwordHitsInsideTheArcOnly() {
        var combat = Fixture.combat(tuning: Fixture.noCrits())
        var player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        let front = Fixture.addEnemy(&combat, at: player.position + CGPoint(x: 1.2, y: 0), definition: Fixture.dummy)
        let behind = Fixture.addEnemy(&combat, at: player.position + CGPoint(x: -1.4, y: 0),
                                      definition: Fixture.dummy)
        swingOnce(StarterWeapons.sword, &combat, &player)

        XCTAssertEqual(combat.enemies.health[front], 1000 - StarterWeapons.sword.baseDamage, accuracy: 0.001)
        XCTAssertEqual(combat.enemies.health[behind], 1000)
        XCTAssertTrue(combat.events.contains { if case .meleeSwing = $0 { return true } else { return false } })
    }

    func testSwordWaitsForATargetInReach() {
        var combat = Fixture.combat()
        var player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        Fixture.addEnemy(&combat, at: player.position + CGPoint(x: 6, y: 0), definition: Fixture.dummy)
        var system = WeaponSystem(weapon: StarterWeapons.sword, tuning: combat.tuning)
        combat.rebuildGrid()
        system.step(&combat, player: &player, form: nil, dt: Fixture.dt)

        XCTAssertTrue(combat.events.isEmpty)
        // Still ready: it swings the moment something steps in.
        XCTAssertEqual(system.cooldown, 0)
    }

    func testSwordReachesAcrossTheSeam() {
        var combat = Fixture.combat(tuning: Fixture.noCrits())
        var player = PlayerState(position: CGPoint(x: 0.2, y: 50), maxHealth: 100)
        let target = Fixture.addEnemy(&combat, at: CGPoint(x: 127.4, y: 50), definition: Fixture.dummy)
        swingOnce(StarterWeapons.sword, &combat, &player)
        XCTAssertLessThan(combat.enemies.health[target], 1000)
    }

    func testCriticalHitsMultiplyDamage() {
        var tuning = Fixture.noCrits()
        tuning.critChance = 1
        var combat = Fixture.combat(tuning: tuning)
        var player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        let target = Fixture.addEnemy(&combat, at: player.position + CGPoint(x: 1, y: 0), definition: Fixture.dummy)
        swingOnce(StarterWeapons.sword, &combat, &player)

        let expected = StarterWeapons.sword.baseDamage * tuning.critMultiplier
        XCTAssertEqual(1000 - combat.enemies.health[target], expected, accuracy: 0.001)
        XCTAssertEqual(combat.stats.criticalHits, 1)
    }

    func testBowArrowStrikesAndIsSpent() {
        var combat = Fixture.combat(tuning: Fixture.noCrits())
        var player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        let target = Fixture.addEnemy(&combat, at: player.position + CGPoint(x: 4, y: 0), definition: Fixture.dummy)
        var weapon = WeaponSystem(weapon: StarterWeapons.bow, tuning: combat.tuning)
        let projectiles = ProjectileSystem()
        for _ in 0..<40 {
            combat.rebuildGrid()
            weapon.step(&combat, player: &player, form: nil, dt: Fixture.dt)
            projectiles.step(&combat, dt: Fixture.dt)
        }
        XCTAssertLessThan(combat.enemies.health[target], 1000)
        XCTAssertTrue(combat.events.contains { if case .projectileFired = $0 { return true } else { return false } })
    }

    func testStaffBurstHitsTheCluster() {
        var combat = Fixture.combat(tuning: Fixture.noCrits())
        var player = PlayerState(position: Fixture.world.center, maxHealth: 100)
        let center = player.position + CGPoint(x: 4, y: 0)
        let indices = [CGPoint.zero, CGPoint(x: 0.6, y: 0), CGPoint(x: 0, y: 0.6)].map {
            Fixture.addEnemy(&combat, at: center + $0, definition: Fixture.dummy)
        }
        var weapon = WeaponSystem(weapon: StarterWeapons.staff, tuning: combat.tuning)
        let projectiles = ProjectileSystem()
        for _ in 0..<60 {
            combat.rebuildGrid()
            weapon.step(&combat, player: &player, form: nil, dt: Fixture.dt)
            projectiles.step(&combat, dt: Fixture.dt)
        }
        for index in indices {
            XCTAssertLessThan(combat.enemies.health[index], 1000, "enemy \(index) escaped the burst")
        }
        XCTAssertTrue(combat.events.contains { if case .burst = $0 { return true } else { return false } })
    }
}

final class GameSimulationTests: XCTestCase {
    private func run(seed: UInt64, steps: Int) -> GameSimulation {
        var simulation = GameSimulation(run: RunConfiguration(realmID: .ashenWilds,
                                                              starterWeaponID: StarterWeapons.sword.id, seed: seed),
                                        tuning: .standard)
        let intent = PlayerIntent(move: CGPoint(x: 0.6, y: -0.3))
        for _ in 0..<steps {
            simulation.step(dt: Fixture.dt, intent: intent)
        }
        return simulation
    }

    func testSameSeedSameOutcome() {
        let a = run(seed: 99, steps: 600)
        let b = run(seed: 99, steps: 600)
        XCTAssertEqual(a.enemies.ids, b.enemies.ids)
        XCTAssertEqual(a.enemies.positions, b.enemies.positions)
        XCTAssertEqual(a.player.health, b.player.health)
        XCTAssertEqual(a.stats, b.stats)
    }

    func testEnemiesArriveAndTheSwordFights() {
        var simulation = run(seed: 7, steps: 60 * 20)
        XCTAssertGreaterThan(simulation.enemies.count + simulation.stats.kills, 0)
        simulation.spawnEnemies(40)
        for _ in 0..<(60 * 5) {
            simulation.step(dt: Fixture.dt, intent: .idle)
        }
        XCTAssertGreaterThan(simulation.stats.kills, 0)
        XCTAssertGreaterThan(simulation.stats.damageDealt, 0)
    }

    func testDeveloperCommands() {
        var simulation = run(seed: 3, steps: 1)
        simulation.spawnEnemies(25)
        XCTAssertEqual(simulation.enemies.count, 25)
        simulation.defeatAllEnemies()
        XCTAssertEqual(simulation.enemies.count, 0)
        XCTAssertEqual(simulation.stats.kills, 25)
    }

    func testFallenPlayerStopsFighting() {
        var simulation = run(seed: 5, steps: 1)
        simulation.cheats.spawningEnabled = false
        simulation.spawnEnemies(500)
        for _ in 0..<(60 * 60) where !simulation.isPlayerDefeated {
            simulation.step(dt: Fixture.dt, intent: .idle)
        }
        XCTAssertTrue(simulation.isPlayerDefeated)
        let dealt = simulation.stats.damageDealt
        _ = simulation.drainEvents()
        for _ in 0..<120 {
            simulation.step(dt: Fixture.dt, intent: PlayerIntent(move: CGPoint(x: 1, y: 0)))
        }
        XCTAssertEqual(simulation.stats.damageDealt, dealt)
        XCTAssertNotNil(simulation.timeSinceDefeat)
    }
}
