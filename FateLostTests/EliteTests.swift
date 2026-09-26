import XCTest
@testable import FateLost

/// The rare elites: a shieldbreaker's barrier and hook, an explosive's bombs
/// and its own death, and that neither realm-gating nor spawning lets two of
/// them crowd a fight at once.
final class EliteTests: XCTestCase {
    private let dt: TimeInterval = 1.0 / 60

    private func solo(seed: UInt64 = 7) -> GameSimulation {
        let run = RunConfiguration(realmID: .frozenWastes, starterWeaponID: StarterWeapons.sword.id, seed: seed)
        var sim = GameSimulation(run: run, tuning: .standard)
        sim.cheats = SimulationCheats(godMode: false, spawningEnabled: false)
        return sim
    }

    private func place(_ sim: inout GameSimulation, at point: CGPoint) {
        sim.player.position = point
        sim.combat.playerPosition = point
    }

    @discardableResult
    private func addElite(_ sim: inout GameSimulation, definition: EnemyDefinition,
                          at point: CGPoint) -> Int {
        let kind = sim.combat.enemies.kindIndex(for: definition)
        let id = sim.combat.makeEntityID()
        sim.combat.enemies.append(id: id, kind: kind, position: point, speedScale: 1)
        return sim.combat.enemies.count - 1
    }

    private func run(_ sim: inout GameSimulation, seconds: Double) {
        for _ in 0..<Int((seconds * 60).rounded()) { sim.step(dt: dt) }
    }

    // MARK: The barrier

    func testABarrierAbsorbsDamageBeforeHealthAndBreakingTurnsItBerserker() {
        var sim = solo()
        let index = addElite(&sim, definition: EnemyCatalog.shieldbreaker, at: CGPoint(x: 40, y: 40))
        let maxBarrier = sim.combat.enemies.maxHealth[index] * 0.4
        XCTAssertEqual(sim.combat.enemies.barrier[index], maxBarrier, accuracy: 0.01)
        let healthBefore = sim.combat.enemies.health[index]
        let speedBefore = sim.combat.enemies.speedScale[index]

        sim.combat.strike(index, with: Hit(amount: maxBarrier * 0.5, type: .physical, tags: [], canCrit: false))
        XCTAssertEqual(sim.combat.enemies.health[index], healthBefore, "the barrier alone paid for it")
        XCTAssertLessThan(sim.combat.enemies.barrier[index], maxBarrier)

        sim.combat.strike(index, with: Hit(amount: maxBarrier, type: .physical, tags: [], canCrit: false))
        XCTAssertLessThanOrEqual(sim.combat.enemies.barrier[index], 0)
        XCTAssertLessThan(sim.combat.enemies.health[index], healthBefore, "the rest came off its health")

        EliteSystem.step(&sim.combat, targets: [], dt: dt)
        XCTAssertGreaterThan(sim.combat.enemies.speedScale[index], speedBefore, "berserker is faster")
        XCTAssertTrue(sim.combat.events.contains { if case .shieldBroke = $0 { return true } else { return false } })
    }

    func testAShieldedShieldbreakerNeverHooksButABrokenOneDoes() {
        var sim = solo()
        let index = addElite(&sim, definition: EnemyCatalog.shieldbreaker, at: CGPoint(x: 40, y: 40))
        place(&sim, at: CGPoint(x: 42, y: 40))
        let target = AITarget(position: sim.player.position, isAlive: true, isHidden: false, hero: 0)

        for _ in 0..<Int(20 / dt) {
            EliteSystem.step(&sim.combat, targets: [target], dt: dt)
        }
        XCTAssertTrue(sim.combat.hostileProjectiles.isEmpty, "shielded, it never hooks")

        sim.combat.enemies.barrier[index] = 0
        var fired = false
        for _ in 0..<Int(20 / dt) {
            EliteSystem.step(&sim.combat, targets: [target], dt: dt)
            if sim.combat.hostileProjectiles.contains(where: { $0.isGrapple }) {
                fired = true
                break
            }
        }
        XCTAssertTrue(fired, "berserker, in range, it hooks")
    }

    // MARK: The hook

