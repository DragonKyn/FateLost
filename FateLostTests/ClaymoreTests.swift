import CoreGraphics
import XCTest
@testable import FateLost

/// The claymore has to be a whole weapon: on the rack, buyable, masterable,
/// saved, sent to a party, and swinging in a solo run and a co-op one.
final class ClaymoreTests: XCTestCase {
    private let claymore = StarterWeapons.claymore
    private let dt: TimeInterval = 1.0 / 60

    private static let dummy = EnemyDefinition(
        id: "test.claymore.dummy", name: "Dummy", family: .goblinoid, maxHealth: 1_000_000, moveSpeed: 0, radius: 0.3,
        attackDamage: 0, attackReach: 0, attackWindup: 1, attackCooldown: 1000, knockbackResistance: 1,
        damageType: .physical, behavior: .melee, experience: 0, spawnWeight: 0, earliestWave: 1,
        spriteVariants: [.enemyGoblin]
    )

    // MARK: Balance

    func testItIsOnTheRackAndFollowsTheBalancePatterns() {
        XCTAssertNotNil(StarterWeapons.definition(for: claymore.id))
        XCTAssertTrue(StarterWeapons.all.contains { $0.id == claymore.id })
        XCTAssertTrue(claymore.tags.contains(.twoHanded))
        XCTAssertFalse(StarterWeapons.defaultUnlocked.contains(claymore.id), "it is bought, not given")

        let others = StarterWeapons.all.filter { $0.id != claymore.id }
        let melee = others.filter { if case .meleeArc = $0.delivery { return true } else { return false } }
        // Reach, arc and blow: more than any other blade; slower than all but the hammer.
        XCTAssertGreaterThan(claymore.range, melee.map(\.range).max() ?? 0)
        XCTAssertGreaterThan(claymore.baseDamage, melee.filter { $0.id != StarterWeapons.warHammer.id }.map(\.baseDamage).max() ?? 0)
        if case .meleeArc(let arc) = claymore.delivery {
            let wider = melee.compactMap { weapon -> Double? in
                if case .meleeArc(let degrees) = weapon.delivery, degrees < 200 { return degrees }
                return nil
            }.max() ?? 0
            XCTAssertGreaterThan(arc, wider, "a wider sweep than any of the ordinary blades")
        } else {
            XCTFail("the claymore is a melee weapon")
        }
        XCTAssertLessThan(claymore.attackSpeed, StarterWeapons.katana.attackSpeed)
        XCTAssertLessThan(claymore.attackSpeed, StarterWeapons.sword.attackSpeed)
        // Not an outlier on damage per second.
        let free = StarterWeapons.all.filter { StarterWeapons.defaultUnlocked.contains($0.id) }
        XCTAssertLessThanOrEqual(claymore.damagePerSecond, (free.map(\.damagePerSecond).max() ?? 0) * 1.15)
        XCTAssertGreaterThanOrEqual(claymore.damagePerSecond, StarterWeapons.warHammer.damagePerSecond * 0.9)
    }

    func testItHasItsOwnLargeArt() throws {
        let sprite = try XCTUnwrap(PlaceholderArt.sprite(for: .weaponClaymore))
        XCTAssertEqual(claymore.spriteID, .weaponClaymore)
        for other in StarterWeapons.all where other.id != claymore.id {
            if case .meleeArc = other.delivery, let art = PlaceholderArt.sprite(for: other.spriteID) {
                XCTAssertGreaterThan(sprite.image.size.height, art.image.size.height, "not larger than \(other.name)")
            }
        }
        XCTAssertGreaterThan(sprite.image.size.width, 16)
        XCTAssertLessThanOrEqual(sprite.image.size.height, 80, "it should still fit in a hand")
    }

    // MARK: The Armoury

    func testItCanBeBoughtMasteredAndIsRememberedInTheSave() throws {
        var profile = LegacyProfile()
        XCTAssertFalse(profile.isUnlocked(claymore))
        XCTAssertNotNil(profile.masteryDenial(for: claymore))
        profile.echoes = WeaponMastery.totalCost(claymore)
        XCTAssertTrue(profile.buy(weapon: claymore))
        XCTAssertTrue(profile.isUnlocked(claymore))
        for _ in 1...WeaponMastery.maxRank { XCTAssertTrue(profile.master(weapon: claymore)) }
        XCTAssertEqual(profile.echoes, 0)
        XCTAssertEqual(profile.rank(of: claymore), WeaponMastery.maxRank)
        XCTAssertFalse(WeaponMastery.modifiers(for: claymore, rank: 3).isEmpty)
        XCTAssertFalse(WeaponMastery.rankText(for: claymore).contains("+0 "))

        let saved = try JSONEncoder().encode(profile)
        let loaded = try JSONDecoder().decode(LegacyProfile.self, from: saved)
        XCTAssertTrue(loaded.isUnlocked(claymore))
        XCTAssertEqual(loaded.rank(of: claymore), WeaponMastery.maxRank)
    }

