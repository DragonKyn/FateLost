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

/// No upgrade may be worth nothing, or read as if it were.
final class LegacyValueTests: XCTestCase {
    /// The first number in a line such as "+0.3% Cooldown Reduction".
    private func leadingNumber(_ text: String) -> Double? {
        let digits = text.drop { !$0.isNumber }.prefix { $0.isNumber || $0 == "." }
        return Double(digits)
    }

    func testEveryNodeIsWorthSomethingAndSaysSo() {
        for node in LegacyTree.all {
            XCTAssertGreaterThan(node.modifier.value, 0, "\(node.id) provides nothing")
            let text = node.effectText
            let shown = leadingNumber(text)
            XCTAssertNotNil(shown, "\(node.id) shows no number: \(text)")
            XCTAssertGreaterThan(shown ?? 0, 0, "\(node.id) reads as zero: \(text)")
            XCTAssertTrue(text.hasPrefix("+"), text)
            XCTAssertFalse(text.contains("e+") || text.contains("e-"), "\(node.id) shows an exponent: \(text)")
        }
    }

    func testTheShownNumberIsTheRealOneToWithinRounding() {
        for node in LegacyTree.all {
            let modifier = node.modifier
            let real = (modifier.kind != .flat || modifier.stat.isFraction) ? modifier.value * 100 : modifier.value
            guard let shown = leadingNumber(node.effectText) else { continue }
            XCTAssertEqual(shown, real, accuracy: max(0.0006, real * 0.03), "\(node.id): \(node.effectText)")
        }
    }

    func testFractionStatsAreShownAsPercentages() {
        for node in LegacyTree.all where node.modifier.stat.isFraction {
            XCTAssertTrue(node.effectText.contains("%"), "\(node.id) is a fraction shown raw: \(node.effectText)")
        }
        let quickRecall = LegacyTree.nodes(in: .focus, tier: 1)[1]
        XCTAssertEqual(quickRecall.effectText, "+0.3% Cooldown Reduction")
        let luckyAngle = LegacyTree.nodes(in: .fortune, tier: 1)[2]
        XCTAssertEqual(luckyAngle.effectText, "+0.3% Critical Chance")
    }

    func testNoNodeAddsAFractionToAStatTheGameReadsInWholeNumbers() {
        // +0.06 pierce truncates to nothing until seventeen of them are owned.
        for node in LegacyTree.all where node.modifier.stat.isWholeNumber {
            XCTAssertGreaterThanOrEqual(node.modifier.value, 1, "\(node.id) would round away to nothing")
        }
    }

    func testNoNodeIsWastedAgainstAStatCap() {
        var total: [StatID: Double] = [:]
        for node in LegacyTree.all where node.modifier.kind == .flat {
            total[node.modifier.stat, default: 0] += node.modifier.value
        }
        for (stat, sum) in total {
            XCTAssertLessThanOrEqual(stat.baseValue + sum, stat.bounds.upperBound,
                                     "the whole board would run into \(stat.displayName)'s cap")
        }
    }

    func testSmallValuesKeepEnoughPrecisionToBeSeen() {
        XCTAssertEqual(StatModifier(.cooldownReduction, .flat, 0.003).displayText, "+0.3% Cooldown Reduction")
        XCTAssertEqual(StatModifier(.spellEcho, .flat, 0.002).displayText, "+0.2% Spell Echo")
        XCTAssertEqual(StatModifier(.healthRegen, .flat, 0.12).displayText, "+0.12 Health Regeneration per second")
        XCTAssertEqual(StatModifier(.maxHealth, .flat, 4).displayText, "+4 Max Health")
        XCTAssertEqual(StatModifier(.damage, .increased, 0.006).displayText, "+0.6% Damage")
        XCTAssertEqual(StatModifier(.critChance, .flat, 0.01).displayText, "+1% Critical Chance")
        XCTAssertEqual(StatModifier(.critDamage, .flat, 0.06).displayText, "+6% Critical Damage")
        XCTAssertEqual(StatModifier(.damage, .increased, 0.00027).displayText, "+0.027% Damage")
        XCTAssertEqual(StatModifier.number(0), "0")
        XCTAssertFalse(StatModifier(.damage, .increased, 0.0000004).displayText.hasPrefix("+0%"))
    }

