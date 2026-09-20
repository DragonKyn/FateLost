import CoreGraphics
import XCTest
@testable import FateLost

/// The wave clock decides when a run gets harder and when it asks for a
/// stand-up fight. These tests walk it through a boss wave from both ends:
/// the champion falling, and the champion never arriving.
final class WaveTests: XCTestCase {
    private static let world = ToroidalWorld(width: 128, height: 128)

    private func makeCombat() -> CombatState {
        CombatState(world: Self.world, tuning: CombatTuning(), gridCellSize: 1.5, capacity: 64, seed: 3)
    }

    private func plan(bossEvery: Int = 2, seconds: Double = 10, grace: Double = 1) -> WavePlan {
        WavePlan(waveSeconds: seconds, bossGraceSeconds: grace, bosses: ["boss.warchief"])
            .with(bossEvery: bossEvery)
    }

    /// Runs the clock for a while, collecting any champion it calls for.
    @discardableResult
    private func run(_ system: inout WaveSystem, _ combat: inout CombatState,
                     seconds: Double, step: Double = 0.5) -> EnemyKindID? {
        var due: EnemyKindID?
        var elapsed = 0.0
        while elapsed < seconds {
            if let called = system.step(&combat, dt: step) { due = called }
            elapsed += step
        }
        return due
    }

    private func addBoss(_ combat: inout CombatState, health: Double = 1_000) -> Int {
        let definition = EnemyCatalog.bossWarchief
        let kind = combat.enemies.kindIndex(for: definition)
        let id = combat.makeEntityID()
        combat.enemies.append(id: id, kind: kind, position: .zero, speedScale: 1)
        combat.enemies.health[combat.enemies.count - 1] = health
        return id
    }

    // MARK: Ordinary waves

    func testWavesAdvanceOnTheClock() {
        var system = WaveSystem(plan: plan(bossEvery: 100), conquestWave: nil)
        var combat = makeCombat()
        XCTAssertEqual(system.state.index, 1)
        run(&system, &combat, seconds: 10)
        XCTAssertEqual(system.state.index, 2)
        XCTAssertTrue(combat.events.contains { if case .waveBegan = $0 { return true } else { return false } })
    }

    func testPressureRisesAsWavesPass() {
        var system = WaveSystem(plan: plan(bossEvery: 100), conquestWave: nil)
        var combat = makeCombat()
        let early = system.pressure
        run(&system, &combat, seconds: 50)
        XCTAssertGreaterThan(system.pressure, early)
    }

    // MARK: Champions

    func testABossWaveCallsForAChampionAndHoldsTheWaveOpen() {
        var system = WaveSystem(plan: plan(), conquestWave: nil)
        var combat = makeCombat()

        let due = run(&system, &combat, seconds: 12)
        XCTAssertEqual(due, "boss.warchief")

        let id = addBoss(&combat)
        system.bossArrived(id: id, title: "Grask", health: 1_000, &combat)
        XCTAssertTrue(system.state.isBossActive)
        XCTAssertEqual(system.state.bossHealthFraction, 1)
        XCTAssertLessThan(system.spawnShare, 1, "the horde should thin out for a champion")

        // The wave does not move on while the champion is up.
        let wave = system.state.index
        run(&system, &combat, seconds: 30)
        XCTAssertEqual(system.state.index, wave)
    }

    func testTheWaveMovesOnOnceTheChampionFalls() {
        var system = WaveSystem(plan: plan(), conquestWave: nil)
        var combat = makeCombat()
        run(&system, &combat, seconds: 12)
        let id = addBoss(&combat)
        system.bossArrived(id: id, title: "Grask", health: 1_000, &combat)

        combat.enemies.health[0] = 0
        combat.events.removeAll()
        _ = system.step(&combat, dt: 0.5)

        XCTAssertFalse(system.state.isBossActive)
        XCTAssertEqual(system.state.phase, .fighting)
        XCTAssertTrue(combat.events.contains { if case .bossDefeated = $0 { return true } else { return false } })
    }

