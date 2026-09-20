import Foundation
import XCTest
@testable import FateLost

/// What a player brings to a party, and how the host turns it back into stats.
final class PartyLoadoutTests: XCTestCase {
    private func profile(owning nodes: Int = 5, weaponRank: Int = 0, discovered: Int = 0) -> LegacyProfile {
        var profile = LegacyProfile()
        for node in LegacyTree.all.prefix(nodes) {
            profile.unlocked.insert(node.id)
        }
        if weaponRank > 0 {
            profile.weaponRanks[StarterWeapons.sword.id] = weaponRank
        }
        for index in 0..<discovered {
            profile.lifetime.relicsSeen["relic-\(index)"] = 1
        }
        return profile
    }

    func testTheLegacyTravelsAsIDsAndPseudoIDs() {
        let mine = profile(owning: 4, weaponRank: 3)
        let ids = PartyLegacy.ids(from: mine, weapon: StarterWeapons.sword)
        XCTAssertEqual(ids.filter { LegacyTree.node($0) != nil }.count, 4)
        XCTAssertTrue(ids.contains("mastery.sword.3"))
        XCTAssertTrue(ids.contains { $0.hasPrefix("rerolls.") })
    }

    func testTheHostRebuildsTheSameBonusesFromTheIDs() {
        let mine = profile(owning: 6, weaponRank: 2)
        let ids = PartyLegacy.ids(from: mine, weapon: StarterWeapons.sword)
        let rebuilt = PartyLegacy.modifiers(from: ids, weapon: StarterWeapons.sword)
        let expected = mine.modifiers + mine.modifiers(startingWith: StarterWeapons.sword)
        XCTAssertEqual(rebuilt.count, expected.count)
        // Order is not promised; the totals must match.
        func total(_ list: [StatModifier]) -> Double { list.reduce(0) { $0 + $1.value } }
        XCTAssertEqual(total(rebuilt), total(expected), accuracy: 0.0001)
    }

    func testABonusCannotBeClaimedTwice() {
        let node = LegacyTree.all[0]
        let once = PartyLegacy.modifiers(from: [node.id], weapon: StarterWeapons.sword)
        let many = PartyLegacy.modifiers(from: Array(repeating: node.id, count: 50), weapon: StarterWeapons.sword)
        XCTAssertEqual(once.count, 1)
        XCTAssertEqual(many.count, 1)
    }

    func testMadeUpIDsAreIgnored() {
        let ids = ["not.a.node", "../../etc", "mastery.sword.nine", "mastery", "rerolls.many", ""]
        XCTAssertTrue(PartyLegacy.modifiers(from: ids, weapon: StarterWeapons.sword).isEmpty)
        XCTAssertEqual(PartyLegacy.bonusRerolls(from: ids), 0)
    }

    func testMasteryOnlyCountsForTheWeaponCarried() {
        XCTAssertFalse(PartyLegacy.modifiers(from: ["mastery.sword.3"], weapon: StarterWeapons.sword).isEmpty)
        XCTAssertTrue(PartyLegacy.modifiers(from: ["mastery.sword.3"], weapon: StarterWeapons.bow).isEmpty)
    }

    func testMasteryAndRerollsAreCappedAtWhatIsPossible() {
        let big = PartyLegacy.modifiers(from: ["mastery.sword.999"], weapon: StarterWeapons.sword)
        let capped = PartyLegacy.modifiers(from: ["mastery.sword.\(WeaponMastery.maxRank)"], weapon: StarterWeapons.sword)
        XCTAssertEqual(big.count, capped.count)
        XCTAssertEqual(PartyLegacy.bonusRerolls(from: ["rerolls.99"]), CodexRewards.thresholds.count)
        XCTAssertEqual(PartyLegacy.bonusRerolls(from: ["rerolls.-4"]), 0)
    }

    func testTheHostReadsOnlyAReasonableNumberOfIDs() {
        let flood = (0..<5_000).map { "junk-\($0)" } + LegacyTree.all.suffix(3).map { $0.id }
        // The real nodes are past the cut, so none of them count.
        XCTAssertTrue(PartyLegacy.modifiers(from: flood, weapon: StarterWeapons.sword).isEmpty)
    }

