import XCTest
@testable import FateLost

/// The record keeps what a player has done across every run, so the thing
/// that must never happen is losing it. These tests hold three lines: a save
/// written before spoils existed still opens with every total intact, what a
/// run found is folded in once and only ever grows, and the codex pays out
/// exactly what it promises.
final class SpoilsRecordTests: XCTestCase {
    private func summary(relics: RelicInventory = RelicInventory(), chests: Int = 0, shrines: Int = 0,
                         taken: Int = 0, weapons: Int = 0) -> RunSummary {
        var stats = RunStats()
        stats.kills = 50
        stats.chestsOpened = chests
        stats.shrinesUsed = shrines
        stats.relicsTaken = taken
        stats.weaponsWielded = weapons
        return RunSummary(realm: .ashenWilds, weapon: "starter.sword", secondsSurvived: 300, stats: stats,
                          level: 8, allocation: SkillAllocation(), outcome: .defeated, wave: 5, relics: relics)
    }

    // MARK: Old saves

    func testARecordWrittenBeforeSpoilsStillLoadsWithEveryTotal() throws {
        let old = """
        {"echoes": 900, "spent": 300, "unlocked": [],
         "lifetime": {"runs": 12, "conquests": 1, "kills": 3400, "highestWave": 14, "highestLevel": 22,
                      "bestWaveByRealm": {"ashenWilds": 14}, "runsByWeapon": {"starter.sword": 12}}}
        """
        let profile = try JSONDecoder().decode(LegacyProfile.self, from: Data(old.utf8))
        XCTAssertEqual(profile.echoes, 900)
        XCTAssertEqual(profile.lifetime.runs, 12)
        XCTAssertEqual(profile.lifetime.kills, 3400)
        XCTAssertEqual(profile.lifetime.highestWave, 14)
        XCTAssertEqual(profile.lifetime.bestWaveByRealm["ashenWilds"], 14)
        XCTAssertEqual(profile.lifetime.chestsOpened, 0)
        XCTAssertTrue(profile.lifetime.relicsSeen.isEmpty)
        XCTAssertEqual(profile.bonusRerolls, 0)
    }

    func testAnEmptyRecordLoads() throws {
        let profile = try JSONDecoder().decode(LegacyProfile.self, from: Data("{}".utf8))
        XCTAssertEqual(profile, LegacyProfile())
    }

    func testTheRecordRoundTripsWithItsCodex() throws {
        var profile = LegacyProfile()
        var pack = RelicInventory()
        pack.add(CommonRelics.whetstone.id, rank: 2)
        pack.add(EpicRelics.phoenixFeather.id)
        profile.lifetime.add(summary(relics: pack, chests: 3, shrines: 2, taken: 2), realm: RealmCatalog.all[0],
                             echoes: 10)
        let data = try JSONEncoder().encode(profile)
        let restored = try JSONDecoder().decode(LegacyProfile.self, from: data)
        XCTAssertEqual(restored, profile)
        XCTAssertEqual(restored.lifetime.relicsSeen[CommonRelics.whetstone.id], 2)
    }

    // MARK: Folding a run in

    func testARunAddsItsSpoilsToTheRecord() {
        var stats = LifetimeStats()
        var pack = RelicInventory()
        pack.add(CommonRelics.whetstone.id)
        pack.add(CommonRelics.ironRing.id)
        stats.add(summary(relics: pack, chests: 4, shrines: 1, taken: 2, weapons: 1), realm: RealmCatalog.all[0],
                  echoes: 5)
        stats.add(summary(chests: 2, shrines: 3, taken: 0), realm: RealmCatalog.all[0], echoes: 5)

        XCTAssertEqual(stats.chestsOpened, 6)
        XCTAssertEqual(stats.shrinesUsed, 4)
        XCTAssertEqual(stats.relicsTaken, 2)
        XCTAssertEqual(stats.weaponsFound, 1)
        XCTAssertEqual(stats.mostRelicsCarried, 2)
        XCTAssertEqual(stats.relicsDiscovered, 2)
    }

