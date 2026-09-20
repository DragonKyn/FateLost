import XCTest
@testable import FateLost

/// A weapon in a chest is a trade: it replaces the one in the hand. These
/// tests hold that trade honest — never the weapon you already have, never
/// more affixes than its rarity earns, never an affix that makes no sense on
/// the weapon it is rolled for — and check the swap takes effect in a run.
final class WeaponFindTests: XCTestCase {
    // MARK: Affixes

    func testAffixesAreWholeAndUnique() {
        var ids = Set<String>()
        for affix in WeaponAffixCatalog.all {
            XCTAssertFalse(ids.contains(affix.id), "two affixes share \(affix.id)")
            ids.insert(affix.id)
            XCTAssertFalse(affix.prefix.isEmpty)
            XCTAssertFalse(affix.suffix.isEmpty)
            XCTAssertFalse(affix.text.isEmpty)
        }
        XCTAssertGreaterThanOrEqual(WeaponAffixCatalog.all.count, 12)
    }

    func testNoAffixIsBiggerThanARelicOfTheSameRarityWouldBe() {
        for affix in WeaponAffixCatalog.all {
            switch affix.modifier.kind {
            case .increased, .more:
                XCTAssertLessThanOrEqual(affix.modifier.value, 0.25, "\(affix.id) is a large multiplier")
            case .flat:
                switch affix.modifier.stat {
                case .critChance: XCTAssertLessThanOrEqual(affix.modifier.value, 0.08)
                case .lifeSteal: XCTAssertLessThanOrEqual(affix.modifier.value, 0.03)
                default: break
                }
            }
        }
    }

    func testAffixesThatNeedAKindOfWeaponOnlyFitIt() {
        XCTAssertTrue(WeaponAffixCatalog.sweeping.fits(StarterWeapons.katana))
        XCTAssertFalse(WeaponAffixCatalog.sweeping.fits(StarterWeapons.bow))
        XCTAssertTrue(WeaponAffixCatalog.piercing.fits(StarterWeapons.bow))
        XCTAssertFalse(WeaponAffixCatalog.piercing.fits(StarterWeapons.warHammer))
        XCTAssertTrue(WeaponAffixCatalog.keen.fits(StarterWeapons.sword))
        XCTAssertTrue(WeaponAffixCatalog.keen.fits(StarterWeapons.staff))
    }

    // MARK: Rolling

    func testAFindIsNeverTheWeaponAlreadyInTheHand() {
        var random = SeededRandom(seed: 6)
        for _ in 0..<400 {
            let find = WeaponRoller.roll(tier: .hoard, wielding: StarterWeapons.sword.id, random: &random)
            XCTAssertNotNil(find)
            XCTAssertNotEqual(find?.weapon, StarterWeapons.sword.id)
        }
    }

    func testFindsAreNeverCommonAndCarryTheAffixesTheirRarityEarns() {
        var random = SeededRandom(seed: 17)
        for tier in LootTier.allCases {
            for _ in 0..<300 {
                guard let find = WeaponRoller.roll(tier: tier, wielding: nil, random: &random) else {
                    return XCTFail("nothing rolled")
                }
                XCTAssertNotEqual(find.rarity, .common)
                XCTAssertEqual(find.affixes.count, WeaponRoller.affixCount(for: find.rarity))
                XCTAssertEqual(Set(find.affixes.map(\.id)).count, find.affixes.count, "an affix rolled twice")
                let base = StarterWeapons.definition(for: find.weapon)!
                XCTAssertTrue(find.affixes.allSatisfy { $0.fits(base) }, "\(find.title) has an affix that does not fit")
            }
        }
    }

    func testARichTierRollsBetterThanAPoorOne() {
        var random = SeededRandom(seed: 3)
        func averageRarity(_ tier: LootTier) -> Double {
            var total = 0
            for _ in 0..<500 {
                total += WeaponRoller.roll(tier: tier, wielding: nil, random: &random)?.rarity.rawValue ?? 0
            }
            return Double(total) / 500
        }
        XCTAssertGreaterThan(averageRarity(.hoard), averageRarity(.chest))
        XCTAssertGreaterThan(averageRarity(.chest), averageRarity(.cache))
    }

    func testAFindCanBeAWeaponThePlayerDoesNotOwn() {
        var random = SeededRandom(seed: 44)
        var sawLocked = false
        for _ in 0..<200 {
            if let find = WeaponRoller.roll(tier: .chest, wielding: nil, random: &random),
               !StarterWeapons.defaultUnlocked.contains(find.weapon) {
                sawLocked = true
            }
        }
        XCTAssertTrue(sawLocked, "a run can never try a weapon it has not bought")
    }

    func testTheSameSeedRollsTheSameWeapon() {
        var one = SeededRandom(seed: 71)
        var two = SeededRandom(seed: 71)
        XCTAssertEqual(WeaponRoller.roll(tier: .hoard, wielding: nil, random: &one),
                       WeaponRoller.roll(tier: .hoard, wielding: nil, random: &two))
    }

