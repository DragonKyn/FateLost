import CoreGraphics
import XCTest
@testable import FateLost

/// A shrine is a bargain, so the rules that matter are the ones that keep it
/// honest: it never kills you, it never stacks a curse on a curse, an unused
/// one is not wasted by walking past, and each one does what it says.
final class ShrineTests: XCTestCase {
    private static let world = ToroidalWorld(width: 128, height: 128)

    private func makeCombat(seed: UInt64 = 3) -> CombatState {
        CombatState(world: Self.world, tuning: CombatTuning(), gridCellSize: 1.5, capacity: 64, seed: seed)
    }

    private func player(health: Double = 100) -> PlayerState {
        var state = PlayerState(position: CGPoint(x: 64, y: 64), maxHealth: 100)
        state.health = health
        return state
    }

    // MARK: Where they rise

    func testNoShrineRisesOnABossWave() {
        var combat = makeCombat()
        for _ in 0..<200 {
            ShrineSystem.waveBegan(5, isBossWave: true, &combat, player: player())
        }
        XCTAssertTrue(combat.shrines.isEmpty)
    }

    func testShrinesRiseOftenEnoughToMeetButNotEveryWave() {
        var combat = makeCombat()
        var raised = 0
        for _ in 0..<400 {
            combat.shrines.removeAll()
            ShrineSystem.waveBegan(6, isBossWave: false, &combat, player: player())
            raised += combat.shrines.count
        }
        XCTAssertGreaterThan(raised, 160)
        XCTAssertLessThan(raised, 280)
    }

    func testNoMoreThanTwoStandAtOnce() {
        var combat = makeCombat()
        for _ in 0..<200 {
            ShrineSystem.waveBegan(6, isBossWave: false, &combat, player: player())
        }
        XCTAssertEqual(combat.shrines.count, ShrineTuning.maxActive)
    }

    func testRuinWaitsForALaterWave() {
        var early = makeCombat()
        for _ in 0..<300 {
            early.shrines.removeAll()
            ShrineSystem.waveBegan(2, isBossWave: false, &early, player: player())
            XCTAssertFalse(early.shrines.contains { $0.kind == .ruin }, "ruin came too early")
        }
        var late = makeCombat()
        var sawRuin = false
        for _ in 0..<300 {
            late.shrines.removeAll()
            ShrineSystem.waveBegan(8, isBossWave: false, &late, player: player())
            if late.shrines.contains(where: { $0.kind == .ruin }) { sawRuin = true }
        }
        XCTAssertTrue(sawRuin, "ruin never appeared")
    }

    func testAShrineRisesWithinReachOfThePlayerButNotOnTopOfThem() {
        var combat = makeCombat()
        let hero = player()
        for _ in 0..<200 {
            combat.shrines.removeAll()
            ShrineSystem.waveBegan(6, isBossWave: false, &combat, player: hero)
            for shrine in combat.shrines {
                let distance = Double(combat.world.distance(shrine.position, hero.position))
                XCTAssertGreaterThanOrEqual(distance, ShrineTuning.nearest - 0.001)
                XCTAssertLessThanOrEqual(distance, ShrineTuning.farthest + 0.001)
            }
        }
    }

    // MARK: Walking onto one

    func testWalkingOntoAShrineTakesItUp() {
        var combat = makeCombat()
        combat.shrines.append(Shrine(id: 1, kind: .fortune, position: CGPoint(x: 64.5, y: 64)))
        ShrineSystem.step(&combat, player: player(), dt: 1.0 / 60)
        XCTAssertEqual(combat.pendingShrines, [.fortune])
        XCTAssertTrue(combat.shrines.isEmpty)
    }

    func testAShrineOutOfReachIsLeftAlone() {
        var combat = makeCombat()
        combat.shrines.append(Shrine(id: 1, kind: .fortune, position: CGPoint(x: 70, y: 64)))
        ShrineSystem.step(&combat, player: player(), dt: 1.0 / 60)
        XCTAssertTrue(combat.pendingShrines.isEmpty)
        XCTAssertEqual(combat.shrines.count, 1)
    }

