import XCTest
@testable import FateLost

/// Relics are found mid-run and change how it plays, so the risk is not that
/// one is dull but that one is required. These tests hold the catalogue
/// honest: every relic is whole, none outgrows its rarity, and the way they
/// are dealt is reproducible and never offers something that can do nothing.
final class RelicTests: XCTestCase {
    // MARK: The catalogue

    func testTheCatalogueIsWholeAndUnique() {
        var ids = Set<RelicID>()
        for relic in RelicCatalog.all {
            XCTAssertFalse(ids.contains(relic.id), "two relics share the id \(relic.id)")
            ids.insert(relic.id)
            XCTAssertFalse(relic.name.isEmpty, "\(relic.id) has no name")
            XCTAssertFalse(relic.symbol.isEmpty, "\(relic.id) has no symbol")
            XCTAssertFalse(relic.effects.isEmpty, "\(relic.id) does nothing")
            XCTAssertTrue((1...3).contains(relic.maxRank), "\(relic.id) has a strange rank limit")
        }
        XCTAssertGreaterThanOrEqual(RelicCatalog.all.count, 60)
    }

    func testEveryRarityHasRelicsToDeal() {
        let minimum: [ItemRarity: Int] = [.common: 12, .uncommon: 12, .rare: 10, .epic: 6, .legendary: 3]
        for (rarity, wanted) in minimum {
            XCTAssertGreaterThanOrEqual(RelicCatalog.relics(of: rarity).count, wanted,
                                        "too few \(rarity.displayName) relics")
        }
    }

    func testRelicTextResolvesAtEveryRank() {
        for relic in RelicCatalog.all {
            for rank in 1...relic.maxRank {
                let text = relic.description(atRank: rank)
                XCTAssertFalse(text.contains("{"), "\(relic.id) rank \(rank) left a placeholder: \(text)")
            }
            for index in relic.values.indices {
                XCTAssertTrue(relic.text.contains("{\(index)"),
                              "\(relic.id) supplies value \(index) but never shows it")
            }
        }
    }

    func testRelicsNeverGrantAbilitiesOrForms() {
        for relic in RelicCatalog.all {
            for effect in relic.effects {
                switch effect {
                case .ability, .permanentForm:
                    XCTFail("\(relic.id) grants a slot the tree screen owns")
                default:
                    break
                }
            }
        }
    }

    func testNoRelicOutgrowsItsRarity() {
        let ceiling: [ItemRarity: Double] = [.common: 0.25, .uncommon: 0.30, .rare: 0.40, .epic: 0.50,
                                             .legendary: 0.60]
        for relic in RelicCatalog.all {
            let limit = ceiling[relic.rarity] ?? 0.2
            for effect in relic.effects {
                let specs: [ModifierSpec]
                switch effect {
                case .stat(let spec): specs = [spec]
                case .statWhile(_, let spec): specs = [spec]
                default: specs = []
                }
                for spec in specs where spec.stat != .pickupRadius {
                    let value = spec.value.at(relic.maxRank)
                    switch spec.kind {
                    case .increased, .more:
                        XCTAssertLessThanOrEqual(value, limit,
                                                 "\(relic.id) grants \(value) of a multiplier at max rank")
                    case .flat:
                        switch spec.stat {
                        case .critChance: XCTAssertLessThanOrEqual(value, 0.12, "\(relic.id) crit chance")
                        case .lifeSteal: XCTAssertLessThanOrEqual(value, 0.05, "\(relic.id) life steal")
                        case .spellEcho: XCTAssertLessThanOrEqual(value, 0.2, "\(relic.id) spell echo")
                        case .cooldownReduction: XCTAssertLessThanOrEqual(value, 0.15, "\(relic.id) cooldowns")
                        case .dodgeChance: XCTAssertLessThanOrEqual(value, 0.12, "\(relic.id) dodge")
                        default: break
                        }
                    }
                }
            }
        }
    }

    // MARK: Carrying them

    func testFindingARelicTwiceRaisesItAndStopsAtItsLimit() {
        var pack = RelicInventory()
        let whetstone = CommonRelics.whetstone
        XCTAssertEqual(pack.add(whetstone.id), 1)
        XCTAssertEqual(pack.add(whetstone.id), 2)
        XCTAssertEqual(pack.add(whetstone.id), 3)
        XCTAssertEqual(pack.add(whetstone.id), 3, "a relic rose past its limit")
        XCTAssertEqual(pack.count, 1, "the same relic took a second place in the pack")
        XCTAssertFalse(pack.canImprove(whetstone))
    }