    func testTheCodexKeepsTheBestRankEverCarried() {
        var stats = LifetimeStats()
        var high = RelicInventory()
        high.add(CommonRelics.whetstone.id, rank: 3)
        var low = RelicInventory()
        low.add(CommonRelics.whetstone.id)
        stats.add(summary(relics: high), realm: RealmCatalog.all[0], echoes: 1)
        stats.add(summary(relics: low), realm: RealmCatalog.all[0], echoes: 1)
        XCTAssertEqual(stats.relicsSeen[CommonRelics.whetstone.id], 3, "a weaker run took the record back")
        XCTAssertEqual(stats.relicsDiscovered, 1)
    }

    func testARelicNoLongerInTheGameIsNotCounted() {
        var stats = LifetimeStats()
        stats.relicsSeen["relic.retiredLongAgo"] = 2
        stats.relicsSeen[CommonRelics.whetstone.id] = 1
        XCTAssertEqual(stats.relicsDiscovered, 1, "a retired relic padded the codex")
    }

    // MARK: Rewards

    func testTheCodexPaysARerollAtEachMilestone() {
        XCTAssertEqual(CodexRewards.bonusRerolls(discovered: 0), 0)
        XCTAssertEqual(CodexRewards.bonusRerolls(discovered: 19), 0)
        XCTAssertEqual(CodexRewards.bonusRerolls(discovered: 20), 1)
        XCTAssertEqual(CodexRewards.bonusRerolls(discovered: 43), 1)
        XCTAssertEqual(CodexRewards.bonusRerolls(discovered: 44), 2)
        XCTAssertEqual(CodexRewards.bonusRerolls(discovered: 64), 2)
        XCTAssertEqual(CodexRewards.nextThreshold(discovered: 5), 20)
        XCTAssertEqual(CodexRewards.nextThreshold(discovered: 20), 44)
        XCTAssertNil(CodexRewards.nextThreshold(discovered: 44))
    }

    func testEveryMilestoneCanActuallyBeReached() {
        for threshold in CodexRewards.thresholds {
            XCTAssertLessThanOrEqual(threshold, RelicCatalog.all.count, "\(threshold) is out of reach")
        }
    }

    func testAProfilesRerollsFollowItsCodex() {
        var profile = LegacyProfile()
        for relic in RelicCatalog.all.prefix(20) {
            profile.lifetime.relicsSeen[relic.id] = 1
        }
        XCTAssertEqual(profile.bonusRerolls, 1)
    }

    func testTheCodexRerollsAreOnEveryFindInARun() {
        var simulation = GameSimulation(run: RunConfiguration(realmID: .ashenWilds,
                                                              starterWeaponID: StarterWeapons.sword.id, seed: 7),
                                        tuning: .standard, bonusRerolls: 2)
        simulation.openOffer(tier: .chest)
        XCTAssertEqual(simulation.offer?.rerollsLeft, RelicRoller.rerolls + 2)
        XCTAssertTrue(simulation.rerollOffer())
        XCTAssertTrue(simulation.rerollOffer())
        XCTAssertTrue(simulation.rerollOffer())
        XCTAssertFalse(simulation.rerollOffer())
    }

    // MARK: Counting in a run

    func testAChestAndAShrineAndARelicAreCountedAsTheyHappen() {
        var simulation = GameSimulation(run: RunConfiguration(realmID: .ashenWilds,
                                                              starterWeaponID: StarterWeapons.sword.id, seed: 7),
                                        tuning: .standard)
        simulation.cheats.spawningEnabled = false
        simulation.spawnDrop(.chest(.chest))
        simulation.spawnShrine(.fortune)
        simulation.step(dt: 1.0 / 60, intent: .idle)
        XCTAssertEqual(simulation.stats.chestsOpened, 1)
        XCTAssertEqual(simulation.stats.shrinesUsed, 1)

        XCTAssertTrue(simulation.chooseRelic(at: 0))
        XCTAssertEqual(simulation.stats.relicsTaken, 1)
    }
}