    func testBloodRefusesAHeroTooWeakToPayAndIsNotWasted() {
        var combat = makeCombat()
        combat.shrines.append(Shrine(id: 1, kind: .blood, position: CGPoint(x: 64, y: 64)))
        ShrineSystem.step(&combat, player: player(health: 30), dt: 1.0 / 60)
        XCTAssertTrue(combat.pendingShrines.isEmpty)
        XCTAssertEqual(combat.shrines.count, 1, "a refused shrine was consumed")

        ShrineSystem.step(&combat, player: player(health: 90), dt: 1.0 / 60)
        XCTAssertEqual(combat.pendingShrines, [.blood])
    }

    func testRuinRefusesToStackOnAnExistingCurse() {
        var combat = makeCombat()
        combat.curseRemaining = 20
        combat.shrines.append(Shrine(id: 1, kind: .ruin, position: CGPoint(x: 64, y: 64)))
        ShrineSystem.step(&combat, player: player(), dt: 1.0 / 60)
        XCTAssertTrue(combat.pendingShrines.isEmpty)
        XCTAssertEqual(combat.shrines.count, 1)
    }

    func testAnUnusedShrineIsTakenBackEventually() {
        var combat = makeCombat()
        combat.shrines.append(Shrine(id: 1, kind: .fortune, position: CGPoint(x: 100, y: 100)))
        var elapsed = 0.0
        while elapsed < ShrineTuning.lifetime + 5 {
            ShrineSystem.step(&combat, player: player(), dt: 1)
            elapsed += 1
        }
        XCTAssertTrue(combat.shrines.isEmpty)
    }

    func testAFallenHeroAgreesToNothing() {
        var combat = makeCombat()
        combat.shrines.append(Shrine(id: 1, kind: .fortune, position: CGPoint(x: 64, y: 64)))
        ShrineSystem.step(&combat, player: player(health: 0), dt: 1.0 / 60)
        XCTAssertTrue(combat.pendingShrines.isEmpty)
    }

    // MARK: In a run

    private func makeSimulation() -> GameSimulation {
        var simulation = GameSimulation(run: RunConfiguration(realmID: .ashenWilds,
                                                              starterWeaponID: StarterWeapons.sword.id, seed: 7),
                                        tuning: .standard)
        simulation.cheats.spawningEnabled = false
        return simulation
    }

    func testBloodCostsHealthNeverKillsAndBuysAChest() {
        var simulation = makeSimulation()
        let before = simulation.player.health
        simulation.spawnShrine(.blood)
        simulation.step(dt: 1.0 / 60, intent: .idle)
        XCTAssertLessThan(simulation.player.health, before)
        XCTAssertGreaterThanOrEqual(simulation.player.health, 1)
        XCTAssertEqual(simulation.player.health, before - simulation.player.maxHealth * ShrineTuning.bloodCost,
                       accuracy: 0.5)
        XCTAssertEqual(simulation.offer?.tier, .chest, "the price was paid and nothing was given")
    }

    func testFortuneGivesExperienceAndCostsNothing() {
        var simulation = makeSimulation()
        let before = simulation.player.health
        let experience = simulation.progression.experience
        simulation.spawnShrine(.fortune)
        for _ in 0..<120 {
            simulation.step(dt: 1.0 / 60, intent: .idle)
        }
        XCTAssertGreaterThanOrEqual(simulation.player.health, before)
        let gained = simulation.progression.level > 1 || simulation.progression.experience > experience
        XCTAssertTrue(gained, "a blessing gave nothing")
        XCTAssertNil(simulation.offer)
    }

    func testRuinCursesTheRealmForAHoardAndThenLetsGo() {
        var simulation = makeSimulation()
        let before = simulation.combat.enemyDamageScale
        simulation.spawnShrine(.ruin)
        simulation.step(dt: 1.0 / 60, intent: .idle)
        XCTAssertEqual(simulation.offer?.tier, .hoard)
        XCTAssertGreaterThan(simulation.curseRemaining, ShrineTuning.curseSeconds - 1)

        // Hold the game still on the offer, run the curse out by answering it.
        XCTAssertTrue(simulation.chooseRelic(at: 0))
        simulation.step(dt: 1.0 / 60, intent: .idle)
        let cursed = simulation.combat.enemyDamageScale
        XCTAssertGreaterThan(cursed, before * 1.25, "the curse did not bite")

        for _ in 0..<(Int(ShrineTuning.curseSeconds) + 5) {
            simulation.step(dt: 1, intent: .idle)
        }
        XCTAssertEqual(simulation.curseRemaining, 0)
        XCTAssertLessThan(simulation.combat.enemyDamageScale, cursed, "the curse never lifted")
    }
}
