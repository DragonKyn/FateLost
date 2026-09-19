import XCTest
@testable import FateLost

/// The Legacy board is generated, so what needs pinning down is its shape:
/// enough nodes, no duplicates, bonuses that stay small, and buying rules
/// that cannot be talked into giving something away.
final class LegacyTests: XCTestCase {
    // MARK: The board

    func testBoardIsAtLeastFiveHundredNodes() {
        XCTAssertGreaterThanOrEqual(LegacyTree.all.count, 500)
        XCTAssertEqual(LegacyTree.all.count,
                       LegacyBranch.allCases.count * LegacyTree.tierCount * LegacyTree.nodesPerTier)
    }

    func testEveryNodeHasItsOwnIdentity() {
        let ids = Set(LegacyTree.all.map(\.id))
        XCTAssertEqual(ids.count, LegacyTree.all.count, "two nodes share an id")
        for node in LegacyTree.all {
            XCTAssertEqual(LegacyTree.node(node.id), node)
        }
    }

    /// Every node is a minor advantage. If one of these ever fails, some
    /// node has become a reason to play, which is what Legacy must not be.
    func testEveryBonusStaysMinor() {
        for node in LegacyTree.all {
            switch node.modifier.kind {
            case .flat:
                XCTAssertLessThanOrEqual(node.modifier.value, 20, "\(node.id) grants too much flat value")
            case .increased, .more:
                XCTAssertLessThanOrEqual(node.modifier.value, 0.06, "\(node.id) grants more than 6%")
            }
            XCTAssertGreaterThan(node.modifier.value, 0, "\(node.id) grants nothing")
        }
    }

    func testDeeperTiersCostMoreAndGiveMore() {
        for branch in LegacyBranch.allCases {
            let first = LegacyTree.nodes(in: branch, tier: 1)
            let last = LegacyTree.nodes(in: branch, tier: LegacyTree.tierCount)
            XCTAssertEqual(first.count, LegacyTree.nodesPerTier)
            XCTAssertGreaterThan(last[0].cost, first[0].cost)
            XCTAssertGreaterThan(last[0].modifier.value, first[0].modifier.value)
        }
    }

    // MARK: Buying

    func testATierOpensOnlyOnceEnoughOfTheOneAboveIsTaken() {
        var profile = LegacyProfile()
        profile.echoes = 1_000_000
        let tierTwo = LegacyTree.nodes(in: .body, tier: 2)[0]
        XCTAssertFalse(profile.isReachable(tierTwo))
        XCTAssertNotNil(profile.denial(for: tierTwo))

        for node in LegacyTree.nodes(in: .body, tier: 1).prefix(LegacyTree.nodesToAdvance) {
            XCTAssertTrue(profile.buy(node))
        }
        XCTAssertTrue(profile.isReachable(tierTwo))
        XCTAssertNil(profile.denial(for: tierTwo))
    }

    func testStrandsOpenIndependently() {
        var profile = LegacyProfile()
        profile.echoes = 1_000_000
        for node in LegacyTree.nodes(in: .body, tier: 1).prefix(LegacyTree.nodesToAdvance) {
            profile.buy(node)
        }
        // Progress in Body says nothing about Flame.
        XCTAssertTrue(profile.isReachable(LegacyTree.nodes(in: .body, tier: 2)[0]))
        XCTAssertFalse(profile.isReachable(LegacyTree.nodes(in: .flame, tier: 2)[0]))
    }

    func testBuyingSpendsExactlyOnceAndCannotBeRepeated() {
        var profile = LegacyProfile()
        let node = LegacyTree.nodes(in: .blade, tier: 1)[0]
        profile.echoes = node.cost

        XCTAssertTrue(profile.buy(node))
        XCTAssertEqual(profile.echoes, 0)
        XCTAssertEqual(profile.spent, node.cost)
        XCTAssertEqual(profile.count(in: .blade), 1)

        XCTAssertFalse(profile.buy(node), "a node cannot be bought twice")
        XCTAssertEqual(profile.spent, node.cost)
    }

    func testCannotBuyWhatCannotBeAfforded() {
        var profile = LegacyProfile()
        let node = LegacyTree.nodes(in: .ward, tier: 1)[0]
        profile.echoes = node.cost - 1
        XCTAssertFalse(profile.buy(node))
        XCTAssertTrue(profile.unlocked.isEmpty)
        XCTAssertEqual(profile.echoes, node.cost - 1)
    }

