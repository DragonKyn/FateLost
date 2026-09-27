import CoreGraphics
import XCTest
@testable import FateLost

/// The rules behind the three advert rewards: stacking boon timers, doubling
/// only the echoes earned while Double Echoes runs, Rift's Calling, and the
/// once-per-run second chance that holds a solo run exactly as it stood.
final class AdRewardTests: XCTestCase {

    private func simulation(_ realm: RealmID = .ashenWilds, secondChance: Bool = true) -> GameSimulation {
        var sim = GameSimulation(run: RunConfiguration(realmID: realm, starterWeaponID: StarterWeapons.sword.id,
                                                       seed: 23),
                                 tuning: .standard)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        sim.offersSecondChance = secondChance
        return sim
    }

    @discardableResult
    private func place(_ definition: EnemyDefinition, in sim: inout GameSimulation, offset: CGPoint) -> Int {
        let kind = sim.combat.enemies.kindIndex(for: definition)
        let id = sim.combat.makeEntityID()
        sim.combat.enemies.append(id: id, kind: kind, position: sim.world.wrap(sim.player.position + offset),
                                  speedScale: 1)
        return id
    }

    private func steps(_ count: Int, _ sim: inout GameSimulation) {
        for _ in 0..<count { sim.step(dt: 1.0 / 60, intent: .idle) }
    }

    // MARK: Boon timers

    func testEachAdvertAddsTenMinutesOnTopOfWhatIsLeft() {
        var timers = BoonTimers()
        XCTAssertFalse(timers.isActive(.doubleEchoes))
        timers.grant(.doubleEchoes)
        XCTAssertEqual(timers.remaining(.doubleEchoes), 600, accuracy: 0.001)
        timers.grant(.doubleEchoes)
        XCTAssertEqual(timers.remaining(.doubleEchoes), 1200, accuracy: 0.001, "two adverts, twenty minutes")
        timers.grant(.doubleEchoes)
        XCTAssertEqual(timers.remaining(.doubleEchoes), 1800, accuracy: 0.001, "three adverts, thirty minutes")

        // Five minutes left, one more advert: fifteen.
        var partial = BoonTimers()
        partial.grant(.riftCalling)
        partial.consume(300)
        partial.grant(.riftCalling)
        XCTAssertEqual(partial.remaining(.riftCalling), 900, accuracy: 0.001)
        XCTAssertFalse(partial.isActive(.doubleEchoes), "each boon keeps its own time")
    }

    func testBoonsRunDownWithPlayAndStopAtZero() {
        var timers = BoonTimers()
        timers.grant(.doubleEchoes)
        timers.consume(599.5)
        XCTAssertTrue(timers.isActive(.doubleEchoes))
        XCTAssertEqual(timers.wholeSeconds(.doubleEchoes), 1, "a sliver still reads as running")
        timers.consume(10)
        XCTAssertEqual(timers.remaining(.doubleEchoes), 0)
        XCTAssertFalse(timers.isActive(.doubleEchoes))
        timers.consume(-50)
        timers.consume(.nan)
        XCTAssertEqual(timers.remaining(.doubleEchoes), 0)
    }