    func testARolledRankStartsHigher() {
        var pack = RelicInventory()
        XCTAssertEqual(pack.add(CommonRelics.whetstone.id, rank: 2), 2)
        XCTAssertEqual(pack.add(CommonRelics.whetstone.id, rank: 2), 3, "rank must stop at the limit")
    }

    func testAnUnknownRelicIsRefused() {
        var pack = RelicInventory()
        XCTAssertEqual(pack.add("relic.doesNotExist"), 0)
        XCTAssertTrue(pack.isEmpty)
    }

    func testThePackKeepsTheOrderThingsWereFound() {
        var pack = RelicInventory()
        pack.add(CommonRelics.ironRing.id)
        pack.add(CommonRelics.whetstone.id)
        pack.add(CommonRelics.ironRing.id)
        XCTAssertEqual(pack.held.map(\.relic.id), [CommonRelics.ironRing.id, CommonRelics.whetstone.id])
    }

    // MARK: Compiling

    func testARelicBecomesPartOfTheBuild() {
        var pack = RelicInventory()
        pack.add(CommonRelics.whetstone.id, rank: 2)
        let build = CompiledBuild.compile(SkillAllocation(), relics: pack)
        let damage = build.modifiers.first { $0.stat == .damage && $0.kind == .increased }
        XCTAssertEqual(damage?.value ?? 0, 0.10, accuracy: 0.0001, "rank two should read 6% + 4%")
    }

    func testRankScalesWhatARelicDoes() {
        var low = RelicInventory()
        low.add(CommonRelics.whetstone.id)
        var high = RelicInventory()
        high.add(CommonRelics.whetstone.id, rank: 3)
        let one = CompiledBuild.compile(SkillAllocation(), relics: low).modifiers.first { $0.stat == .damage }
        let three = CompiledBuild.compile(SkillAllocation(), relics: high).modifiers.first { $0.stat == .damage }
        XCTAssertGreaterThan(three?.value ?? 0, one?.value ?? 0)
    }

    func testRelicsCanCarryBehaviourNotJustNumbers() {
        var pack = RelicInventory()
        pack.add(UncommonRelics.thornmail.id)
        pack.add(EpicRelics.phoenixFeather.id)
        pack.add(RareRelics.houndsWhistle.id)
        let build = CompiledBuild.compile(SkillAllocation(), relics: pack)
        XCTAssertFalse(build.hurtProcs.isEmpty, "thornmail should fire when the player is struck")
        XCTAssertNotNil(build.cheatDeath, "the feather should refuse a killing blow")
        XCTAssertEqual(build.companions.first?.count, 1)
    }

    func testCarryingNothingChangesNothing() {
        let plain = CompiledBuild.compile(SkillAllocation())
        let empty = CompiledBuild.compile(SkillAllocation(), relics: RelicInventory())
        XCTAssertEqual(plain.modifiers, empty.modifiers)
        XCTAssertEqual(plain.procs.count, empty.procs.count)
    }

    // MARK: Dealing

    func testAnOfferHoldsThreeDistinctRelics() {
        var random = SeededRandom(seed: 4)
        let offer = RelicRoller.offer(tier: .chest, wave: 5, inventory: RelicInventory(), random: &random)
        XCTAssertEqual(offer.choices.count, RelicRoller.choiceCount)
        XCTAssertEqual(Set(offer.choices.map(\.relic)).count, offer.choices.count, "a relic was dealt twice")
        XCTAssertEqual(offer.rerollsLeft, RelicRoller.rerolls)
    }

    func testTheSameSeedDealsTheSameCards() {
        var first = SeededRandom(seed: 99)
        var second = SeededRandom(seed: 99)
        let a = RelicRoller.offer(tier: .hoard, wave: 12, inventory: RelicInventory(), random: &first)
        let b = RelicRoller.offer(tier: .hoard, wave: 12, inventory: RelicInventory(), random: &second)
        XCTAssertEqual(a, b)
    }

    func testTiersOnlyDealWhatTheyAreFor() {
        var random = SeededRandom(seed: 21)
        for _ in 0..<300 {
            let cache = RelicRoller.offer(tier: .cache, wave: 3, inventory: RelicInventory(), random: &random)
            for choice in cache.choices {
                let rarity = RelicCatalog.relic(choice.relic)?.rarity
                XCTAssertTrue(rarity == .common || rarity == .uncommon || rarity == .rare,
                              "a cache held a \(String(describing: rarity)) relic")
            }
            let hoard = RelicRoller.offer(tier: .hoard, wave: 15, inventory: RelicInventory(), random: &random)
            for choice in hoard.choices {
                XCTAssertNotEqual(RelicCatalog.relic(choice.relic)?.rarity, .common, "a hoard held a common relic")
            }
        }
    }