    func testRicherFindsCarryAWeaponMoreOften() {
        XCTAssertLessThan(WeaponRoller.chance(of: .cache), WeaponRoller.chance(of: .chest))
        XCTAssertLessThan(WeaponRoller.chance(of: .chest), WeaponRoller.chance(of: .hoard))
        XCTAssertLessThan(WeaponRoller.chance(of: .hoard), 0.6, "a weapon should not crowd out the relics")
    }

    // MARK: What a find is

    func testAFindReadsAsAnItem() {
        let find = WeaponFind(weapon: StarterWeapons.katana.id, rarity: .rare,
                              affixes: [WeaponAffixCatalog.keen, WeaponAffixCatalog.swift], damageScale: 1.1)
        XCTAssertEqual(find.title, "Keen Katana of Haste")
        let single = WeaponFind(weapon: StarterWeapons.katana.id, rarity: .uncommon,
                                affixes: [WeaponAffixCatalog.heavy], damageScale: 1)
        XCTAssertEqual(single.title, "Heavy Katana")
    }

    func testAFindsDamageIsScaledAndTheRestIsTheBaseWeapon() throws {
        let find = WeaponFind(weapon: StarterWeapons.katana.id, rarity: .epic,
                              affixes: [WeaponAffixCatalog.keen], damageScale: 1.2)
        let definition = try XCTUnwrap(find.definition)
        XCTAssertEqual(definition.baseDamage, StarterWeapons.katana.baseDamage * 1.2, accuracy: 0.0001)
        XCTAssertEqual(definition.id, StarterWeapons.katana.id)
        XCTAssertEqual(definition.attackSpeed, StarterWeapons.katana.attackSpeed)
        XCTAssertEqual(definition.spriteID, StarterWeapons.katana.spriteID)
        XCTAssertEqual(definition.rarity, .epic)
    }

    func testARolledScaleStaysInsideItsBand() {
        var random = SeededRandom(seed: 90)
        for _ in 0..<500 {
            guard let find = WeaponRoller.roll(tier: .hoard, wielding: nil, random: &random) else { continue }
            XCTAssertGreaterThan(find.damageScale, 1.0)
            XCTAssertLessThan(find.damageScale, 1.35)
        }
    }

    // MARK: In a run

    private func simulationWithAWeaponOnOffer() -> GameSimulation? {
        for seed in UInt64(1)...200 {
            var simulation = GameSimulation(run: RunConfiguration(realmID: .ashenWilds,
                                                                  starterWeaponID: StarterWeapons.sword.id,
                                                                  seed: seed), tuning: .standard)
            simulation.openOffer(tier: .hoard)
            if simulation.offer?.weapon != nil { return simulation }
        }
        return nil
    }

    func testTakingAWeaponReplacesTheOneInTheHand() throws {
        var simulation = try XCTUnwrap(simulationWithAWeaponOnOffer(), "no weapon turned up in 200 runs")
        let find = try XCTUnwrap(simulation.offer?.weapon)
        let beforeStat = simulation.sheet[find.affixes[0].modifier.stat]

        XCTAssertTrue(simulation.chooseWeapon())
        XCTAssertNil(simulation.offer)
        XCTAssertEqual(simulation.weapon.id, find.weapon)
        XCTAssertNotEqual(simulation.weapon.id, StarterWeapons.sword.id)
        XCTAssertEqual(simulation.wielded, find)
        XCTAssertNotEqual(simulation.sheet[find.affixes[0].modifier.stat], beforeStat,
                          "holding the weapon changed nothing about the hero")
        XCTAssertTrue(simulation.drainEvents().contains {
            if case .weaponWielded = $0 { return true }
            return false
        })
    }

    func testAWeaponOnlyCompetesWithTheRelicsForTheChoice() throws {
        var simulation = try XCTUnwrap(simulationWithAWeaponOnOffer())
        XCTAssertTrue(simulation.chooseRelic(at: 0))
        XCTAssertNil(simulation.offer)
        XCTAssertNil(simulation.wielded, "taking a relic still handed over the weapon")
        XCTAssertEqual(simulation.weapon.id, StarterWeapons.sword.id)
    }

    func testChoosingAWeaponThatIsNotThereIsRefused() {
        var simulation = GameSimulation(run: RunConfiguration(realmID: .ashenWilds,
                                                              starterWeaponID: StarterWeapons.sword.id, seed: 7),
                                        tuning: .standard)
        XCTAssertFalse(simulation.chooseWeapon(), "no offer is open")
        simulation.openOffer(tier: .cache)
        if simulation.offer?.weapon == nil {
            XCTAssertFalse(simulation.chooseWeapon())
            XCTAssertNotNil(simulation.offer, "a refused choice closed the find")
        }
    }

    func testTheNextFindNeverOffersTheWeaponNowInTheHand() throws {
        var simulation = try XCTUnwrap(simulationWithAWeaponOnOffer())
        XCTAssertTrue(simulation.chooseWeapon())
        let wielded = simulation.weapon.id
        for _ in 0..<40 {
            simulation.openOffer(tier: .hoard)
            if let offered = simulation.offer?.weapon {
                XCTAssertNotEqual(offered.weapon, wielded)
            }
            XCTAssertEqual(simulation.offer?.wielding, wielded)
            _ = simulation.chooseRelic(at: 0)
        }
    }
}
