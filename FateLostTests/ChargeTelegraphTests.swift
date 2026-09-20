import CoreGraphics
import XCTest
@testable import FateLost

/// A charge has to be something a player can beat with their feet. The boss
/// commits to a line when its windup begins, holds it, and only then runs it,
/// so stepping off the line is an answer; and it does not do it so often that
/// the answer has no room to be made.
final class ChargeTelegraphTests: XCTestCase {
    private let world = ToroidalWorld(width: 128, height: 128)
    private let dt: TimeInterval = 1.0 / 60.0

    private func combat() -> CombatState {
        CombatState(world: world, tuning: CombatTuning(), gridCellSize: 1.5, capacity: 16, seed: 1)
    }

    private func add(_ definition: EnemyDefinition, at position: CGPoint, to combat: inout CombatState) {
        let kind = combat.enemies.kindIndex(for: definition)
        let id = combat.makeEntityID()
        combat.enemies.append(id: id, kind: kind, position: position, speedScale: 1)
    }

    private func tick(_ ai: inout EnemyAISystem, _ combat: inout CombatState, _ player: inout PlayerState) {
        player.invulnerability = max(0, player.invulnerability - dt)
        combat.rebuildGrid()
        ai.step(&combat, player: &player, godMode: false, dt: dt)
    }

    func testTheBossCommitsToALineAndDoesNotFollowTheHeroOffIt() {
        var ai = EnemyAISystem(tuning: EnemyAITuning(), combatTuning: CombatTuning())
        var state = combat()
        var player = PlayerState(position: world.center, maxHealth: 1000)
        add(EnemyCatalog.bossWarchief, at: player.position + CGPoint(x: 6, y: 0), to: &state)

        var guardTicks = 0
        while state.enemies.windup[0] == 0, guardTicks < 900 {
            tick(&ai, &state, &player)
            guardTicks += 1
        }
        XCTAssertGreaterThan(state.enemies.windup[0], 0, "the boss never wound up")

        // It is aiming at where the hero is standing: left of it.
        let aim = state.enemies.aim[0]
        XCTAssertEqual(aim.length, 1, accuracy: 0.01)
        XCTAssertLessThan(aim.x, -0.9)

        // The hero steps clear of that line. The boss must not follow.
        player.position = player.position + CGPoint(x: 0, y: 5)
        var charged = false
        for _ in 0..<240 {
            tick(&ai, &state, &player)
            if state.enemies.dash[0] != .zero {
                charged = true
                let direction = state.enemies.dash[0].normalized
                XCTAssertEqual(direction.x, aim.x, accuracy: 0.01, "it turned to follow the hero")
                XCTAssertEqual(direction.y, aim.y, accuracy: 0.01, "it turned to follow the hero")
                break
            }
        }
        XCTAssertTrue(charged, "the boss never charged")

        for _ in 0..<60 {
            tick(&ai, &state, &player)
        }
        XCTAssertEqual(player.health, 1000, "stepping aside should have dodged it")
    }

    func testStandingInTheLaneStillHurts() {
        var ai = EnemyAISystem(tuning: EnemyAITuning(), combatTuning: CombatTuning())
        var state = combat()
        var player = PlayerState(position: world.center, maxHealth: 1000)
        add(EnemyCatalog.bossWarchief, at: player.position + CGPoint(x: 6, y: 0), to: &state)
        for _ in 0..<600 {
            tick(&ai, &state, &player)
        }
        XCTAssertLessThan(player.health, 1000, "a charge that cannot hurt is not a threat")
    }

    func testTheAimIsClearedOnceTheChargeBegins() {
        var ai = EnemyAISystem(tuning: EnemyAITuning(), combatTuning: CombatTuning())
        var state = combat()
        var player = PlayerState(position: world.center, maxHealth: 1000)
        add(EnemyCatalog.bossWarchief, at: player.position + CGPoint(x: 6, y: 0), to: &state)
        for _ in 0..<600 where state.enemies.dash[0] == .zero {
            tick(&ai, &state, &player)
        }
        XCTAssertNotEqual(state.enemies.dash[0], .zero)
        XCTAssertEqual(state.enemies.aim[0], .zero, "a stale lane would be drawn under the next charge")
    }

    func testTheBossWindsUpLongerAndChargesLessOftenThanItDid() {
        let boss = EnemyCatalog.bossWarchief
        // It used to wind up for 0.6 s and rest for 1.5 s.
        XCTAssertGreaterThanOrEqual(boss.attackWindup, 1.0, "not enough warning")
        XCTAssertGreaterThanOrEqual(boss.attackWindup + boss.attackCooldown, 4.0, "still charging too often")
    }

    func testEveryChargingChampionGivesAFairWarning() {
        for realm in RealmCatalog.all {
            for id in EnemyCatalog.bosses(for: realm.id) {
                guard let boss = EnemyCatalog.definition(for: id), case .charger = boss.behavior else { continue }
                XCTAssertGreaterThanOrEqual(boss.attackWindup, 0.9, "\(boss.name) charges with too little warning")
            }
        }
    }

    func testTheFirstRealmsArchersFireAboutAThirdLessOftenAgain() {
        let archer = EnemyCatalog.goblinArcher
        // A shot used to come every 0.55 + 2.5 seconds.
        let before = 0.55 + 2.5
        let now = archer.attackWindup + archer.attackCooldown
        let reduction = 1 - before / now
        XCTAssertGreaterThanOrEqual(reduction, 0.28, "the archers were not slowed enough")
        XCTAssertLessThanOrEqual(reduction, 0.38, "the archers were slowed too much")
    }

    func testArchersAreRareAndNotInTheFirstTwoWaves() {
        let archer = EnemyCatalog.goblinArcher
        XCTAssertLessThanOrEqual(archer.spawnWeight, 0.2)
        XCTAssertGreaterThanOrEqual(archer.earliestWave, 3)
    }

    func testTheArchersDamageAndRangeAreUntouched() {
        let archer = EnemyCatalog.goblinArcher
        XCTAssertEqual(archer.attackDamage, 8)
        if case .ranged(let range, _, _) = archer.behavior {
            XCTAssertEqual(range, 7)
        } else {
            XCTFail("the archer stopped being a shooter")
        }
    }
}
