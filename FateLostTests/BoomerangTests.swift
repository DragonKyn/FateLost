import CoreGraphics
import XCTest
@testable import FateLost

/// The boomerang has to be thrown, hit what it passes, come back, be caught,
/// and be thrown again, for a lone hero and for every hero in a party.
final class BoomerangTests: XCTestCase {
    private static let dummy = EnemyDefinition(
        id: "test.boomerang.dummy", name: "Dummy", family: .goblinoid, maxHealth: 1_000_000, moveSpeed: 0, radius: 0.3,
        attackDamage: 0, attackReach: 0, attackWindup: 1, attackCooldown: 1000, knockbackResistance: 1,
        damageType: .physical, behavior: .melee, experience: 0, spawnWeight: 0, earliestWave: 1,
        spriteVariants: [.enemyGoblin]
    )
    private let dt: TimeInterval = 1.0 / 60

    private func solo(weapon: WeaponDefinition = StarterWeapons.boomerang) -> GameSimulation {
        var sim = GameSimulation(run: RunConfiguration(realmID: .ashenWilds, starterWeaponID: weapon.id, seed: 5),
                                 tuning: .standard)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        return sim
    }

    @discardableResult
    private func addDummy(_ sim: inout GameSimulation, offset: CGPoint) -> Int {
        let kind = sim.combat.enemies.kindIndex(for: Self.dummy)
        let id = sim.combat.makeEntityID()
        sim.combat.enemies.append(id: id, kind: kind,
                                  position: sim.world.wrap(sim.player.position + offset), speedScale: 1)
        return sim.combat.enemies.count - 1
    }

    private func fired(_ events: [CombatEvent]) -> Int {
        events.filter { if case .projectileFired = $0 { return true } else { return false } }.count
    }

    private func hits(_ events: [CombatEvent]) -> Int {
        events.filter { if case .enemyHit = $0 { return true } else { return false } }.count
    }

    // MARK: Solo

    func testTheBoomerangIsThrownAtAnEnemyInRange() {
        var sim = solo()
        addDummy(&sim, offset: CGPoint(x: 4, y: 0))
        var thrown = 0
        for _ in 0..<10 {
            sim.step(dt: dt)
            thrown += fired(sim.drainEvents())
        }
        XCTAssertEqual(thrown, 1, "one throw, not none and not several")
        XCTAssertEqual(sim.combat.projectiles.count, 1)
        XCTAssertEqual(sim.combat.projectiles.first?.spriteID, .projectileBoomerang)
        XCTAssertEqual(sim.combat.projectiles.first?.returnsToThrower, true)
    }

    func testItReachesTheEnemyItWasThrownAtEvenAtFullRange() {
        for distance in [2.0, 4.0, 6.0] {
            var sim = solo()
            let enemy = addDummy(&sim, offset: CGPoint(x: distance, y: 0))
            let before = sim.combat.enemies.health[enemy]
            for _ in 0..<90 { sim.step(dt: dt) }
            XCTAssertLessThan(sim.combat.enemies.health[enemy], before, "the throw fell short of an enemy \(distance) tiles away")
        }
    }

    func testItComesBackIsCaughtAndIsThrownAgain() {
        var sim = solo()
        addDummy(&sim, offset: CGPoint(x: 4, y: 0))
        var throws = 0
        var sawReturning = false
        var sawCaught = false
        var inFlight = false
        for _ in 0..<(60 * 8) {
            sim.step(dt: dt)
            throws += fired(sim.drainEvents())
            if sim.combat.projectiles.contains(where: \.isReturning) { sawReturning = true }
            if inFlight, sim.combat.projectiles.isEmpty { sawCaught = true }
            inFlight = !sim.combat.projectiles.isEmpty
        }
        XCTAssertTrue(sawReturning, "it never turned for home")
        XCTAssertTrue(sawCaught, "it was never caught: it must not stay in the world or in the hand")
        XCTAssertGreaterThanOrEqual(throws, 5, "it stopped attacking after the first throw")
    }

    func testTheReturningBoomerangFollowsTheThrowerAsTheyRun() {
        var sim = solo()
        addDummy(&sim, offset: CGPoint(x: 4, y: 0))
        var caught = false
        var inFlight = false
        for frame in 0..<120 {
            // The hero runs across the throw's path.
            sim.step(dt: dt, intent: PlayerIntent(move: CGPoint(x: 0, y: frame < 60 ? 1 : -1)))
            _ = sim.drainEvents()
            if inFlight, sim.combat.projectiles.isEmpty { caught = true }
            inFlight = !sim.combat.projectiles.isEmpty
        }
        XCTAssertTrue(caught, "a boomerang that cannot find its thrower would fly off forever")
    }

