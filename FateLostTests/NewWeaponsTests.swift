import XCTest
@testable import FateLost

/// The ten weapons added alongside the difficulty modifiers: each has to be
/// a whole, balanced entry on the rack, and the two with a stated synergy
/// (Shuriken with Rogue, Hand Claws with a Druid form) have to actually work.
final class NewWeaponsTests: XCTestCase {
    private let newWeapons: [WeaponDefinition] = [
        StarterWeapons.spear, StarterWeapons.lance, StarterWeapons.halberd, StarterWeapons.scythe,
        StarterWeapons.heavyAxe, StarterWeapons.whip, StarterWeapons.nunchaku, StarterWeapons.handClaws,
        StarterWeapons.crossbow, StarterWeapons.shuriken,
    ]

    func testAllTenAreOnTheRackWithArt() throws {
        XCTAssertEqual(newWeapons.count, 10)
        for weapon in newWeapons {
            XCTAssertTrue(StarterWeapons.all.contains { $0.id == weapon.id }, "\(weapon.name) is missing from the rack")
            XCTAssertFalse(StarterWeapons.defaultUnlocked.contains(weapon.id), "\(weapon.name) should cost echoes")
            let sprite = try XCTUnwrap(PlaceholderArt.sprite(for: weapon.spriteID), "\(weapon.name) has no art")
            XCTAssertGreaterThan(sprite.image.size.width, 0)
            XCTAssertTrue(SpriteCatalog.gameplaySprites.contains(weapon.spriteID), "\(weapon.name) art is never preloaded")
            if case .projectile(let profile) = weapon.delivery {
                XCTAssertTrue(SpriteCatalog.gameplaySprites.contains(profile.spriteID),
                              "\(weapon.name)'s projectile art is never preloaded")
            }
        }
    }

    func testEachHasAMasteryAffinityWorthHaving() {
        for weapon in newWeapons {
            let lean = WeaponMastery.affinity(of: weapon)
            XCTAssertGreaterThan(lean.value, 0, weapon.name)
            XCTAssertFalse(lean.stat.isWholeNumber, "\(weapon.name) leans on a whole-number stat, which mastery can't scale into safely")
        }
    }

    func testCrossbowIsASlowHardHittingBoltWithPierce() {
        guard case .projectile(let profile) = StarterWeapons.crossbow.delivery else {
            return XCTFail("the crossbow should fire a bolt")
        }
        XCTAssertGreaterThan(profile.pierce, 0)
        XCTAssertLessThan(StarterWeapons.crossbow.attackSpeed, StarterWeapons.bow.attackSpeed)
        XCTAssertGreaterThan(StarterWeapons.crossbow.baseDamage, StarterWeapons.bow.baseDamage)
    }

    func testShurikenThrowsTwoAndPiercesDeeply() {
        guard case .projectile(let profile) = StarterWeapons.shuriken.delivery else {
            return XCTFail("the shuriken should be thrown")
        }
        XCTAssertEqual(profile.count, 2)
        XCTAssertGreaterThanOrEqual(profile.pierce, 3, "should scale into a Rogue's pierce and multistrike")
    }

    func testHandClawsAreTheFastestMeleeWeapon() {
        let melee = StarterWeapons.all.filter { if case .meleeArc = $0.delivery { return true } else { return false } }
        let fastest = melee.map(\.attackSpeed).max() ?? 0
        XCTAssertEqual(StarterWeapons.handClaws.attackSpeed, fastest)
    }

    // MARK: The Hand Claws / Druid synergy

    func testHandClawsBoostDamageWhileShapeshifted() {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.handClaws.id, seed: 3)
        var sim = GameSimulation(run: run, tuning: .standard)
        let baseline = sim.sheet[.damage]

        sim.player.form = FormCatalog.bear.id
        sim.combat.build.formRanks[FormCatalog.bear.id] = 1
        sim.refreshStats(force: true)

        XCTAssertGreaterThan(sim.sheet[.damage], baseline, "Hand Claws should carry their edge into the beast form")
    }

    func testTheShapeshiftBonusIsSpecificToHandClaws() {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 3)
        var sim = GameSimulation(run: run, tuning: .standard)
        let baseline = sim.sheet[.damage]

        sim.player.form = FormCatalog.bear.id
        sim.combat.build.formRanks[FormCatalog.bear.id] = 1
        sim.refreshStats(force: true)

        XCTAssertEqual(sim.sheet[.damage], baseline, accuracy: 0.0001,
                       "only Hand Claws should benefit; a sword gets nothing extra from a form")
    }

    func testHandClawsGetNoBonusWithoutAForm() {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.handClaws.id, seed: 3)
        var sim = GameSimulation(run: run, tuning: .standard)
        let baseline = sim.sheet[.damage]

        sim.refreshStats(force: true)

        XCTAssertEqual(sim.sheet[.damage], baseline, accuracy: 0.0001)
    }
}