    func testAnOlderSaveWithoutItStillLoadsAndDoesNotOwnIt() throws {
        var old = LegacyProfile()
        old.echoes = 500
        old.weapons.insert(StarterWeapons.katana.id)
        let loaded = try JSONDecoder().decode(LegacyProfile.self, from: JSONEncoder().encode(old))
        XCTAssertTrue(loaded.isUnlocked(StarterWeapons.katana))
        XCTAssertFalse(loaded.isUnlocked(claymore))
    }

    // MARK: Multiplayer

    func testItTravelsToAPartyAndComesBackAsTheSameWeapon() throws {
        var profile = LegacyProfile()
        profile.echoes = WeaponMastery.totalCost(claymore)
        profile.buy(weapon: claymore)
        for _ in 1...3 { profile.master(weapon: claymore) }

        let loadout = PartyLoadout.make(weapon: claymore, hero: .standard, profile: profile)
        XCTAssertEqual(loadout.weapon, "starter.claymore")
        XCTAssertTrue(loadout.legacy.contains("mastery.starter.claymore.3"))

        let wire = try JSONEncoder().encode(loadout)
        let back = try JSONDecoder().decode(PartyLoadout.self, from: wire)
        XCTAssertEqual(back.weapon, claymore.id)

        let modifiers = PartyLegacy.modifiers(from: back.legacy, weapon: claymore)
        XCTAssertTrue(modifiers.contains { $0.stat == .meleeDamage && abs($0.value - 0.09) < 0.0001 },
                      "the host must rebuild this player's mastery from the ids")
        XCTAssertEqual(StarterWeapons.definition(for: back.weapon)?.id, claymore.id)
    }

    // MARK: Play

    private func addDummy(_ sim: inout GameSimulation, near position: CGPoint, offset: CGPoint) -> Int {
        let kind = sim.combat.enemies.kindIndex(for: Self.dummy)
        sim.combat.enemies.append(id: sim.combat.makeEntityID(), kind: kind,
                                  position: sim.world.wrap(position + offset), speedScale: 1)
        return sim.combat.enemies.count - 1
    }

    func testItSwingsAndHitsInASoloRun() {
        var sim = GameSimulation(run: RunConfiguration(realmID: .ashenWilds, starterWeaponID: claymore.id, seed: 3),
                                 tuning: .standard)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        XCTAssertEqual(sim.weapon.id, claymore.id)
        // One enemy at the very end of its reach, one behind the hero.
        let far = addDummy(&sim, near: sim.player.position, offset: CGPoint(x: 2.5, y: 0))
        let behind = addDummy(&sim, near: sim.player.position, offset: CGPoint(x: -2.6, y: 0))
        var swings = 0
        var reach: CGFloat = 0
        for _ in 0..<(60 * 5) {
            sim.step(dt: dt)
            for event in sim.drainEvents() {
                if case .meleeSwing(_, _, let range, _) = event {
                    swings += 1
                    reach = range
                }
            }
        }
        XCTAssertGreaterThanOrEqual(swings, 2)
        XCTAssertLessThanOrEqual(swings, 4, "it is slow: about 0.6 swings a second at most")
        XCTAssertGreaterThanOrEqual(reach, 2.3, "the swing reaches farther than the hammer")
        XCTAssertLessThan(sim.combat.enemies.health[far], sim.combat.enemies.maxHealth[far], "reach did not land")
        XCTAssertEqual(sim.combat.enemies.health[behind], sim.combat.enemies.maxHealth[behind],
                       "a 170 degree swing must not hit what is directly behind the hero")
    }

    func testEveryHeroInAPartyCanSwingIt() {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: claymore.id, seed: 4)
        let party = (0..<3).map { index in
            PartyHeroConfig(id: "p\(index)", name: "Hero\(index)", slot: index, weaponID: claymore.id)
        }
        var sim = GameSimulation(run: run, tuning: .standard, party: party)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        let home = sim.arena.playerSpawn
        var targets: [Int] = []
        for hero in 0..<3 {
            let at = sim.world.wrap(home + CGPoint(x: Double(hero) * 30, y: 0))
            sim.perform(as: hero) { simulation in
                simulation.player.position = at
                simulation.combat.playerPosition = at
            }
            targets.append(addDummy(&sim, near: at, offset: CGPoint(x: 1.5, y: 0)))
        }
        var swingsByHero = [Int: Int]()
        for _ in 0..<(60 * 4) {
            sim.step(dt: dt)
            for (hero, event) in sim.drainPartyEvents() {
                if case .meleeSwing = event { swingsByHero[hero, default: 0] += 1 }
            }
        }
        for hero in 0..<3 {
            XCTAssertGreaterThanOrEqual(swingsByHero[hero] ?? 0, 2, "hero \(hero) never swung")
            XCTAssertLessThan(sim.combat.enemies.health[targets[hero]], sim.combat.enemies.maxHealth[targets[hero]])
        }
    }
}