    func testTheLoadoutCarriesTheWeaponTheLookAndTheLegacy() {
        var look = HeroAppearance.standard
        look.build = .broad
        let loadout = PartyLoadout.make(weapon: StarterWeapons.bow, hero: look, profile: profile(owning: 3))
        XCTAssertEqual(loadout.weapon, StarterWeapons.bow.id)
        XCTAssertEqual(loadout.hero?["build"]?.stringValue, BodyBuild.broad.rawValue)
        XCTAssertGreaterThanOrEqual(loadout.legacy.count, 3)
        XCTAssertEqual(PartyLoadout.appearance(from: loadout.hero), look)
    }

    func testAHeroLookThatCannotBeReadFallsBackToTheDefault() {
        XCTAssertEqual(PartyLoadout.appearance(from: nil), .standard)
        XCTAssertEqual(PartyLoadout.appearance(from: ["build": .string("dragon")]).build, HeroAppearance.standard.build)
        XCTAssertEqual(PartyLoadout.appearance(from: ["build": .number(7)]), .standard)
    }

    func testTheLookTheServerAllowsIsWhatALookIsMadeOf() {
        // The service accepts flat objects of short strings; a look must fit.
        guard case .object(let fields)? = JSONValue.from(HeroAppearance.standard) else {
            return XCTFail("a look is a flat object")
        }
        XCTAssertLessThanOrEqual(fields.count, 40)
        for (key, value) in fields {
            XCTAssertLessThanOrEqual(key.count, 40)
            if case .string(let text) = value { XCTAssertLessThanOrEqual(text.count, 80) }
        }
    }

    func testARosterBecomesAPartyHostFirst() {
        let node = LegacyTree.all[0]
        let info = RunStartInfo(
            resumed: false, runId: "r", runNumber: 1, seed: "9", realm: "ashenWilds", hostId: "h", you: "h",
            roster: [
                .init(id: "g2", name: "Kevin", fateId: "FL-AAAA-BBBB", slot: 2, weapon: "staff", hero: nil, legacy: nil),
                .init(id: "h", name: "Jesse", fateId: "FL-AAAA-BBBB", slot: 0, weapon: "sword", hero: nil,
                      legacy: [node.id, "rerolls.2"]),
                .init(id: "g1", name: "Whitney", fateId: "FL-AAAA-BBBB", slot: 1, weapon: "no-such-weapon", hero: nil,
                      legacy: nil),
            ])
        let configs = info.partyConfigs()
        XCTAssertEqual(configs.map { $0.id }, ["h", "g1", "g2"], "the host first, then by seat")
        XCTAssertEqual(configs[0].bonusRerolls, 2)
        XCTAssertEqual(configs[0].legacy.count, 1)
        XCTAssertEqual(configs[1].weaponID, StarterWeapons.sword.id, "an unknown weapon becomes the sword")
        XCTAssertEqual(configs[2].weaponID, StarterWeapons.staff.id)
        XCTAssertEqual(configs.map { $0.slot }, [0, 1, 2])
    }

    func testAPartyBuiltFromARosterRuns() {
        let info = RunStartInfo(
            resumed: false, runId: "r", runNumber: 1, seed: "12345", realm: "ashenWilds", hostId: "h", you: "h",
            roster: [
                .init(id: "h", name: "Jesse", fateId: "FL-AAAA-BBBB", slot: 0, weapon: "sword", hero: nil, legacy: []),
                .init(id: "g", name: "Whitney", fateId: "FL-AAAA-BBBB", slot: 1, weapon: "bow", hero: nil, legacy: nil),
            ])
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: info.seedValue)
        var simulation = GameSimulation(run: run, tuning: .standard, party: info.partyConfigs())
        XCTAssertEqual(simulation.heroCount, 2)
        for _ in 0..<120 { simulation.step(dt: 1.0 / 60) }
        XCTAssertEqual(simulation.heroSummary(1).name, "Whitney")
    }
}
