import XCTest
@testable import FateLost

/// The night hunters that arrive in the Frozen Wastes: a bat whose bite stops
/// regeneration from making a hero unkillable, and a stalker that hamstrings.
final class EnemyTraitsTests: XCTestCase {
    private let dt: TimeInterval = 1.0 / 60

    private func solo() -> GameSimulation {
        var sim = GameSimulation(run: RunConfiguration(realmID: .frozenWastes, starterWeaponID: StarterWeapons.sword.id,
                                                       seed: 4), tuning: .standard)
        sim.cheats = SimulationCheats(godMode: false, spawningEnabled: false)
        return sim
    }

    private func run(_ sim: inout GameSimulation, seconds: Double) {
        for _ in 0..<Int((seconds * 60).rounded()) { sim.step(dt: dt) }
    }

    // MARK: Who they are and where they come from

    func testTheyComeInFromTheFourthRealmAndNotBefore() {
        for realm in RealmCatalog.all {
            let roster = Set(EnemyCatalog.roster(for: realm.id).map(\.id))
            for hunter in EnemyCatalog.nightHunters {
                if realm.order < 4 {
                    XCTAssertFalse(roster.contains(hunter.id), "\(hunter.name) turns up in \(realm.name)")
                } else {
                    XCTAssertTrue(roster.contains(hunter.id), "\(hunter.name) is missing from \(realm.name)")
                }
            }
        }
    }

    func testTheBatIsFastFragileAndDartsAndTheStalkerLungesFromTheShadows() {
        let bat = EnemyCatalog.vampireBat
        XCTAssertTrue(bat.flutters)
        XCTAssertLessThan(bat.maxHealth, 25)
        XCTAssertGreaterThan(bat.moveSpeed, EnemyCatalog.goblin.moveSpeed)
        XCTAssertEqual(bat.onHit, .witherRegen(seconds: 6))

        let stalker = EnemyCatalog.duskStalker
        XCTAssertTrue(stalker.isShrouded)
        guard case .charger(let range, _, let distance) = stalker.behavior else { return XCTFail("a stalker lunges") }
        XCTAssertLessThanOrEqual(range, 6, "a short lunge, not a charge across the field")
        XCTAssertLessThanOrEqual(distance, 6)
        XCTAssertGreaterThanOrEqual(stalker.attackWindup, 0.4, "it has to show itself before it strikes")
        XCTAssertEqual(stalker.onHit, .hamstring(seconds: 4, slow: 0.3))
    }

    // MARK: What they do

    func testTheBitesModifiersTakeNinetyPercentOfRegeneration() {
        var sheet = StatSheet()
        sheet.reset()
        sheet.add(StatModifier(.healthRegen, .flat, 10))
        sheet.add(EnemyOnHit.witherRegen(seconds: 6).modifiers)
        sheet.finalize()
        XCTAssertEqual(sheet[.healthRegen], 1, accuracy: 0.0001)

        var slowed = StatSheet()
        slowed.reset()
        slowed.add(EnemyOnHit.hamstring(seconds: 4, slow: 0.3).modifiers)
        slowed.finalize()
        XCTAssertEqual(slowed[.moveSpeed], 0.7, accuracy: 0.0001)
    }

    func testAHeroWhoRegeneratesHealsAtATenthOfTheRateWhileWithered() {
        var sim = solo()
        sim.legacy.append(StatModifier(.healthRegen, .flat, 3))
        sim.refreshStats(force: true)
        sim.player.health = 20
        run(&sim, seconds: 1)
        let healthy = sim.player.health - 20
        XCTAssertGreaterThan(healthy, 2, "the test hero should be regenerating about 3 a second")

        sim.player.health = 20
        sim.player.applyBuff(id: EnemyOnHit.witherRegen(seconds: 6).buffID,
                             modifiers: EnemyOnHit.witherRegen(seconds: 6).modifiers, duration: 6, maxStacks: 1)
        run(&sim, seconds: 1)
        let withered = sim.player.health - 20
        XCTAssertLessThan(withered, healthy * 0.2, "regeneration should be nearly gone")
        run(&sim, seconds: 6)
        sim.player.health = 20
        run(&sim, seconds: 1)
        XCTAssertGreaterThan(sim.player.health - 20, 2, "and come back when it fades")
    }

