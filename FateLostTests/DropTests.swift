import CoreGraphics
import XCTest
@testable import FateLost

/// Chests are meant to be events. These tests hold the drop rates stingy at
/// the bottom and certain at the top, and check that walking onto a chest is
/// what opens it, one at a time.
final class DropTests: XCTestCase {
    private static let world = ToroidalWorld(width: 128, height: 128)

    private func makeCombat(seed: UInt64 = 3) -> CombatState {
        CombatState(world: Self.world, tuning: CombatTuning(), gridCellSize: 1.5, capacity: 64, seed: seed)
    }

    private func first(_ rank: EnemyRank) -> EnemyDefinition {
        guard let found = EnemyCatalog.all.first(where: { $0.rank == rank }) else {
            XCTFail("no \(rank) in the catalogue")
            return EnemyCatalog.all[0]
        }
        return found
    }

    private func chestTiers(in combat: CombatState) -> [LootTier] {
        combat.drops.compactMap { drop in
            if case .chest(let tier) = drop.kind { return tier }
            return nil
        }
    }

    // MARK: What falls

    func testAChampionAlwaysLeavesAChestAndSomeDraughts() {
        var combat = makeCombat()
        combat.dropLoot(for: EnemyCatalog.bossWarchief, at: .zero)
        XCTAssertEqual(chestTiers(in: combat), [.chest])
        XCTAssertEqual(combat.drops.filter { $0.kind == .vial }.count, DropTable.bossVials)
    }

    func testALateChampionLeavesAHoard() {
        var combat = makeCombat()
        combat.stats.wave = DropTable.hoardWave
        combat.dropLoot(for: EnemyCatalog.bossWarchief, at: .zero)
        XCTAssertEqual(chestTiers(in: combat), [.hoard])
    }

    func testElitesSometimesLeaveACacheAndNothingRicherThanOne() {
        var combat = makeCombat()
        let elite = first(.elite)
        for _ in 0..<600 {
            combat.dropLoot(for: elite, at: .zero)
            combat.drops.removeAll { drop in
                if case .chest(.cache) = drop.kind { return false }
                return true
            }
        }
        let caches = chestTiers(in: combat).count
        XCTAssertGreaterThan(caches, 90, "elites almost never leave anything")
        XCTAssertLessThan(caches, 260, "elites leave a cache far too often")
        XCTAssertTrue(chestTiers(in: combat).allSatisfy { $0 == .cache })
    }

    func testTheHordeNeverLeavesAChestAndRarelyLeavesAnything() {
        var combat = makeCombat()
        let minion = first(.minion)
        var drops = 0
        for _ in 0..<2_000 {
            combat.dropLoot(for: minion, at: .zero)
            drops += combat.drops.count
            combat.drops.removeAll()
        }
        XCTAssertGreaterThan(drops, 5, "the horde never leaves a draught")
        XCTAssertLessThan(drops, 90, "the horde leaves too much")
    }

    func testTheGroundNeverFillsWithDraughts() {
        var combat = makeCombat()
        for _ in 0..<200 {
            combat.place(.vial, near: .zero, scatter: 1)
        }
        XCTAssertEqual(combat.drops.count, DropTable.looseLimit)
        combat.place(.chest(.hoard), near: .zero, scatter: 0)
        XCTAssertEqual(chestTiers(in: combat), [.hoard], "a find was lost to clutter")
    }

    func testLootHasItsOwnRandomStream() {
        var one = makeCombat()
        var two = makeCombat()
        let before = one.random.unit()
        _ = two.random.unit()
        for _ in 0..<50 {
            two.dropLoot(for: first(.minion), at: .zero)
        }
        XCTAssertEqual(one.random.unit(), two.random.unit(), "rolling drops disturbed combat's randomness")
        _ = before
    }

    // MARK: Picking up

    func testWalkingOntoAChestQueuesAFindAndRemovesIt() {
        var combat = makeCombat()
        let player = PlayerState(position: CGPoint(x: 64, y: 64), maxHealth: 100)
        combat.place(.chest(.chest), near: player.position, scatter: 0)
        PickupSystem.step(&combat, player: player, dt: 1.0 / 60)
        XCTAssertEqual(combat.pendingFinds, [.chest])
        XCTAssertTrue(combat.drops.isEmpty)
    }

    func testAChestOutOfReachStaysPutEvenInsideThePickupRadius() {
        var combat = makeCombat()
        let player = PlayerState(position: CGPoint(x: 64, y: 64), maxHealth: 100)
        combat.place(.chest(.chest), near: CGPoint(x: 65.4, y: 64), scatter: 0)
        for _ in 0..<120 {
            PickupSystem.step(&combat, player: player, dt: 1.0 / 60)
        }
        XCTAssertTrue(combat.pendingFinds.isEmpty, "a chest was drawn in like an ember")
        XCTAssertEqual(combat.drops.count, 1)
    }

