import XCTest
@testable import FateLost

final class PassiveHealingTests: XCTestCase {
    private let tuning = PlayerTuning()

    func testOrdinaryRegenerationCountsInFull() {
        // A hero at 200 health has a knee of 6 a second: one maxed passive sits under it.
        for raw in [0.0, 0.5, 1.5, 4.0, 6.0] {
            XCTAssertEqual(tuning.effectiveRegeneration(raw, maxHealth: 200), raw, accuracy: 0.0001)
        }
    }

    func testEachExtraPointIsWorthLessAndNothingPassesTheCeiling() {
        var previous = 0.0
        var previousGain = Double.greatestFiniteMagnitude
        for raw in stride(from: 0.0, through: 200.0, by: 2.0) {
            let effective = tuning.effectiveRegeneration(raw, maxHealth: 200)
            XCTAssertGreaterThanOrEqual(effective, previous, "more regeneration must never heal less")
            let gain = effective - previous
            XCTAssertLessThanOrEqual(gain, previousGain + 0.0001, "returns must diminish, not grow")
            XCTAssertLessThanOrEqual(effective, 200 * tuning.regenCeilingFraction + 0.0001)
            previous = effective
            previousGain = gain
        }
        XCTAssertGreaterThan(previous, 200 * tuning.regenCeilingFraction * 0.99, "a huge pile approaches the ceiling")
    }

    func testStackingSeveralMaxedSourcesIsNowFarFromAdditive() {
        // Verdant Blood, Inner Calm, a Legacy grain and a relic, each worth about 7 a second.
        let one = tuning.effectiveRegeneration(7, maxHealth: 200)
        let four = tuning.effectiveRegeneration(28, maxHealth: 200)
        XCTAssertLessThan(four, one * 2, "four sources must be worth well under double one")
        XCTAssertLessThanOrEqual(four, 12.0, "at most six percent of max health a second")
    }

    func testANegativeOrEmptyRegenerationPassesThrough() {
        XCTAssertEqual(tuning.effectiveRegeneration(0, maxHealth: 100), 0)
        XCTAssertEqual(tuning.effectiveRegeneration(-3, maxHealth: 100), 0)
        XCTAssertEqual(tuning.effectiveRegeneration(5, maxHealth: 0), 5)
    }

    func testWhatItIsWorthScalesWithMaxHealth() {
        let small = tuning.effectiveRegeneration(20, maxHealth: 100)
        let large = tuning.effectiveRegeneration(20, maxHealth: 400)
        XCTAssertLessThan(small, large, "a bigger hero regains more of the same raw regeneration")
    }

    func testAGroundedHeroWithStackedRegenerationHealsAtTheCappedRateInASimulation() {
        var sim = GameSimulation(run: RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 1),
                                 tuning: .standard)
        sim.player.maxHealth = 200
        sim.player.health = 10
        // Only permanent sources: put a big regen straight on the sheet.
        sim.combat.sheet.add(StatModifier(.healthRegen, .flat, 60))
        sim.combat.sheet.finalize()
        let before = sim.player.health
        sim.applyHealing(1)
        let gained = sim.player.health - before
        XCTAssertGreaterThan(gained, 6, "still worth having")
        XCTAssertLessThanOrEqual(gained, 12.01, "but capped at six percent of max health")
    }
}