    func testFellingTheConquestChampionTakesTheRealm() {
        var system = WaveSystem(plan: plan(), conquestWave: 2)
        var combat = makeCombat()
        run(&system, &combat, seconds: 12)
        let id = addBoss(&combat)
        system.bossArrived(id: id, title: "Grask", health: 1_000, &combat)

        combat.enemies.health[0] = 0
        combat.events.removeAll()
        _ = system.step(&combat, dt: 0.5)

        XCTAssertEqual(system.state.phase, .conquered)
        XCTAssertEqual(system.spawnShare, 0, "a conquered realm stops sending anything")
        XCTAssertTrue(combat.events.contains { if case .realmConquered = $0 { return true } else { return false } })
    }

    func testAChampionThatNeverArrivesDoesNotStallTheRun() {
        var system = WaveSystem(plan: plan(), conquestWave: nil)
        var combat = makeCombat()
        run(&system, &combat, seconds: 12)

        system.abandonBossWave()
        XCTAssertEqual(system.state.phase, .fighting)

        let wave = system.state.index
        run(&system, &combat, seconds: 12)
        XCTAssertEqual(system.state.index, wave + 1, "the clock should be running again")
    }

    // MARK: A party's breather

    private func partySystem(bossEvery: Int = 100, rest: Double = 30) -> WaveSystem {
        var system = WaveSystem(plan: plan(bossEvery: bossEvery), conquestWave: nil)
        system.restEvery = 2
        system.restSeconds = rest
        system.setElectorate([0, 1])
        return system
    }

    func testAPartyRestsAfterEverySecondWaveAndNotAfterTheFirst() {
        var system = partySystem()
        var combat = makeCombat()
        run(&system, &combat, seconds: 10)
        XCTAssertEqual(system.state.index, 2, "no breather after wave one")
        XCTAssertEqual(system.state.phase, .fighting)

        run(&system, &combat, seconds: 10)
        XCTAssertEqual(system.state.phase, .resting, "a breather after wave two")
        XCTAssertEqual(system.state.index, 2, "the next wave has not begun")
        XCTAssertEqual(system.spawnShare, 0, "nothing arrives while resting")

        run(&system, &combat, seconds: 30)
        XCTAssertEqual(system.state.phase, .fighting)
        XCTAssertEqual(system.state.index, 3)
        XCTAssertEqual(system.spawnShare, 1)
    }

    func testTheBreatherCountsDownAndLastsThirtySeconds() {
        var system = partySystem()
        var combat = makeCombat()
        run(&system, &combat, seconds: 20)
        XCTAssertEqual(system.state.restRemaining, 30, accuracy: 0.6)
        run(&system, &combat, seconds: 15)
        XCTAssertEqual(system.state.restRemaining, 15, accuracy: 0.6)
        run(&system, &combat, seconds: 14)
        XCTAssertEqual(system.state.phase, .resting)
        run(&system, &combat, seconds: 2)
        XCTAssertEqual(system.state.phase, .fighting)
    }

    func testTheBreatherEndsOnceEveryoneAsksToGoOn() {
        var system = partySystem()
        var combat = makeCombat()
        run(&system, &combat, seconds: 20)
        XCTAssertEqual(system.state.restVoters, 2)

        system.voteToProceed(hero: 0)
        XCTAssertEqual(system.state.restVotes, 1)
        run(&system, &combat, seconds: 1)
        XCTAssertEqual(system.state.phase, .resting, "one player cannot skip it alone")

        system.voteToProceed(hero: 1)
        run(&system, &combat, seconds: 0.5)
        XCTAssertEqual(system.state.phase, .fighting)
        XCTAssertEqual(system.state.index, 3)
        XCTAssertEqual(system.state.restVotes, 0, "votes do not carry into the next breather")
    }

    private func addGoblins(_ combat: inout CombatState, count: Int) {
        for offset in 0..<count {
            let kind = combat.enemies.kindIndex(for: EnemyCatalog.goblin)
            combat.enemies.append(id: combat.makeEntityID(), kind: kind, position: CGPoint(x: Double(offset), y: 0),
                                  speedScale: 1)
        }
    }