    func testAConnectingHookPullsAndStunsAndAMissDoesNothing() {
        var sim = solo()
        place(&sim, at: CGPoint(x: 40, y: 40))
        let origin = CGPoint(x: 44, y: 40)
        sim.combat.incidents.append(.grappleHero(hero: 0, origin: origin, pullSeconds: 0.3, stunSeconds: 2))
        sim.carryOutIncidents()
        XCTAssertTrue(sim.player.isStunned)
        XCTAssertNotNil(sim.player.pullTarget)

        run(&sim, seconds: 0.5)
        XCTAssertLessThan(sim.world.distance(sim.player.position, origin), 0.5, "dragged in")
        XCTAssertTrue(sim.player.isStunned, "still held")
        run(&sim, seconds: 2)
        XCTAssertFalse(sim.player.isStunned, "and then let go")
    }

    func testAMissedHookLeavesTheHeroUntouched() {
        var sim = solo()
        place(&sim, at: CGPoint(x: 40, y: 40))
        sim.combat.hostileProjectiles.append(Projectile(
            id: sim.combat.makeEntityID(), position: CGPoint(x: 30, y: 30), velocity: CGPoint(x: 1, y: 0) * 5,
            remainingLife: 0.4, pierceRemaining: 0,
            hit: Hit(amount: 0, type: .physical, tags: [.projectile]), radius: 0.3, splashRadius: 0,
            spriteID: .projectileHook, visual: .physical, isHostile: true, isGrapple: true, pullSeconds: 0.3,
            stunSeconds: 2))
        run(&sim, seconds: 1)
        XCTAssertFalse(sim.player.isStunned)
        XCTAssertTrue(sim.combat.hostileProjectiles.isEmpty, "it fizzled out")
    }

    // MARK: The bombs

    func testABombTelegraphsThenBurnsWhoeverItCatchesAndMissesWhoeverLeaves() {
        var sim = solo()
        let point = CGPoint(x: 40, y: 40)
        var bomb = Hazard(id: sim.combat.makeEntityID(), shape: .circle, position: point, direction: .zero,
                          size: 1.8, width: 0, warning: 1, damage: 26, type: .fire, visual: .fire)
        bomb.burnTickDamage = 5
        bomb.burnTicks = 5
        bomb.burnTickEvery = 1
        sim.combat.hazards.append(bomb)
        place(&sim, at: point)
        let before = sim.player.health
        run(&sim, seconds: 0.8)
        XCTAssertEqual(sim.player.health, before, accuracy: 0.001, "nothing during the warning")

        run(&sim, seconds: 0.4)
        XCTAssertLessThan(sim.player.health, before, "the blast lands")
        XCTAssertTrue(sim.player.isBurning, "and it caught fire")

        run(&sim, seconds: 5)
        XCTAssertFalse(sim.player.isBurning, "the fire burns out cleanly")
    }

    func testLeavingBeforeItLandsTakesNoDamageAndNoBurn() {
        var sim = solo()
        var bomb = Hazard(id: sim.combat.makeEntityID(), shape: .circle, position: CGPoint(x: 40, y: 40),
                          direction: .zero, size: 1.8, width: 0, warning: 1, damage: 26, type: .fire, visual: .fire)
        bomb.burnTickDamage = 5
        bomb.burnTicks = 5
        bomb.burnTickEvery = 1
        sim.combat.hazards.append(bomb)
        place(&sim, at: CGPoint(x: 60, y: 60))
        let before = sim.player.health
        run(&sim, seconds: 1.5)
        XCTAssertEqual(sim.player.health, before, accuracy: 0.001)
        XCTAssertFalse(sim.player.isBurning)
    }

    func testSeveralBurnsStackButNeverAddUpToAnUnavoidableKill() {
        var player = PlayerState(position: .zero, maxHealth: 100)
        for _ in 0..<6 {
            player.addBurn(tickDamage: 5, ticks: 5, tickEvery: 1)
        }
        XCTAssertLessThanOrEqual(player.burns.count, PlayerState.maxBurnStacks)
        let worstCaseTotal = player.burns.reduce(0.0) { $0 + $1.tickDamage * Double($1.ticksRemaining) }
        XCTAssertLessThan(worstCaseTotal, player.maxHealth, "the cap keeps it survivable on its own")
    }