    func testModifiersMatchWhatWasBought() {
        var profile = LegacyProfile()
        profile.echoes = 1_000_000
        let nodes = Array(LegacyTree.nodes(in: .focus, tier: 1).prefix(3))
        for node in nodes { profile.buy(node) }
        XCTAssertEqual(profile.modifiers.count, nodes.count)
        for node in nodes {
            XCTAssertTrue(profile.modifiers.contains(node.modifier))
        }
    }

    // MARK: Runs and the record

    private func summary(kills: Int = 100, wave: Int = 7, level: Int = 12,
                         outcome: RunSummary.Outcome = .defeated) -> RunSummary {
        var stats = RunStats()
        stats.kills = kills
        stats.eliteKills = 3
        stats.bossKills = outcome == .conquered ? 2 : 1
        stats.damageDealt = 5_000
        return RunSummary(realm: .ashenWilds, weapon: "weapon.sword", secondsSurvived: 400, stats: stats,
                          level: level, allocation: SkillAllocation(), outcome: outcome, wave: wave)
    }

    func testARunAlwaysPaysSomething() {
        let barelyStarted = RunSummary(realm: .ashenWilds, weapon: "weapon.sword", secondsSurvived: 3,
                                       stats: RunStats(), level: 1, allocation: SkillAllocation(),
                                       outcome: .defeated, wave: 1)
        XCTAssertGreaterThan(LegacyEchoes.earned(from: barelyStarted.stats, wave: 1, level: 1,
                                                 realmMultiplier: 1, conquered: false), 0)
    }

    func testConquestIsWorthMoreThanFalling() {
        let stats = summary().stats
        let fell = LegacyEchoes.earned(from: stats, wave: 10, level: 15, realmMultiplier: 1, conquered: false)
        let took = LegacyEchoes.earned(from: stats, wave: 10, level: 15, realmMultiplier: 1, conquered: true)
        XCTAssertGreaterThan(took, fell)
    }

    func testHarderRealmsPayMore() {
        let stats = summary().stats
        let easy = LegacyEchoes.earned(from: stats, wave: 10, level: 15, realmMultiplier: 1, conquered: false)
        let hard = LegacyEchoes.earned(from: stats, wave: 10, level: 15, realmMultiplier: 3, conquered: false)
        XCTAssertGreaterThan(hard, easy)
    }

    func testRecordingARunPaysOutAndWritesHistory() {
        var profile = LegacyProfile()
        let run = summary()
        profile.record(run, realm: RealmCatalog.realm(.ashenWilds))

        XCTAssertGreaterThan(profile.echoes, 0)
        XCTAssertEqual(profile.lifetime.runs, 1)
        XCTAssertEqual(profile.lifetime.deaths, 1)
        XCTAssertEqual(profile.lifetime.kills, run.stats.kills)
        XCTAssertEqual(profile.lifetime.highestWave, run.wave)
        XCTAssertEqual(profile.lifetime.bestWaveByRealm[RealmID.ashenWilds.rawValue], run.wave)
        XCTAssertEqual(profile.lifetime.echoesEarned, profile.echoes)
    }

    func testConqueringARealmOpensTheNextOne() {
        var profile = LegacyProfile()
        profile.record(summary(outcome: .conquered), realm: RealmCatalog.realm(.ashenWilds))
        XCTAssertTrue(profile.realms.conquered.contains(.ashenWilds))
        XCTAssertEqual(profile.lifetime.conquests, 1)
        XCTAssertEqual(profile.lifetime.deaths, 0)
    }

    func testBestsOnlyEverImprove() {
        var profile = LegacyProfile()
        profile.record(summary(wave: 12, level: 20), realm: RealmCatalog.realm(.ashenWilds))
        profile.record(summary(wave: 4, level: 5), realm: RealmCatalog.realm(.ashenWilds))
        XCTAssertEqual(profile.lifetime.highestWave, 12)
        XCTAssertEqual(profile.lifetime.highestLevel, 20)
        XCTAssertEqual(profile.lifetime.runs, 2)
    }

    // MARK: Persistence

    func testAProfileSurvivesASaveAndLoad() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = LegacyStore(fileURL: url)
        XCTAssertEqual(store.load(), LegacyProfile(), "a missing file is a new player, not an error")

        var profile = LegacyProfile()
        profile.echoes = 5_000
        profile.buy(LegacyTree.nodes(in: .fate, tier: 1)[0])
        profile.record(summary(), realm: RealmCatalog.realm(.ashenWilds))
        XCTAssertTrue(store.save(profile))

        XCTAssertEqual(LegacyStore(fileURL: url).load(), profile)
    }
}