    func testNoEnemyIsStruckTwiceOnTheSameLegOfTheTrip() {
        var sim = solo()
        addDummy(&sim, offset: CGPoint(x: 3, y: 0))
        var thrown = 0
        var landed = 0
        for _ in 0..<(60 * 7) {
            sim.step(dt: dt)
            let events = sim.drainEvents()
            thrown += fired(events)
            landed += hits(events)
        }
        XCTAssertGreaterThan(thrown, 3)
        // Out and back: at most two blows a throw (a throw may still be in flight).
        XCTAssertLessThanOrEqual(landed, thrown * 2, "a boomerang struck the same enemy over and over")
        XCTAssertGreaterThanOrEqual(landed, thrown - 1, "throws are not landing")
    }

    func testAFullLineOfEnemiesSendsItHomeAtOnceRatherThanLosingIt() {
        var sim = solo()
        for step in 0..<6 {
            addDummy(&sim, offset: CGPoint(x: 2 + Double(step) * 0.5, y: 0))
        }
        var turnedWhileAlive = false
        for _ in 0..<45 {
            sim.step(dt: dt)
            _ = sim.drainEvents()
            if sim.combat.projectiles.contains(where: { $0.isReturning && $0.remainingLife > 0 }) {
                turnedWhileAlive = true
            }
        }
        XCTAssertTrue(turnedWhileAlive, "spent its pierce going out and vanished instead of coming home")
    }

    func testTheThrownBoomerangSurvivesTheJourneyToAGuestsScreen() throws {
        var sim = solo()
        addDummy(&sim, offset: CGPoint(x: 4, y: 0))
        for _ in 0..<12 { sim.step(dt: dt) }
        XCTAssertFalse(sim.combat.projectiles.isEmpty)
        let snapshot = try XCTUnwrap(NetSnapshot.decode(sim.snapshot(forViewer: 0, radius: 26).encoded()))
        let shot = try XCTUnwrap(snapshot.projectiles.first)
        XCTAssertEqual(NetTables.sprite(shot.sprite), .projectileBoomerang)
        XCTAssertFalse(shot.isHostile)
    }

    func testOtherWeaponsAreUntouchedByTheBoomerangChanges() {
        var sim = solo(weapon: StarterWeapons.bow)
        addDummy(&sim, offset: CGPoint(x: 4, y: 0))
        for _ in 0..<60 { sim.step(dt: dt) }
        XCTAssertTrue(sim.combat.projectiles.allSatisfy { !$0.returnsToThrower && !$0.isReturning })
    }

    // MARK: Co-op

    func testEveryHeroInAPartyThrowsTheirOwnAndCatchesIt() {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.boomerang.id, seed: 9)
        let party = (0..<3).map { index in
            PartyHeroConfig(id: "p\(index)", name: "Hero\(index)", slot: index, weaponID: StarterWeapons.boomerang.id)
        }
        var sim = GameSimulation(run: run, tuning: .standard, party: party)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        let home = sim.arena.playerSpawn
        // Each hero on their own patch of ground with an enemy to throw at.
        let places: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 30), CGPoint(x: 30, y: 0)]
        for hero in 0..<3 {
            let at = sim.world.wrap(home + places[hero])
            sim.perform(as: hero) { simulation in
                simulation.player.position = at
                simulation.combat.playerPosition = at
            }
            let kind = sim.combat.enemies.kindIndex(for: Self.dummy)
            sim.combat.enemies.append(id: sim.combat.makeEntityID(), kind: kind,
                                      position: sim.world.wrap(at + CGPoint(x: 4, y: 0)), speedScale: 1)
        }
        var throwsByHero = [Int: Int]()
        var caughtByHero = [Int: Bool]()
        var flying = [Int: Bool]()
        for _ in 0..<(60 * 6) {
            sim.step(dt: dt)
            for (hero, event) in sim.drainPartyEvents() {
                if case .projectileFired = event { throwsByHero[hero, default: 0] += 1 }
            }
            for hero in 0..<3 {
                let count = sim.perform(as: hero) { $0.combat.projectiles.count }
                XCTAssertLessThanOrEqual(count, 1, "hero \(hero) has more than one boomerang out")
                if flying[hero] == true, count == 0 { caughtByHero[hero] = true }
                flying[hero] = count > 0
            }
        }
        for hero in 0..<3 {
            XCTAssertGreaterThanOrEqual(throwsByHero[hero] ?? 0, 4, "hero \(hero) stopped attacking")
            XCTAssertEqual(caughtByHero[hero], true, "hero \(hero)'s boomerang was never caught")
            let attacks = sim.perform(as: hero) { $0.combat.attackCount }
            XCTAssertEqual(throwsByHero[hero], attacks, "hero \(hero) threw a different number than they attacked: duplicates")
        }
    }
}
