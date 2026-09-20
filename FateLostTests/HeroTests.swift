import XCTest
@testable import FateLost

/// The hero is a choice of looks, some of them earned. These tests hold the
/// lines that matter: every combination on offer draws, a saved look can
/// never wear something unpaid for, a purchase costs exactly what it says,
/// and nothing about the hero's save can be lost by adding to it.
final class HeroTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FateLostHero-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Drawing

    func testEveryBuildCloakAndHeadDraws() {
        for build in BodyBuild.allCases {
            for cloak in CloakStyle.allCases {
                for head in HeadStyle.allCases {
                    var look = HeroAppearance()
                    look.build = build
                    look.cloak = cloak
                    look.head = head
                    let sprite = PlaceholderArt.hero(look)
                    XCTAssertEqual(sprite.image.size, PlaceholderArt.heroCanvas,
                                   "\(build) \(cloak) \(head) drew the wrong size")
                }
            }
        }
    }

    func testEveryExtraDrawsOnEveryBuild() {
        for build in BodyBuild.allCases {
            for emblem in EmblemStyle.allCases {
                for detail in MetalDetail.allCases {
                    for wings in WingStyle.allCases {
                        var look = HeroAppearance()
                        look.build = build
                        look.emblem = emblem
                        look.detail = detail
                        look.wings = wings
                        XCTAssertEqual(PlaceholderArt.hero(look).image.size, PlaceholderArt.heroCanvas,
                                       "\(build) \(emblem) \(detail) \(wings)")
                    }
                }
            }
        }
    }

    func testThePlayerSpriteIsTheStandardHero() {
        let stock = PlaceholderArt.sprite(for: .playerAdventurer)
        XCTAssertNotNil(stock)
        XCTAssertEqual(stock?.image.size, PlaceholderArt.heroCanvas)
    }

    func testThePortraitIsRedrawnAtTheScaleAsked() {
        let portrait = PlaceholderArt.heroPortrait(.standard, scale: 6)
        XCTAssertEqual(portrait.scale, 6)
        XCTAssertEqual(portrait.size, PlaceholderArt.heroCanvas)
    }

    func testEveryBuildHoldsTheWeaponAtItsOwnHand() {
        let hands = BodyBuild.allCases.map(\.hand)
        XCTAssertEqual(Set(hands.map { "\($0.x),\($0.y)" }).count, hands.count, "two builds share a hand")
        XCTAssertLessThan(BodyBuild.lithe.hand.x, BodyBuild.broad.hand.x)
    }

    // MARK: The palette

    func testEveryPaletteHasUniqueIDsAndOpensWithAFreeColour() {
        let lists: [(String, [HeroSwatch], (String) -> HeroOption?)] = [
            ("cloak", HeroPalette.cloak, { .cloakColor($0) }),
            ("trim", HeroPalette.trim, { .trimColor($0) }),
            ("eyes", HeroPalette.eyes, { .eyeColor($0) }),
            ("skin", HeroPalette.skin, { _ in nil }),
            ("hair", HeroPalette.hair, { _ in nil }),
        ]
        for (name, list, option) in lists {
            XCTAssertEqual(Set(list.map(\.id)).count, list.count, "\(name) has a repeated id")
            if let first = option(list[0].id) {
                XCTAssertTrue(HeroUnlocks.isFree(first), "\(name) opens with a locked colour")
            }
        }
    }

    func testAnUnknownColourFallsBackToTheFirst() {
        XCTAssertEqual(HeroPalette.swatch("no-such-dye", in: HeroPalette.cloak), HeroPalette.cloak[0])
    }

    // MARK: Saving

    func testALookRoundTrips() throws {
        var look = HeroAppearance()
        look.build = .broad
        look.cloak = .shroud
        look.head = .helm
        look.cloakColor = "violet"
        look.eyeColor = "jade"
        let restored = try JSONDecoder().decode(HeroAppearance.self, from: JSONEncoder().encode(look))
        XCTAssertEqual(restored, look)
    }

    func testAnEmptyOrPartialSaveStillLoads() throws {
        XCTAssertEqual(try JSONDecoder().decode(HeroAppearance.self, from: Data("{}".utf8)), .standard)
        let partial = try JSONDecoder().decode(HeroAppearance.self, from: Data(#"{"cloak": "pilgrim"}"#.utf8))
        XCTAssertEqual(partial.cloak, .pilgrim)
        XCTAssertEqual(partial.build, .standard)
    }

    func testAnOptionThatNoLongerExistsFallsBackInsteadOfLosingTheSave() throws {
        let stale = #"{"build": "gigantic", "cloak": "cape-of-the-future", "cloakColor": "violet"}"#
        let look = try JSONDecoder().decode(HeroAppearance.self, from: Data(stale.utf8))
        XCTAssertEqual(look.build, .standard)
        XCTAssertEqual(look.cloak, .hooded)
        XCTAssertEqual(look.cloakColor, "violet", "a good field was lost with a bad one")
    }

    func testTheStoreKeepsALookAndForgetsItOnErase() {
        let url = directory.appendingPathComponent("hero.json")
        let store = HeroStore(fileURL: url)
        XCTAssertEqual(store.load(), .standard)
        var look = HeroAppearance()
        look.head = .cowl
        XCTAssertTrue(store.save(look))
        XCTAssertEqual(HeroStore(fileURL: url).load(), look)

        store.erase()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(store.load(), .standard)
    }

    func testEraseAlsoClearsCopiesMovedAsideAsCorrupt() throws {
        let url = directory.appendingPathComponent("hero.json")
        try Data("this is not json".utf8).write(to: url)
        let store = HeroStore(fileURL: url)
        _ = store.load() // moves the bad file aside
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(before.contains { $0.hasPrefix("hero.corrupt-") }, "expected a moved-aside copy: \(before)")

        store.erase()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }

    func testEraseLeavesOtherSavesAlone() throws {
        let hero = HeroStore(fileURL: directory.appendingPathComponent("hero.json"))
        let other = directory.appendingPathComponent("legacy.json")
        try Data("{}".utf8).write(to: other)
        XCTAssertTrue(hero.save(.standard))
        hero.erase()
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
    }

    // MARK: What costs what

    func testTheStandardLookIsEntirelyFree() {
        for option in HeroUnlocks.options(of: .standard) {
            XCTAssertTrue(HeroUnlocks.isFree(option), "\(option.id) is locked in the starting look")
        }
        for build in HeroUnlocks.builds {
            XCTAssertTrue(HeroUnlocks.isFree(build), "a body should never cost anything")
        }
    }

    func testTheDistinctiveOptionsAreThePricedOnes() {
        for option in [HeroOption.cloak(.vampire), .head(.skull), .wings(.angel), .emblem(.dragon), .detail(.warPlate)] {
            XCTAssertTrue(HeroUnlocks.priced.contains(option), "\(option.id) should cost something")
        }
        for option in HeroUnlocks.priced {
            XCTAssertGreaterThan(HeroUnlocks.cost(of: option), 0)
        }
        // Enough is free that nobody has to buy anything to make a character.
        XCTAssertGreaterThanOrEqual(HeroUnlocks.cloaks.filter(HeroUnlocks.isFree).count, 3)
        XCTAssertGreaterThanOrEqual(HeroUnlocks.heads.filter(HeroUnlocks.isFree).count, 2)
    }

    func testCoolerCostsMore() {
        let angel = HeroUnlocks.cost(of: .wings(.angel))
        XCTAssertEqual(angel, 500)
        XCTAssertEqual(HeroUnlocks.cost(of: .wings(.demon)), 500)
        // Wings are the aspiration: dearer than any cloak, head, emblem or metalwork.
        for option in HeroUnlocks.cloaks + HeroUnlocks.heads + HeroUnlocks.emblems + HeroUnlocks.details {
            XCTAssertLessThan(HeroUnlocks.cost(of: option), angel, "\(option.id) costs as much as wings")
        }
        // A colour is small change beside a whole outfit.
        let dearestColour = (HeroUnlocks.cloakColours + HeroUnlocks.trimColours + HeroUnlocks.eyeColours)
            .map(HeroUnlocks.cost).max() ?? 0
        let cheapestStyle = (HeroUnlocks.cloaks + HeroUnlocks.heads + HeroUnlocks.emblems + HeroUnlocks.details)
            .filter { !HeroUnlocks.isFree($0) }.map(HeroUnlocks.cost).min() ?? 0
        XCTAssertLessThan(dearestColour, cheapestStyle)
        XCTAssertLessThan(HeroUnlocks.cost(of: .emblem(.skulls)), HeroUnlocks.cost(of: .emblem(.dragon)))
        XCTAssertLessThan(HeroUnlocks.cost(of: .detail(.studs)), HeroUnlocks.cost(of: .detail(.warPlate)))
    }

    func testEveryStyleAndColourThePlayerAskedForExists() {
        let cloaks: Set<CloakStyle> = [.vampire, .wizard, .ninja, .samurai, .druid, .paladin]
        XCTAssertTrue(cloaks.isSubset(of: Set(CloakStyle.allCases)))
        XCTAssertTrue(HeadStyle.allCases.contains(.eyeless), "the eyeless hood is missing")
        XCTAssertGreaterThanOrEqual(BodyBuild.allCases.count, 5)
        XCTAssertTrue(HeroPalette.trim.contains { $0.id == "black" }, "black trim is missing")
        XCTAssertEqual(EmblemStyle.allCases.count, 6)
        XCTAssertTrue(WingStyle.allCases.contains(.angel) && WingStyle.allCases.contains(.demon))
    }

    func testEveryPricedColourIsARealColour() {
        // A typo in a price table would quietly make a colour free.
        XCTAssertEqual(HeroUnlocks.cloakColours.filter { !HeroUnlocks.isFree($0) }.count, 11)
        XCTAssertEqual(HeroUnlocks.trimColours.filter { !HeroUnlocks.isFree($0) }.count, 9)
        XCTAssertEqual(HeroUnlocks.eyeColours.filter { !HeroUnlocks.isFree($0) }.count, 7)
    }

    func testAnOldHeroSaveWithoutExtrasStillLoadsPlain() throws {
        let old = #"{"build": "broad", "cloak": "pilgrim", "head": "cowl", "cloakColor": "violet"}"#
        let look = try JSONDecoder().decode(HeroAppearance.self, from: Data(old.utf8))
        XCTAssertEqual(look.build, .broad)
        XCTAssertEqual(look.emblem, .plain)
        XCTAssertEqual(look.detail, .plain)
        XCTAssertEqual(look.wings, .plain)
    }

    func testExtrasAreCutBackToWhatIsOwned() {
        var look = HeroAppearance()
        look.wings = .demon
        look.emblem = .dragon
        look.detail = .warPlate
        let restricted = look.restricted(to: { HeroUnlocks.isFree($0) })
        XCTAssertEqual(restricted.wings, .plain)
        XCTAssertEqual(restricted.emblem, .plain)
        XCTAssertEqual(restricted.detail, .plain)
        var owned = Set([HeroOption.wings(.demon).id])
        owned.insert(HeroOption.emblem(.dragon).id)
        let partly = look.restricted(to: { HeroUnlocks.isFree($0) || owned.contains($0.id) })
        XCTAssertEqual(partly.wings, .demon)
        XCTAssertEqual(partly.emblem, .dragon)
        XCTAssertEqual(partly.detail, .plain)
    }

    func testGrantingEchoesAddsThemAndNeverTakesAny() {
        var profile = LegacyProfile()
        profile.grant(echoes: 500)
        profile.grant(echoes: 1_000)
        profile.grant(echoes: -300)
        XCTAssertEqual(profile.echoes, 1_500)
        XCTAssertTrue(profile.buy(.wings(.angel)))
        XCTAssertEqual(profile.echoes, 1_000)
    }

    func testOptionIDsAreUnique() {
        let all = HeroUnlocks.all
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "two options share a save key")
    }

    func testAnOptionAppliesToALookAndIsRecognisedAsWorn() {
        let option = HeroOption.cloakColor("teal")
        let worn = option.applying(to: .standard)
        XCTAssertEqual(worn.cloakColor, "teal")
        XCTAssertTrue(option.isWorn(by: worn))
        XCTAssertFalse(option.isWorn(by: .standard))
    }

    // MARK: Buying

    func testBuyingTakesTheEchoesAndKeepsTheLook() {
        var profile = LegacyProfile()
        profile.echoes = 200
        let option = HeroOption.cloak(.shroud)
        XCTAssertFalse(profile.owns(option))
        XCTAssertTrue(profile.buy(option))
        XCTAssertEqual(profile.echoes, 200 - HeroUnlocks.cost(of: option))
        XCTAssertEqual(profile.spent, HeroUnlocks.cost(of: option))
        XCTAssertTrue(profile.owns(option))
    }

    func testABrokeHeroCannotBuyAndNothingChanges() {
        var profile = LegacyProfile()
        profile.echoes = 10
        let before = profile
        XCTAssertFalse(profile.buy(.head(.helm)))
        XCTAssertEqual(profile, before)
        XCTAssertNotNil(profile.denial(for: .head(.helm)))
    }

    func testAnOptionIsNotBoughtTwiceOrFreeOnesAtAll() {
        var profile = LegacyProfile()
        profile.echoes = 500
        XCTAssertTrue(profile.buy(.cloak(.pilgrim)))
        let after = profile.echoes
        XCTAssertFalse(profile.buy(.cloak(.pilgrim)))
        XCTAssertFalse(profile.buy(.cloak(.mantle)), "a free option was charged for")
        XCTAssertEqual(profile.echoes, after)
    }

    func testAProfileWithoutAWardrobeStillLoads() throws {
        let old = #"{"echoes": 300, "spent": 100, "unlocked": [], "weapons": []}"#
        let profile = try JSONDecoder().decode(LegacyProfile.self, from: Data(old.utf8))
        XCTAssertEqual(profile.echoes, 300)
        XCTAssertTrue(profile.cosmetics.isEmpty)
    }

    func testPurchasesSurviveASaveAndLoad() throws {
        var profile = LegacyProfile()
        profile.echoes = 300
        profile.buy(.eyeColor("ember"))
        let restored = try JSONDecoder().decode(LegacyProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertTrue(restored.owns(.eyeColor("ember")))
    }

    // MARK: Wearing only what is owned

    func testALookIsCutBackToWhatIsOwned() {
        var look = HeroAppearance()
        look.cloak = .shroud
        look.head = .helm
        look.cloakColor = "violet"
        look.build = .broad
        let restricted = look.restricted(to: { HeroUnlocks.isFree($0) })
        XCTAssertEqual(restricted.cloak, .hooded)
        XCTAssertEqual(restricted.head, .hood)
        XCTAssertEqual(restricted.cloakColor, HeroPalette.cloak[0].id)
        XCTAssertEqual(restricted.build, .broad, "a body was taken away")
    }

    func testAnOwnedLookIsLeftAlone() {
        var look = HeroAppearance()
        look.cloak = .shroud
        look.trimColor = "gold"
        XCTAssertEqual(look.restricted(to: { _ in true }), look)
    }

    func testRandomNeverWearsWhatIsNotOwned() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<300 {
            let look = HeroAppearance.random(using: &generator, owns: { HeroUnlocks.isFree($0) })
            for option in HeroUnlocks.options(of: look) {
                XCTAssertTrue(HeroUnlocks.isFree(option), "random wore \(option.id)")
            }
        }
    }

    func testRandomCanUseEverythingOnceOwned() {
        var generator = SystemRandomNumberGenerator()
        var seenPriced = false
        for _ in 0..<400 {
            let look = HeroAppearance.random(using: &generator, owns: { _ in true })
            if HeroUnlocks.options(of: look).contains(where: { !HeroUnlocks.isFree($0) }) {
                seenPriced = true
            }
        }
        XCTAssertTrue(seenPriced)
    }
}