    func testWeaponMasteryIsWorthSomethingAtEveryRank() {
        for weapon in StarterWeapons.all {
            let lean = WeaponMastery.affinity(of: weapon)
            XCTAssertFalse(lean.stat.isWholeNumber && lean.value < 1, "\(weapon.name) leans on a stat that rounds to nothing")
            XCTAssertGreaterThan(lean.value, 0)
            for rank in 1...WeaponMastery.maxRank {
                for modifier in WeaponMastery.modifiers(for: weapon, rank: rank) {
                    XCTAssertGreaterThan(modifier.value, 0, "\(weapon.name) rank \(rank)")
                    XCTAssertFalse(modifier.displayText.hasPrefix("+0 ") || modifier.displayText.hasPrefix("+0% "),
                                   modifier.displayText)
                }
            }
            XCTAssertFalse(WeaponMastery.rankText(for: weapon).contains("+0 "), weapon.name)
        }
    }
}

/// The Legacy board's icons: each strand reads as what it is, at the size it is drawn.
final class LegacyIconTests: XCTestCase {
    private func bounds(of glyph: String) -> CGRect {
        LegacyGlyph.pieces(named: glyph).reduce(CGRect.null) { $0.union($1.path.boundingRect) }
    }

    func testTheParserReadsPathsTheWayTheToolWritesThem() {
        let square = LegacyGlyph.path(from: "M0 0 L10 0 L10 10 L0 10 Z").boundingRect
        XCTAssertEqual(square, CGRect(x: 0, y: 0, width: 10, height: 10))
        let ellipse = LegacyGlyph.path(from: "E 5 5 2 3").boundingRect
        XCTAssertEqual(ellipse.width, 4, accuracy: 0.01)
        XCTAssertEqual(ellipse.height, 6, accuracy: 0.01)
        let curve = LegacyGlyph.path(from: "M0 0 Q5 10 10 0 M2 2 C3 3 4 3 5 2").boundingRect
        XCTAssertGreaterThan(curve.width, 9.9)
        XCTAssertEqual(LegacyGlyph.style(from: "stroke:1.7:0.65"), .stroke(width: 1.7, opacity: 0.65))
        XCTAssertEqual(LegacyGlyph.style(from: "stroke:2"), .stroke(width: 2, opacity: 1))
        XCTAssertEqual(LegacyGlyph.style(from: "shade"), .shade)
        XCTAssertEqual(LegacyGlyph.style(from: "fill"), .fill)
    }

    func testEveryStrandHasAnIconAndTheOnesWithoutADrawingKeepASensibleSymbol() {
        var glyphs = Set<String>()
        var symbols = Set<String>()
        for branch in LegacyBranch.allCases {
            if let glyph = branch.glyph {
                XCTAssertTrue(LegacyGlyph.names.contains(glyph), "\(branch.name) points at a glyph that does not exist")
                XCTAssertTrue(glyphs.insert(glyph).inserted, "\(branch.name) shares its icon")
            } else {
                XCTAssertTrue(symbols.insert(branch.symbol).inserted, "\(branch.name) shares its symbol")
            }
        }
        XCTAssertEqual(LegacyBranch.blade.glyph, "blade")
        XCTAssertNotEqual(LegacyBranch.blade.symbol, "scissors", "Blade is not a pair of scissors")
        XCTAssertNil(LegacyBranch.body.glyph)
        XCTAssertNotNil(LegacyGlyph.names.firstIndex(of: "echo"), "echoes have their own mark")
    }

    func testEveryGlyphFillsItsGridAndDrawsSomething() {
        for name in LegacyGlyph.names {
            let box = bounds(of: name)
            XCTAssertFalse(LegacyGlyph.pieces(named: name).isEmpty, name)
            XCTAssertGreaterThanOrEqual(box.minX, -0.5, name)
            XCTAssertGreaterThanOrEqual(box.minY, -0.5, name)
            XCTAssertLessThanOrEqual(box.maxX, 24.5, "\(name) runs off the grid")
            XCTAssertLessThanOrEqual(box.maxY, 24.5, "\(name) runs off the grid")
            // Readable at 20 points: it must use most of its 24-unit square.
            XCTAssertGreaterThanOrEqual(max(box.width, box.height), 18, "\(name) is too small to read")
            XCTAssertGreaterThanOrEqual(min(box.width, box.height), 10, "\(name) is too thin to read")
            XCTAssertTrue(LegacyGlyph.pieces(named: name).contains { $0.style == .fill }, "\(name) has no body")
        }
    }
}
