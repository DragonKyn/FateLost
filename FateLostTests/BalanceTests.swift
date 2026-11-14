import CoreGraphics
import XCTest
@testable import FateLost

/// The limits that keep a strong build from becoming an unkillable one, or
/// one blast from erasing the screen.
final class BalanceTests: XCTestCase {
    private func simulation(tuning: GameTuning = .standard) -> GameSimulation {
        var sim = GameSimulation(run: RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id,
                                                       seed: 5),
                                 tuning: tuning)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        return sim
    }

    // MARK: Sustain

    func testStackedAurasLifeStealAndRegenerationShareOneCeiling() {
        var sim = simulation()
        sim.player.maxHealth = 300
        sim.player.health = 1
        // Every steady source at once, far past anything sane: Hallowed Ground,
        // Renewal, Consecration and an Anthem on top of passive regeneration,
        // plus a screen's worth of life steal and kill-triggered heals.
        sim.combat.sheet.add(StatModifier(.healthRegen, .flat, 120))
        sim.combat.sheet.finalize()
        sim.combat.pendingSustain = 900
        let before = sim.player.health
        sim.applyHealing(1)
        let gained = sim.player.health - before
        let ceiling = 300 * PlayerTuning().regenCeilingFraction
        XCTAssertLessThanOrEqual(gained, ceiling + 0.01, "steady healing never passes the ceiling")
        XCTAssertGreaterThan(gained, ceiling * 0.9, "but a stacked build sits close to it")
    }

    func testACastHealStillLandsInFull() {
        var sim = simulation()
        sim.player.maxHealth = 200
        sim.player.health = 20
        sim.combat.pendingHealing = 100
        sim.applyHealing(1.0 / 60)
        XCTAssertEqual(sim.player.health, 120, accuracy: 0.01, "a heal the player chose to cast is not capped")
    }

    func testLifeStealIsSteadySustainNotABurst() {
        var sim = simulation()
        sim.player.maxHealth = 200
        sim.player.health = 10
        sim.combat.sheet.add(StatModifier(.lifeSteal, .flat, 0.25))
        sim.combat.sheet.finalize()
        // One enormous area hit in a single step.
        sim.combat.pendingSustain = 5_000 * 0.25
        sim.applyHealing(1.0 / 60)
        XCTAssertLessThan(sim.player.health - 10, 1, "a single step's life steal is bounded by the per-second ceiling")
    }

    func testHealingPastFullKeepsOnlyAPartialShield() {
        var sim = simulation()
        sim.player.maxHealth = 200
        sim.player.health = 200
        sim.combat.sheet.add(StatModifier(.overhealBarrier, .flat, 1))
        sim.combat.sheet.finalize()
        for _ in 0..<50 {
            sim.combat.pendingHealing = 200
            sim.applyHealing(1.0 / 60)
        }
        XCTAssertEqual(sim.player.barrier, 200 * PlayerTuning().overhealBarrierFraction, accuracy: 0.01)
    }

    func testDefenceCapsLeaveEveryBlowSomeBite() {
        var sheet = StatSheet()
        sheet.add(StatModifier(.dodgeChance, .flat, 5))
        sheet.add(StatModifier(.healingReceived, .increased, 50))
        sheet.add(StatModifier(.areaSize, .increased, 50))
        sheet.finalize()
        XCTAssertEqual(sheet[.dodgeChance], 0.5)
        XCTAssertEqual(sheet[.healingReceived], 2)
        XCTAssertEqual(sheet[.areaSize], 2.5)
        XCTAssertEqual(BalanceTuning.maximumArmorReduction, 0.75)
    }

    // MARK: Area damage

    func testCrowdScaleIsFullForSmallGroupsAndEasesForHordes() {
        for count in 0...BalanceTuning.fullDamageTargets {
            XCTAssertEqual(BalanceTuning.crowdScale(count), 1)
        }
        XCTAssertEqual(BalanceTuning.crowdScale(32), 0.5, accuracy: 0.0001)
        var previousTotal = 0.0
        for count in stride(from: 8, through: 120, by: 4) {
            let total = BalanceTuning.crowdScale(count) * Double(count)
            XCTAssertGreaterThan(total, previousTotal, "a bigger crowd is always worth more damage in total")
            previousTotal = total
        }
    }

    func testANovaIntoAHordeHitsEachEnemySofterThanIntoAFew() {
        let few = damagePerEnemy(enemies: 4)
        let horde = damagePerEnemy(enemies: 32)
        XCTAssertEqual(horde / few, 0.5, accuracy: 0.001)
    }

    func testChainsOfTriggeredEffectsFadeWithDepth() {
        XCTAssertEqual(BalanceTuning.depthScale(0), 1)
        XCTAssertEqual(BalanceTuning.depthScale(1), 1)
        XCTAssertEqual(BalanceTuning.depthScale(2), 0.7, accuracy: 0.0001)
        XCTAssertEqual(BalanceTuning.depthScale(4), 0.343, accuracy: 0.0001)
        let combat = simulation().combat
        let spec = DamageSpec(RankValue(1), .fire, tags: .area)
        let direct = combat.hit(from: spec, direction: .zero, depth: 1, source: .proc).amount
        let deep = combat.hit(from: spec, direction: .zero, depth: 3, source: .proc).amount
        XCTAssertEqual(deep / direct, 0.49, accuracy: 0.0001)
    }

    /// Health one enemy lost to a nova that caught `enemies` of them.
    private func damagePerEnemy(enemies: Int) -> Double {
        // No crits and no damage roll, so the comparison is exact.
        var tuning = GameTuning.standard
        tuning.combat.critChance = 0
        tuning.combat.damageVariance = 0
        var sim = simulation(tuning: tuning)
        let center = sim.player.position
        for slot in 0..<enemies {
            let angle = Double(slot) / Double(enemies) * 2 * .pi
            let offset = CGPoint(x: CGFloat(cos(angle)) * 1.5, y: CGFloat(sin(angle)) * 1.5)
            let kind = sim.combat.enemies.kindIndex(for: EnemyCatalog.goblin)
            sim.combat.enemies.append(id: sim.combat.makeEntityID(), kind: kind,
                                      position: sim.world.wrap(center + offset), speedScale: 1)
        }
        for index in 0..<sim.combat.enemies.count {
            sim.combat.enemies.health[index] = 1_000_000
        }
        sim.combat.rebuildGrid()
        let spec = DamageSpec(RankValue(1), .physical, tags: .area, knockback: 0)
        var combat = sim.combat
        combat.sheet = StatSheet()
        combat.sheet.finalize()
        ActionExecutor.affect(around: center, radius: 3, damage: spec, status: nil, depth: 0, source: .ability,
                              &combat)
        let lost = (0..<combat.enemies.count).map { 1_000_000 - combat.enemies.health[$0] }
        return lost.reduce(0, +) / Double(lost.count)
    }
}