/// Developer mode, and the way back to a fresh install.
final class DeveloperAndResetTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FateLostReset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testTheDeveloperCodeIsExact() {
        XCTAssertTrue(DeveloperOptions.accepts("GreenLantern"))
        XCTAssertTrue(DeveloperOptions.accepts("  GreenLantern\n"), "stray spaces should not matter")
        XCTAssertFalse(DeveloperOptions.accepts("greenlantern"))
        XCTAssertFalse(DeveloperOptions.accepts("Green Lantern"))
        XCTAssertFalse(DeveloperOptions.accepts(""))
    }

    func testDeveloperModeStartsLockedAndOldSettingsStayLocked() throws {
        XCTAssertFalse(GameSettings.defaults.developerUnlocked)
        let old = #"{"masterVolume": 0.4, "hapticsEnabled": false}"#
        let settings = try JSONDecoder().decode(GameSettings.self, from: Data(old.utf8))
        XCTAssertFalse(settings.developerUnlocked)
        XCTAssertEqual(settings.masterVolume, 0.4)
    }

    func testLockingClearsEveryCheat() {
        let developer = DeveloperOptions()
        developer.godMode = true
        developer.gameSpeed = 4
        developer.unlockAllRealms = true
        developer.disableLegacyBonuses = true
        developer.spawningEnabled = false
        developer.showHitboxes = true
        developer.send(.grantLevels(5))
        developer.reset()

        XCTAssertFalse(developer.godMode)
        XCTAssertEqual(developer.gameSpeed, 1)
        XCTAssertFalse(developer.unlockAllRealms)
        XCTAssertFalse(developer.disableLegacyBonuses)
        XCTAssertTrue(developer.spawningEnabled)
        XCTAssertFalse(developer.showHitboxes)
        XCTAssertTrue(developer.takeCommands().isEmpty)
    }

    func testResettingSettingsDeletesTheFileAndRestoresDefaults() {
        let store = SettingsStore(directory: directory)
        store.update {
            $0.masterVolume = 0.1
            $0.developerUnlocked = true
        }
        let file = directory.appendingPathComponent("settings.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        store.reset()
        XCTAssertEqual(store.settings, .defaults)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(SettingsStore(directory: directory).settings, .defaults)
    }

    func testErasingTheLegacySaveStartsAFreshProfile() {
        let url = directory.appendingPathComponent("legacy.json")
        let store = LegacyStore(fileURL: url)
        var profile = LegacyProfile()
        profile.echoes = 999
        profile.buy(.cloak(.shroud))
        XCTAssertTrue(store.save(profile))
        XCTAssertEqual(store.load().echoes, 999 - HeroUnlocks.cost(of: .cloak(.shroud)))

        store.erase()
        XCTAssertEqual(store.load(), LegacyProfile())
    }
}
