import XCTest
@testable import FateLost

/// The rack has to stay a choice rather than a ladder: thirteen weapons that
/// feel different and land within reach of each other, mastery that is worth
/// having and never worth more than playing well, and a save file that
/// survives the Armoury being added to a game that did not have one.
final class ArmouryTests: XCTestCase {
    // MARK: The rack

    func testEveryStarterIsWholeAndUnique() {
        var ids: Set<WeaponID> = []
        var sprites: Set<SpriteID> = []
        for weapon in StarterWeapons.all {
            XCTAssertFalse(ids.contains(weapon.id), "two weapons share the id \(weapon.id)")
            ids.insert(weapon.id)
            XCTAssertFalse(sprites.contains(weapon.spriteID), "two weapons share the art \(weapon.spriteID)")
            sprites.insert(weapon.spriteID)
            XCTAssertFalse(weapon.name.isEmpty)
            XCTAssertFalse(weapon.summary.isEmpty)
            XCTAssertGreaterThan(weapon.baseDamage, 0)
            XCTAssertGreaterThan(weapon.attackSpeed, 0)
            XCTAssertGreaterThan(weapon.range, 0)
        }
    }

    func testNoStarterIsSimplyBetterThanTheFreeOnes() {
        let band = StarterWeapons.all.map(\.damagePerSecond)
        let free = StarterWeapons.all.filter { StarterWeapons.defaultUnlocked.contains($0.id) }
        let bestFree = free.map(\.damagePerSecond).max() ?? 0
        for weapon in StarterWeapons.all {
            XCTAssertLessThanOrEqual(weapon.damagePerSecond, bestFree * 1.15,
                                     "\(weapon.name) outclasses everything a new player has")
        }
        XCTAssertLessThanOrEqual((band.max() ?? 0) / (band.min() ?? 1), 1.7,
                                 "the rack has spread too far apart on damage per second")
    }

    func testTheRackCoversMeleeReachAndMagic() {
        let melee = StarterWeapons.all.filter { if case .meleeArc = $0.delivery { return true } else { return false } }
        let thrown = StarterWeapons.all.filter { if case .projectile = $0.delivery { return true } else { return false } }
        XCTAssertGreaterThanOrEqual(melee.count, 4)
        XCTAssertGreaterThanOrEqual(thrown.count, 4)
        let types = Set(StarterWeapons.all.map(\.damageType))
        XCTAssertTrue(types.isSuperset(of: [.physical, .fire, .cold, .lightning, .arcane]))
        XCTAssertTrue(StarterWeapons.all.contains { if case .projectile(let p) = $0.delivery { return p.returns }
                                                    else { return false } },
                      "nothing on the rack comes back")
    }

    // MARK: Mastery

    func testMasteryIsSmallAndStopsAtFive() {
        for weapon in StarterWeapons.all {
            XCTAssertTrue(WeaponMastery.modifiers(for: weapon, rank: 0).isEmpty)
            let full = WeaponMastery.modifiers(for: weapon, rank: WeaponMastery.maxRank)
            let beyond = WeaponMastery.modifiers(for: weapon, rank: WeaponMastery.maxRank + 4)
            XCTAssertEqual(full, beyond, "\(weapon.name) keeps paying out past mastery")
            for modifier in full {
                switch modifier.kind {
                case .increased, .more:
                    XCTAssertLessThanOrEqual(modifier.value, 0.45,
                                             "\(weapon.name) mastery grants \(modifier.value) of a multiplier")
                case .flat:
                    XCTAssertLessThanOrEqual(modifier.value, 2.5)
                }
            }
        }
    }

    func testMasteryGrowsOneRankAtATime() {
        let weapon = StarterWeapons.katana
        var last = 0.0
        for rank in 1...WeaponMastery.maxRank {
            let damage = WeaponMastery.modifiers(for: weapon, rank: rank)
                .first { $0.stat == .damage }?.value ?? 0
            XCTAssertGreaterThan(damage, last)
            last = damage
        }
    }

    // MARK: Buying

    func testAWeaponMustBeBoughtBeforeItCanBeMastered() {
        var profile = LegacyProfile()
        let katana = StarterWeapons.katana
        XCTAssertFalse(profile.isUnlocked(katana))
        XCTAssertNotNil(profile.masteryDenial(for: katana))

        profile.echoes = WeaponMastery.totalCost(katana)
        XCTAssertTrue(profile.buy(weapon: katana))
        XCTAssertTrue(profile.isUnlocked(katana))
        XCTAssertFalse(profile.buy(weapon: katana), "a weapon should not be bought twice")

        for rank in 1...WeaponMastery.maxRank {
            XCTAssertTrue(profile.master(weapon: katana), "rank \(rank) was refused")
        }
        XCTAssertEqual(profile.rank(of: katana), WeaponMastery.maxRank)
        XCTAssertFalse(profile.master(weapon: katana), "mastery went past its last rank")
        XCTAssertEqual(profile.echoes, 0, "buying the lot should cost exactly what it says")
    }

    func testTheFreeThreeNeedNoBuying() {
        let profile = LegacyProfile()
        for id in StarterWeapons.defaultUnlocked {
            let weapon = StarterWeapons.definition(for: id)!
            XCTAssertTrue(profile.isUnlocked(weapon))
            XCTAssertEqual(WeaponMastery.unlockCost(weapon), 0)
        }
    }

    func testEchoesAreNotSpentOnARefusedPurchase() {
        var profile = LegacyProfile()
        profile.echoes = 10
        let katana = StarterWeapons.katana
        XCTAssertFalse(profile.buy(weapon: katana))
        XCTAssertEqual(profile.echoes, 10)
        XCTAssertFalse(profile.isUnlocked(katana))
    }

    // MARK: The save file

    func testAProfileWrittenBeforeTheArmouryStillLoads() throws {
        let old = """
        {"echoes": 120, "spent": 40, "unlocked": ["legacy.body.1.1"]}
        """
        let profile = try JSONDecoder().decode(LegacyProfile.self, from: Data(old.utf8))
        XCTAssertEqual(profile.echoes, 120)
        XCTAssertEqual(profile.spent, 40)
        XCTAssertEqual(profile.unlocked, ["legacy.body.1.1"])
        XCTAssertTrue(profile.weapons.isEmpty)
        XCTAssertEqual(profile.rank(of: StarterWeapons.sword), 0)
    }

    func testAProfileRoundTripsWithItsRack() throws {
        var profile = LegacyProfile()
        profile.echoes = 5_000
        profile.buy(weapon: StarterWeapons.warHammer)
        profile.master(weapon: StarterWeapons.warHammer)
        let data = try JSONEncoder().encode(profile)
        let restored = try JSONDecoder().decode(LegacyProfile.self, from: data)
        XCTAssertEqual(restored, profile)
        XCTAssertEqual(restored.rank(of: StarterWeapons.warHammer), 1)
    }
}