    func testTheBreatherWaitsForTheLastEnemyOfTheWave() {
        var system = partySystem()
        var combat = makeCombat()
        run(&system, &combat, seconds: 10)
        addGoblins(&combat, count: 3)
        run(&system, &combat, seconds: 10)
        XCTAssertEqual(system.state.phase, .clearing, "the wave is over but three enemies remain")
        XCTAssertEqual(system.spawnShare, 0, "nothing new arrives while they are finished off")

        // The countdown has not started, however long it takes.
        run(&system, &combat, seconds: 30)
        XCTAssertEqual(system.state.phase, .clearing)
        XCTAssertEqual(system.state.index, 2)

        combat.enemies.removeAll()
        run(&system, &combat, seconds: 0.5)
        XCTAssertEqual(system.state.phase, .resting)
        XCTAssertEqual(system.state.restRemaining, 30, accuracy: 0.6, "the full breather starts once they are down")
    }

    func testAStragglerCannotHoldTheBreatherOffForever() {
        var system = partySystem()
        var combat = makeCombat()
        run(&system, &combat, seconds: 10)
        addGoblins(&combat, count: 1)
        run(&system, &combat, seconds: 10)
        XCTAssertEqual(system.state.phase, .clearing)
        run(&system, &combat, seconds: system.clearLimit + 1)
        XCTAssertEqual(system.state.phase, .resting)
        XCTAssertEqual(combat.enemies.count, 0, "the straggler was let go so the breather is a full one")
        XCTAssertGreaterThan(system.state.restRemaining, 28)
    }

    func testAPlayerWhoLeavesNoLongerHoldsTheVote() {
        var system = partySystem()
        var combat = makeCombat()
        run(&system, &combat, seconds: 20)
        system.voteToProceed(hero: 0)
        system.setElectorate([0])
        run(&system, &combat, seconds: 0.5)
        XCTAssertEqual(system.state.phase, .fighting, "the only remaining player had voted")
    }

    func testOnlyAPartyMemberInTheBreatherMayVote() {
        var system = partySystem()
        var combat = makeCombat()
        system.voteToProceed(hero: 0)
        XCTAssertEqual(system.state.restVotes, 0, "there is no breather yet")
        run(&system, &combat, seconds: 20)
        system.voteToProceed(hero: 7)
        XCTAssertEqual(system.state.restVotes, 0, "a stranger's vote counts for nothing")
    }

    func testASoloRunNeverRests() {
        var system = WaveSystem(plan: plan(bossEvery: 100), conquestWave: nil)
        var combat = makeCombat()
        run(&system, &combat, seconds: 60)
        XCTAssertNotEqual(system.state.phase, .resting)
        XCTAssertEqual(system.state.index, 7)
    }

    func testAnEvenBossWaveRestsAfterTheChampionFalls() {
        var system = partySystem(bossEvery: 2)
        var combat = makeCombat()
        run(&system, &combat, seconds: 12)
        let id = addBoss(&combat)
        system.bossArrived(id: id, title: "Grask", health: 1_000, &combat)
        combat.enemies.health[0] = 0
        _ = system.step(&combat, dt: 0.5)
        XCTAssertEqual(system.state.phase, .clearing, "its body is still on the field")
        combat.enemies.removeAll()
        _ = system.step(&combat, dt: 0.5)
        XCTAssertEqual(system.state.phase, .resting)
        XCTAssertEqual(system.state.index, 2)

        run(&system, &combat, seconds: 31)
        XCTAssertEqual(system.state.phase, .fighting)
        XCTAssertEqual(system.state.index, 2, "the wave carries on where it was")

        run(&system, &combat, seconds: 10)
        XCTAssertEqual(system.state.index, 3, "and does not rest a second time before moving on")
        XCTAssertEqual(system.state.phase, .fighting)
    }

    func testARealmWithNoChampionsNeverAsksForOne() {
        var system = WaveSystem(plan: WavePlan(waveSeconds: 5, bosses: []), conquestWave: nil)
        var combat = makeCombat()
        XCTAssertNil(run(&system, &combat, seconds: 60))
        XCTAssertEqual(system.state.phase, .fighting)
    }
}

private extension WavePlan {
    /// `bossEvery` is a `var`, but a test reads better building the plan in
    /// one expression.
    func with(bossEvery: Int) -> WavePlan {
        var copy = self
        copy.bossEvery = bossEvery
        return copy
    }
}