    func testBoonTimersSurviveASaveAndRejectNonsense() throws {
        var timers = BoonTimers()
        timers.grant(.doubleEchoes)
        timers.grant(.riftCalling)
        timers.consume(42)
        let data = try JSONEncoder().encode(timers)
        XCTAssertEqual(try JSONDecoder().decode(BoonTimers.self, from: data), timers)

        let hostile = Data(#"{"doubleEchoesSeconds": -30, "riftCallingSeconds": 1e300}"#.utf8)
        let decoded = try JSONDecoder().decode(BoonTimers.self, from: hostile)
        XCTAssertEqual(decoded.remaining(.doubleEchoes), 0)
        XCTAssertEqual(decoded.remaining(.riftCalling), BoonTuning.maximumSeconds)
        XCTAssertEqual(try JSONDecoder().decode(BoonTimers.self, from: Data("{}".utf8)), BoonTimers())
    }

    func testBoonStoreKeepsTimersBetweenLaunches() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("boons-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var timers = BoonTimers()
        timers.grant(.riftCalling)
        XCTAssertTrue(BoonStore(fileURL: url).save(timers))
        XCTAssertEqual(BoonStore(fileURL: url).load(), timers)
        BoonStore(fileURL: url).erase()
        XCTAssertEqual(BoonStore(fileURL: url).load(), BoonTimers())
    }

    // MARK: Double Echoes

    func testOnlyEchoesEarnedWhileTheBoonRanAreDoubled() {
        var tally = EchoBoostTally()
        XCTAssertEqual(tally.bonus(finalPayout: 300), 0, "never opened: nothing doubled")

        // Running from the start and still running at the end: the whole run doubles.
        tally.open(at: 0)
        XCTAssertEqual(tally.bonus(finalPayout: 300), 300)

        // Ran out partway: only what was earned up to then doubles.
        var expired = EchoBoostTally()
        expired.open(at: 0)
        expired.close(at: 120)
        XCTAssertEqual(expired.bonus(finalPayout: 300), 120)

        // Opened late (echoes already earned are not doubled retroactively).
        var late = EchoBoostTally()
        late.open(at: 50)
        XCTAssertEqual(late.bonus(finalPayout: 80), 30)
    }

    func testDoubleEchoesNeverExceedsTimesTwoOrPaysOnNothing() {
        var tally = EchoBoostTally()
        tally.open(at: 0)
        tally.open(at: 999)  // a second open is ignored, not stacked
        XCTAssertEqual(tally.openedAt, 0)
        XCTAssertEqual(tally.bonus(finalPayout: 200), 200, "×2 at most, never ×4")
        // A run that paid nothing (a fall in Fate's Echo before banking) gains nothing.
        XCTAssertEqual(tally.bonus(finalPayout: 0), 0)
        // Samples taken from a summary can wobble past the final: still capped.
        var wobble = EchoBoostTally()
        wobble.open(at: 0)
        wobble.close(at: 500)
        XCTAssertEqual(wobble.bonus(finalPayout: 400), 400)
    }

    func testTheBoonShareIsPaidOnlyOnRunsThatPaid() {
        var profile = LegacyProfile()
        let stats = RunStats()
        let won = RunSummary(realm: .ashenWilds, weapon: StarterWeapons.sword.id, secondsSurvived: 300,
                             stats: stats, level: 8, allocation: SkillAllocation(), outcome: .conquered, wave: 20)
        let realm = RealmCatalog.realm(.ashenWilds)
        let base = profile.payout(for: won, realm: realm)
        XCTAssertGreaterThan(base, 0)
        profile.record(won, realm: realm, extra: base)
        XCTAssertEqual(profile.echoes, base * 2)

        var echoProfile = LegacyProfile()
        let lost = RunSummary(realm: .fatesEcho, weapon: StarterWeapons.sword.id, secondsSurvived: 300,
                              stats: stats, level: 8, allocation: SkillAllocation(), outcome: .defeated, wave: 12)
        echoProfile.record(lost, realm: RealmCatalog.realm(.fatesEcho), extra: 500)
        XCTAssertEqual(echoProfile.echoes, 0, "a forfeited run is not paid by the boon either")
    }

    // MARK: Rift's Calling

    func testRiftsCallingRaisesTheRiftChanceByTenPoints() {
        XCTAssertEqual(BoonTuning.riftChanceBonus, 0.10, accuracy: 1e-9)
        var sim = simulation()
        XCTAssertEqual(sim.riftChanceBonus, 0)
        sim.riftChanceBonus = BoonTuning.riftChanceBonus
        XCTAssertEqual(GameTuning.standard.simulation.riftChance + sim.riftChanceBonus,
                       RiftTuning.chance + 0.10, accuracy: 1e-9)
    }

    // MARK: A second chance

    func testAFallHoldsTheRunExactlyAsItStood() {
        var sim = simulation()
        let id = place(EnemyCatalog.champions[0], in: &sim, offset: CGPoint(x: 4, y: 0))
        steps(3, &sim)
        guard let index = sim.combat.index(ofEnemy: id) else { return XCTFail("the champion is on the field") }
        sim.combat.enemies.statusMask[index] = 1
        let enemyHealth = sim.combat.enemies.health[index]
        let enemyPosition = sim.combat.enemies.positions[index]
        let elapsed = sim.elapsed
        let kills = sim.stats.kills
        let position = sim.player.position

        sim.player.health = 0
        steps(1, &sim)
        XCTAssertNotNil(sim.awaitingSecondChance, "the fall waits for the player's choice")
        XCTAssertEqual(sim.awaitingSecondChance?.position, position)

        steps(120, &sim)
        XCTAssertEqual(sim.elapsed, elapsed, accuracy: 1e-9, "no time passes while the choice waits")
        XCTAssertNil(sim.timeSinceDefeat, "the fall has not begun counting towards the summary")
        XCTAssertEqual(sim.combat.enemies.health[index], enemyHealth)
        XCTAssertEqual(sim.combat.enemies.positions[index], enemyPosition)
        XCTAssertEqual(sim.combat.enemies.statusMask[index], 1, "nothing the hero laid on the horde is torn down")
        XCTAssertEqual(sim.stats.kills, kills)
    }

    func testTakingTheSecondChanceRaisesTheHeroWhereTheyFell() {
        var sim = simulation()
        steps(2, &sim)
        let position = sim.player.position
        sim.player.addBurn(tickDamage: 50, ticks: 5, tickEvery: 0.5)
        sim.player.health = 0
        steps(1, &sim)
        _ = sim.drainEvents()

        XCTAssertTrue(sim.takeSecondChance())
        XCTAssertEqual(sim.player.health, sim.player.maxHealth * 0.5, accuracy: 1e-6)
        XCTAssertEqual(sim.player.position, position)
        XCTAssertGreaterThanOrEqual(sim.player.invulnerability, 2.0)
        XCTAssertTrue(sim.player.burns.isEmpty, "a burn cannot finish the job after the immunity")
        XCTAssertNil(sim.awaitingSecondChance)
        XCTAssertTrue(sim.secondChanceSpent)
        XCTAssertTrue(sim.drainEvents().contains { if case .heroRevived = $0 { return true } else { return false } })

        // Asked again (a repeated callback or tap): nothing more happens.
        sim.player.health = 10
        XCTAssertFalse(sim.takeSecondChance())
        XCTAssertEqual(sim.player.health, 10)

        let before = sim.elapsed
        steps(30, &sim)
        XCTAssertGreaterThan(sim.elapsed, before, "the run goes on")
    }

    func testTheImmunityCoversTheFirstTwoSeconds() {
        var sim = simulation()
        steps(2, &sim)
        sim.player.health = 0
        steps(1, &sim)
        sim.takeSecondChance()
        steps(Int(1.9 * 60), &sim)
        XCTAssertTrue(sim.player.isInvulnerable, "still protected just before two seconds")
        steps(12, &sim)
        XCTAssertFalse(sim.player.isInvulnerable, "and not for ever")
    }

    func testAFallAfterTheSecondChanceIsFinal() {
        var sim = simulation()
        steps(2, &sim)
        sim.player.health = 0
        steps(1, &sim)
        sim.takeSecondChance()
        steps(10, &sim)

        sim.player.health = 0
        steps(5, &sim)
        XCTAssertNil(sim.awaitingSecondChance, "one second chance a run")
        XCTAssertNotNil(sim.timeSinceDefeat, "the ordinary end of the run proceeds")
    }

    func testAcceptingFateEndsTheRunAsItAlwaysHas() {
        var sim = simulation()
        let id = place(EnemyCatalog.champions[0], in: &sim, offset: CGPoint(x: 5, y: 0))
        steps(2, &sim)
        guard let index = sim.combat.index(ofEnemy: id) else { return XCTFail("the champion is on the field") }
        sim.combat.enemies.statusMask[index] = 1
        sim.player.health = 0
        steps(1, &sim)
        XCTAssertNotNil(sim.awaitingSecondChance)

        sim.acceptFate()
        XCTAssertNil(sim.awaitingSecondChance)
        XCTAssertTrue(sim.secondChanceSpent)
        XCTAssertEqual(sim.combat.enemies.statusMask[index], 0, "what the hero held dies with them")
        steps(10, &sim)
        XCTAssertNotNil(sim.timeSinceDefeat)
        XCTAssertNil(sim.awaitingSecondChance, "accepting is final")
        XCTAssertFalse(sim.takeSecondChance(), "and cannot be undone")
    }

    func testWithoutTheOfferAFallIsNeverHeld() {
        var sim = simulation(secondChance: false)
        steps(2, &sim)
        sim.player.health = 0
        steps(5, &sim)
        XCTAssertNil(sim.awaitingSecondChance)
        XCTAssertNotNil(sim.timeSinceDefeat)
    }

    func testDyingToFateKeepsFateAsItWasThroughTheSecondChance() {
        var sim = simulation(.abyss)
        let id = place(EnemyCatalog.fate, in: &sim, offset: CGPoint(x: 6, y: 0))
        guard let index = sim.combat.index(ofEnemy: id) else { return XCTFail("Fate is on the field") }
        sim.waves.bossArrived(id: id, title: "Fate", health: sim.combat.enemies.health[index], &sim.combat)
        steps(2, &sim)
        guard let placed = sim.combat.index(ofEnemy: id) else { return XCTFail("Fate is still there") }
        // Wear some of the barrier down first, so there is something to keep.
        let barrier = sim.combat.enemies.barrier[placed]
        XCTAssertGreaterThan(barrier, 0)
        sim.combat.enemies.barrier[placed] = barrier * 0.4
        let health = sim.combat.enemies.health[placed]

        sim.player.health = 0
        steps(1, &sim)
        XCTAssertNotNil(sim.awaitingSecondChance)
        steps(60, &sim)
        XCTAssertEqual(sim.combat.enemies.barrier[placed], barrier * 0.4, accuracy: 1e-6)
        XCTAssertEqual(sim.combat.enemies.health[placed], health, accuracy: 1e-6)
        XCTAssertEqual(sim.wave.bossID, id, "the fight with Fate is still on")

        XCTAssertTrue(sim.takeSecondChance())
        XCTAssertEqual(sim.combat.index(ofEnemy: id), placed, "Fate was not rerolled or restarted")
        XCTAssertEqual(sim.combat.enemies.health[placed], health, accuracy: 1e-6)
        XCTAssertEqual(sim.combat.enemies.barrier[placed], barrier * 0.4, accuracy: 1e-6)
        XCTAssertEqual(sim.wave.bossID, id)
        XCTAssertFalse(sim.isRealmConquered)
    }
}
