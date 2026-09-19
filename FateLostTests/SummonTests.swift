import CoreGraphics
import XCTest
@testable import FateLost

/// Summons are no longer untouchable: they carry health, they can be cut
/// down, their kind waits before returning, and the player can send them
/// away. These tests pin that lifecycle down.
final class SummonTests: XCTestCase {
    private static let world = ToroidalWorld(width: 128, height: 128)

    private func makeCombat(level: Int = 1) -> CombatState {
        var combat = CombatState(world: Self.world, tuning: CombatTuning(), gridCellSize: 1.5, capacity: 64, seed: 7)
        combat.summonVitalityLevel = level
        combat.summonVitalityGrowth = 0.07
        return combat
    }

    private func spawn(_ spec: SummonSpec, into combat: inout CombatState, companionKey: String? = nil) {
        AllySystem.spawn(spec, around: .zero, duration: .infinity, companionKey: companionKey, slot: 0, of: 1,
                         &combat)
    }

    // MARK: Vitality

    func testSummonsWithVitalityCarryHealth() {
        var combat = makeCombat()
        spawn(SummonCatalog.tiger, into: &combat)
        let ally = combat.allies[0]
        XCTAssertTrue(ally.isMortal)
        XCTAssertGreaterThan(ally.maxHealth, 0)
        XCTAssertEqual(ally.health, ally.maxHealth)
        XCTAssertEqual(ally.healthFraction, 1)
    }

    func testConjuredBladesHaveNoBodyToCut() {
        var combat = makeCombat()
        spawn(SummonCatalog.blade, into: &combat)
        XCTAssertFalse(combat.allies[0].isMortal)
        // A blow simply passes through.
        XCTAssertFalse(AllySystem.wound(0, amount: 9_999, &combat))
        XCTAssertEqual(combat.allies.count, 1)
    }

    func testToughnessGrowsWithTheHero() {
        let early = SummonVitality.maxHealth(of: SummonCatalog.bear, level: 1, perLevel: 0.07)
        let late = SummonVitality.maxHealth(of: SummonCatalog.bear, level: 20, perLevel: 0.07)
        XCTAssertGreaterThan(late, early)
        // A sturdier summon is sturdier at every level.
        XCTAssertGreaterThan(SummonVitality.maxHealth(of: SummonCatalog.boneColossus, level: 5, perLevel: 0.07),
                             SummonVitality.maxHealth(of: SummonCatalog.skeleton, level: 5, perLevel: 0.07))
    }

    // MARK: Falling

    func testAWoundedSummonFallsAndLeavesAnEvent() {
        var combat = makeCombat()
        spawn(SummonCatalog.skeleton, into: &combat, companionKey: "companion.skeleton")
        let life = combat.allies[0].maxHealth

        XCTAssertFalse(AllySystem.wound(0, amount: life / 2, &combat))
        XCTAssertEqual(combat.allies.count, 1)
        XCTAssertEqual(combat.allies[0].timeSinceHurt, 0)

        XCTAssertTrue(AllySystem.wound(0, amount: life, &combat))
        XCTAssertTrue(combat.allies.isEmpty)
        XCTAssertEqual(combat.stats.summonsLost, 1)
        XCTAssertTrue(combat.events.contains { if case .allyFell = $0 { return true } else { return false } })
    }

    func testAFallenCompanionWaitsBeforeReturning() {
        var combat = makeCombat()
        let spec = SummonCatalog.tiger
        spawn(spec, into: &combat, companionKey: spec.key)
        AllySystem.wound(0, amount: 9_999, &combat)

        XCTAssertEqual(combat.summonCooldowns[spec.key], spec.resummonCooldown)
        AllySystem.tickCooldowns(&combat, dt: spec.resummonCooldown - 0.5)
        XCTAssertNotNil(combat.summonCooldowns[spec.key])
        AllySystem.tickCooldowns(&combat, dt: 1)
        XCTAssertNil(combat.summonCooldowns[spec.key], "the wait should end once it runs out")
    }

    // MARK: Dismissal

    func testDismissingSendsEveryAllyAway() {
        var combat = makeCombat()
        spawn(SummonCatalog.tiger, into: &combat, companionKey: "companion.tiger")
        spawn(SummonCatalog.blade, into: &combat)

        AllySystem.dismissAll(&combat)
        XCTAssertTrue(combat.allies.isEmpty)
        XCTAssertTrue(combat.companionsDismissed)

        // And they stay away while dismissed, however often the build syncs.
        AllySystem.syncCompanions(&combat, player: PlayerState(position: .zero, maxHealth: 100))
        XCTAssertTrue(combat.allies.isEmpty)
    }

    func testEveryMortalSummonHasAResummonWait() {
        for spec in SummonCatalog.all where spec.isMortal {
            XCTAssertGreaterThan(spec.resummonCooldown, 0, "\(spec.key) would return instantly")
        }
    }
}