    func testABlowThatLandsLeavesItsMarkAndOneThatMissesDoesNot() {
        var sim = solo()
        let effect = EnemyOnHit.hamstring(seconds: 4, slow: 0.3)
        sim.combat.incidents.append(.stingHero(hero: 0, amount: 5, direction: CGPoint(x: 1, y: 0), effect: effect))
        run(&sim, seconds: 0.2)
        XCTAssertTrue(sim.player.buffs.contains { $0.id == effect.buffID }, "the hero was cut and not slowed")
        XCTAssertEqual(sim.combat.sheet[.moveSpeed], 0.7, accuracy: 0.01)

        var shielded = solo()
        shielded.player.invulnerability = 5
        shielded.combat.incidents.append(.stingHero(hero: 0, amount: 5, direction: CGPoint(x: 1, y: 0), effect: effect))
        run(&shielded, seconds: 0.2)
        XCTAssertFalse(shielded.player.buffs.contains { $0.id == effect.buffID }, "a blow that did not land left a mark")
    }

    func testAnAfflictionIsRecognisedFromItsBuff() {
        XCTAssertNotNil(EnemyOnHit.forBuff("affliction.wither"))
        XCTAssertNotNil(EnemyOnHit.forBuff("affliction.hamstring"))
        XCTAssertNil(EnemyOnHit.forBuff("relic.something"))
        for effect in [EnemyOnHit.witherRegen(seconds: 6), .hamstring(seconds: 4, slow: 0.3)] {
            XCTAssertFalse(effect.blurb.isEmpty)
            XCTAssertFalse(effect.name.isEmpty)
        }
    }

    func testABatDartsFromSideToSideOnTheWayIn() {
        var sim = solo()
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        let home = sim.arena.playerSpawn
        sim.player.position = home
        sim.combat.playerPosition = home
        let kind = sim.combat.enemies.kindIndex(for: EnemyCatalog.vampireBat)
        let start = sim.world.wrap(home + CGPoint(x: 9, y: 0))
        sim.combat.enemies.append(id: sim.combat.makeEntityID(), kind: kind, position: start, speedScale: 1)
        var widest: CGFloat = 0
        for _ in 0..<Int(2.2 / dt) {
            sim.step(dt: dt)
            guard sim.combat.enemies.count > 0 else { break }
            let offset = sim.world.delta(from: home, to: sim.combat.enemies.positions[0])
            widest = max(widest, abs(offset.y))
        }
        XCTAssertGreaterThan(widest, 0.2, "it came straight in like anything else")
    }

    func testAStalkerThatLungesHamstringsTheHeroItHits() {
        var sim = solo()
        let home = sim.arena.playerSpawn
        sim.player.position = home
        sim.combat.playerPosition = home
        let kind = sim.combat.enemies.kindIndex(for: EnemyCatalog.duskStalker)
        sim.combat.enemies.append(id: sim.combat.makeEntityID(), kind: kind,
                                  position: sim.world.wrap(home + CGPoint(x: 3.5, y: 0)), speedScale: 1)
        // The hero's own sword must not kill it before it has lunged.
        sim.combat.enemies.health[0] = 1_000_000
        sim.combat.enemies.maxHealth[0] = 1_000_000
        var cut = false
        for _ in 0..<Int(4 / dt) {
            sim.step(dt: dt)
            if sim.player.buffs.contains(where: { $0.id == EnemyOnHit.hamstring(seconds: 4, slow: 0.3).buffID }) {
                cut = true
                break
            }
        }
        XCTAssertTrue(cut, "the stalker never landed its lunge")
    }
}