    func testARelicAtItsLimitIsNeverOffered() {
        var pack = RelicInventory()
        for relic in CommonRelics.all {
            pack.add(relic.id, rank: 3)
        }
        var random = SeededRandom(seed: 8)
        for _ in 0..<100 {
            let offer = RelicRoller.offer(tier: .cache, wave: 4, inventory: pack, random: &random)
            for choice in offer.choices {
                XCTAssertTrue(pack.canImprove(RelicCatalog.relic(choice.relic)!),
                              "\(choice.relic) is at its limit and can do nothing more")
            }
        }
    }

    func testARolledRankNeverPassesTheRelicsLimit() {
        var random = SeededRandom(seed: 5)
        for _ in 0..<400 {
            let offer = RelicRoller.offer(tier: .hoard, wave: 30, inventory: RelicInventory(), random: &random)
            for choice in offer.choices {
                let relic = RelicCatalog.relic(choice.relic)!
                XCTAssertLessThanOrEqual(choice.rank, relic.maxRank)
                XCTAssertGreaterThanOrEqual(choice.rank, 1)
            }
        }
    }

    func testStrongRollsGetMoreLikelyAndRankThreeWaitsForALateRun() {
        let early = RelicRoller.rankChances(atWave: 1)
        let late = RelicRoller.rankChances(atWave: 20)
        XCTAssertGreaterThan(late.second, early.second)
        XCTAssertEqual(early.third, 0)
        XCTAssertEqual(RelicRoller.rankChances(atWave: 9).third, 0)
        XCTAssertGreaterThan(late.third, 0)
        XCTAssertLessThanOrEqual(late.second, 0.30)
        XCTAssertLessThanOrEqual(late.third, 0.08)
    }

    func testARerollDealsAgainOnceAndOnlyOnce() {
        var random = SeededRandom(seed: 13)
        var offer = RelicRoller.offer(tier: .chest, wave: 6, inventory: RelicInventory(), random: &random)
        let before = offer.choices
        XCTAssertTrue(RelicRoller.reroll(&offer, inventory: RelicInventory(), random: &random))
        XCTAssertEqual(offer.rerollsLeft, 0)
        XCTAssertEqual(offer.choices.count, RelicRoller.choiceCount)
        XCTAssertNotEqual(offer.choices, before, "a reroll dealt the same cards")

        let held = offer.choices
        XCTAssertFalse(RelicRoller.reroll(&offer, inventory: RelicInventory(), random: &random))
        XCTAssertEqual(offer.choices, held, "a refused reroll changed the cards")
    }

    // MARK: In a run

    private func makeSimulation() -> GameSimulation {
        GameSimulation(run: RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 7),
                       tuning: .standard)
    }

    func testChoosingARelicChangesTheHeroAndReportsIt() {
        var simulation = makeSimulation()
        let before = simulation.sheet[.damage]
        simulation.grantRelic(RelicChoice(relic: CommonRelics.whetstone.id, rank: 1))
        XCTAssertEqual(simulation.relics.count, 1)
        XCTAssertGreaterThan(simulation.sheet[.damage], before)
        XCTAssertTrue(simulation.drainEvents().contains {
            if case .relicGained(let id, let rank) = $0 { return id == CommonRelics.whetstone.id && rank == 1 }
            return false
        })
    }

    func testAnOfferHoldsTheGameUntilItIsAnswered() {
        var simulation = makeSimulation()
        XCTAssertNil(simulation.offer)
        XCTAssertTrue(simulation.openOffer(tier: .chest))
        XCTAssertNotNil(simulation.offer)
        XCTAssertFalse(simulation.openOffer(tier: .hoard), "a second find replaced the first")

        XCTAssertFalse(simulation.chooseRelic(at: 9), "an index off the end was accepted")
        XCTAssertNotNil(simulation.offer)
        XCTAssertTrue(simulation.chooseRelic(at: 0))
        XCTAssertNil(simulation.offer)
        XCTAssertEqual(simulation.relics.count, 1)
    }

    func testTheOfferCanBeRerolledFromInsideARun() {
        var simulation = makeSimulation()
        simulation.openOffer(tier: .chest)
        let first = simulation.offer?.choices
        XCTAssertTrue(simulation.rerollOffer())
        XCTAssertNotEqual(simulation.offer?.choices, first)
        XCTAssertFalse(simulation.rerollOffer(), "the reroll is meant to be spent once")
    }

    func testTheSameSeedFindsTheSameRelics() {
        var one = makeSimulation()
        var two = makeSimulation()
        one.openOffer(tier: .chest)
        two.openOffer(tier: .chest)
        XCTAssertEqual(one.offer, two.offer)
    }
}