    func testAnExplosiveElitesDeathDetonatesAfterAFuse() {
        var sim = solo()
        let index = addElite(&sim, definition: EnemyCatalog.explosiveElite, at: CGPoint(x: 40, y: 40))
        sim.combat.enemies.health[index] = 0
        sim.combat.removeDefeatedEnemies()
        guard let last = sim.combat.hazards.last else { return XCTFail("no blast was left behind") }
        XCTAssertEqual(last.warning, 1.2, accuracy: 0.001, "a brief fuse, same as a thrown bomb's telegraph")
        XCTAssertEqual(last.damage, 30, accuracy: 0.001)
        XCTAssertGreaterThan(last.burnTicks, 0, "burns like its bombs, not just a blast")
        XCTAssertGreaterThan(last.burnTickDamage, 0)
    }

    // MARK: Where they walk, and never crowding

    func testRareElitesRespectTheirRealmsAndNoRealmStacksThem() {
        XCTAssertFalse(EnemyCatalog.roster(for: .ashenWilds).contains { $0.id == EnemyCatalog.shieldbreaker.id })
        XCTAssertFalse(EnemyCatalog.roster(for: .drownedFen).contains { $0.id == EnemyCatalog.shieldbreaker.id })
        XCTAssertTrue(EnemyCatalog.roster(for: .hollowForest).contains { $0.id == EnemyCatalog.shieldbreaker.id })
        XCTAssertTrue(EnemyCatalog.roster(for: .frozenWastes).contains { $0.id == EnemyCatalog.shieldbreaker.id })

        XCTAssertFalse(EnemyCatalog.roster(for: .hollowForest).contains { $0.id == EnemyCatalog.explosiveElite.id })
        XCTAssertTrue(EnemyCatalog.roster(for: .frozenWastes).contains { $0.id == EnemyCatalog.explosiveElite.id })
        XCTAssertTrue(EnemyCatalog.roster(for: .fallenCitadel).contains { $0.id == EnemyCatalog.explosiveElite.id })
    }

    func testNoSecondRareEliteSpawnsWhileOneWalksTheField() {
        var sim = solo()
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: true)
        addElite(&sim, definition: EnemyCatalog.shieldbreaker, at: CGPoint(x: 30, y: 30))
        place(&sim, at: CGPoint(x: 40, y: 40))
        run(&sim, seconds: 30)
        let eliteCount = (0..<sim.combat.enemies.count)
            .filter { sim.combat.enemies.definition(at: $0).eliteKit != nil }.count
        XCTAssertLessThanOrEqual(eliteCount, 1, "the cap held even with plenty of time to roll another")
    }

    // MARK: Across the wire

    func testABarrierAndAHerosFireAndStunReachTheWire() {
        var sim = solo()
        let index = addElite(&sim, definition: EnemyCatalog.shieldbreaker, at: CGPoint(x: 40, y: 40))
        place(&sim, at: CGPoint(x: 40, y: 40))
        sim.combat.enemies.barrier[index] = sim.combat.enemies.maxHealth[index] * 0.4 * 0.5
        sim.player.addBurn(tickDamage: 5, ticks: 3, tickEvery: 1)
        sim.player.stunSecondsRemaining = 1.5

        let snapshot = sim.snapshot(forViewer: 0, radius: 60)
        guard let netEnemy = snapshot.enemies.first(where: { $0.id == UInt32(sim.combat.enemies.ids[index]) }) else {
            return XCTFail("the shieldbreaker never made the snapshot")
        }
        XCTAssertEqual(netEnemy.barrierFraction, 0.5, accuracy: 0.02)
        let hero = snapshot.heroes.first { $0.slot == 0 }
        XCTAssertEqual(hero?.isBurning, true)
        XCTAssertEqual(hero?.isStunned, true)

        guard let decoded = NetSnapshot.decode(snapshot.encoded()) else { return XCTFail("did not decode") }
        let decodedEnemy = decoded.enemies.first { $0.id == netEnemy.id }
        XCTAssertEqual(decodedEnemy?.barrierFraction ?? -1, 0.5, accuracy: 0.02)
        let decodedHero = decoded.heroes.first { $0.slot == 0 }
        XCTAssertEqual(decodedHero?.isBurning, true)
        XCTAssertEqual(decodedHero?.isStunned, true)
    }
}