    func testACacheExpiresButAChestDoesNot() {
        var combat = makeCombat()
        let player = PlayerState(position: CGPoint(x: 10, y: 10), maxHealth: 100)
        combat.place(.chest(.cache), near: CGPoint(x: 90, y: 90), scatter: 0)
        combat.place(.chest(.chest), near: CGPoint(x: 100, y: 100), scatter: 0)
        var elapsed = 0.0
        while elapsed < DropTable.cacheLifetime + 5 {
            PickupSystem.step(&combat, player: player, dt: 1)
            elapsed += 1
        }
        XCTAssertEqual(chestTiers(in: combat), [.chest])
    }

    func testAVialHealsAQuarterOfMaxHealth() {
        var combat = makeCombat()
        let player = PlayerState(position: CGPoint(x: 64, y: 64), maxHealth: 200)
        combat.place(.vial, near: CGPoint(x: 64.5, y: 64), scatter: 0)
        for _ in 0..<60 {
            PickupSystem.step(&combat, player: player, dt: 1.0 / 60)
        }
        XCTAssertTrue(combat.drops.isEmpty)
        XCTAssertEqual(combat.pendingHealing, 200 * DropTable.vialHeal, accuracy: 0.001)
    }

    func testAVialFarAwayIsLeftAlone() {
        var combat = makeCombat()
        let player = PlayerState(position: CGPoint(x: 64, y: 64), maxHealth: 100)
        combat.place(.vial, near: CGPoint(x: 80, y: 64), scatter: 0)
        for _ in 0..<60 {
            PickupSystem.step(&combat, player: player, dt: 1.0 / 60)
        }
        XCTAssertEqual(combat.drops.count, 1)
        XCTAssertEqual(combat.pendingHealing, 0)
    }

    func testAMagnetDrawsEveryEmberInAtOnce() {
        var combat = makeCombat()
        let player = PlayerState(position: CGPoint(x: 64, y: 64), maxHealth: 100)
        for x in stride(from: 20.0, to: 40.0, by: 4.0) {
            combat.dropExperience(3, at: CGPoint(x: x, y: 20))
        }
        combat.place(.magnet, near: CGPoint(x: 64.5, y: 64), scatter: 0)
        for _ in 0..<10 {
            PickupSystem.step(&combat, player: player, dt: 1.0 / 60)
        }
        XCTAssertFalse(combat.orbs.isEmpty)
        XCTAssertTrue(combat.orbs.allSatisfy { $0.attracted }, "the magnet left some embers where they were")
    }

    func testAFallenPlayerCollectsNothing() {
        var combat = makeCombat()
        var player = PlayerState(position: CGPoint(x: 64, y: 64), maxHealth: 100)
        player.health = 0
        combat.place(.chest(.chest), near: player.position, scatter: 0)
        PickupSystem.step(&combat, player: player, dt: 1.0 / 60)
        XCTAssertTrue(combat.pendingFinds.isEmpty)
    }

    // MARK: In a run

    private func makeSimulation() -> GameSimulation {
        GameSimulation(run: RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 7),
                       tuning: .standard)
    }

    func testStandingOnAChestOpensAnOffer() {
        var simulation = makeSimulation()
        simulation.cheats.spawningEnabled = false
        simulation.spawnDrop(.chest(.chest))
        XCTAssertNil(simulation.offer)
        simulation.step(dt: 1.0 / 60, intent: .idle)
        XCTAssertNotNil(simulation.offer)
        XCTAssertEqual(simulation.offer?.tier, .chest)
    }

    func testASecondChestWaitsForTheFirstToBeAnswered() {
        var simulation = makeSimulation()
        simulation.cheats.spawningEnabled = false
        simulation.spawnDrop(.chest(.cache))
        simulation.spawnDrop(.chest(.hoard))
        for _ in 0..<5 {
            simulation.step(dt: 1.0 / 60, intent: .idle)
        }
        let firstTier = simulation.offer?.tier
        XCTAssertNotNil(firstTier)
        XCTAssertTrue(simulation.chooseRelic(at: 0))
        XCTAssertNil(simulation.offer)

        simulation.step(dt: 1.0 / 60, intent: .idle)
        XCTAssertNotNil(simulation.offer, "the second chest never opened")
        XCTAssertNotEqual(simulation.offer?.tier, firstTier)
    }
}
