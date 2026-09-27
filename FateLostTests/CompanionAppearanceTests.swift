import XCTest
@testable import FateLost

/// The six restylable companions: the druid's two forms, and four standout
/// summons. Every appearance, size and extra is its own purchase — these
/// hold the same guarantees the hero's own wardrobe does.
final class CompanionAppearanceTests: XCTestCase {
    // MARK: Pricing

    func testBaseAppearanceAndStandardSizeAreAlwaysFree() {
        for target in CompanionTarget.allCases {
            XCTAssertTrue(CompanionUnlocks.isFree(.appearance(target, "base")), target.rawValue)
            XCTAssertTrue(CompanionUnlocks.isFree(.scale(target, .standard)), target.rawValue)
            XCTAssertTrue(CompanionUnlocks.isFree(.extra(target, .none)), target.rawValue)
        }
    }

    func testEveryOtherOptionCostsSomething() {
        for option in CompanionUnlocks.priced {
            XCTAssertGreaterThan(CompanionUnlocks.cost(of: option), 0, option.id)
        }
    }

    func testHeavierCompanionsCostMoreToRestyle() {
        let colossus = CompanionUnlocks.cost(of: .appearance(.boneColossus, "ember"))
        let skeleton = CompanionUnlocks.cost(of: .appearance(.skeleton, "ember"))
        XCTAssertGreaterThan(colossus, skeleton, "the colossus is the bigger ask")
    }

    func testEveryOptionIDIsUnique() {
        let all = CompanionUnlocks.all
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "two companion options share a save key")
    }

    func testOptionIDsDoNotCollideWithTheHeroWardrobe() {
        let heroIDs = Set(HeroUnlocks.all.map(\.id))
        let companionIDs = Set(CompanionUnlocks.all.map(\.id))
        XCTAssertTrue(heroIDs.isDisjoint(with: companionIDs), "a companion option reused a hero option's save key")
    }

    // MARK: Appearances

    func testEveryTargetHasABaseAppearanceFirst() {
        for target in CompanionTarget.allCases {
            let options = CompanionAppearanceCatalog.options(for: target)
            XCTAssertEqual(options.first?.id, "base", target.rawValue)
            XCTAssertTrue(options.first?.isBase ?? false, target.rawValue)
            XCTAssertGreaterThanOrEqual(options.count, 3, "\(target.rawValue) should offer real variety")
            XCTAssertEqual(Set(options.map(\.id)).count, options.count, "\(target.rawValue) repeats an appearance id")
        }
    }

    func testFieryTargetsDoNotOfferARedundantEmberVariant() {
        // The hellhound and the pit fiend are already a fire theme; an
        // "ember" recolour of either would be indistinguishable from base.
        for target in [CompanionTarget.hellhound, .fiend] {
            let ids = CompanionAppearanceCatalog.options(for: target).map(\.id)
            XCTAssertFalse(ids.contains("ember"), target.rawValue)
        }
    }

    func testUnknownAppearanceIDFallsBackToBase() {
        let option = CompanionAppearanceCatalog.option("not-a-real-id", for: .skeleton)
        XCTAssertEqual(option.id, "base")
    }

    // MARK: The look

    func testAFreshLookIsTheBaseAppearanceAtStandardSize() {
        let look = CompanionLook()
        XCTAssertNil(look.appearanceID)
        XCTAssertEqual(look.scale, .standard)
        XCTAssertEqual(look.extra, .none)
    }

    func testCustomizationRoundTripsThroughJSON() throws {
        var custom = CompanionCustomization()
        custom[.hellhound] = CompanionLook(appearanceID: "frost", scale: .massive, extra: .banner)
        let restored = try JSONDecoder().decode(CompanionCustomization.self, from: JSONEncoder().encode(custom))
        XCTAssertEqual(restored[.hellhound], custom[.hellhound])
        XCTAssertEqual(restored[.fiend], CompanionLook(), "an untouched target still reads as the default")
    }

    func testGarbageJSONFallsBackToEmpty() throws {
        let custom = try JSONDecoder().decode(CompanionCustomization.self, from: Data("\"not a dictionary\"".utf8))
        XCTAssertEqual(custom, CompanionCustomization())
    }

    // MARK: Wearing, applying and toggling off

    func testApplyingAnOptionWearsExactlyThatOptionAndNothingElse() {
        var look = CompanionLook(appearanceID: "ember", scale: .massive, extra: .banner)
        look = CompanionOption.scale(.skeleton, .runt).applying(to: look)
        XCTAssertEqual(look.scale, .runt)
        XCTAssertEqual(look.appearanceID, "ember", "changing size left the appearance alone")
        XCTAssertEqual(look.extra, .banner, "changing size left the extra alone")
    }

    func testIsWornMatchesTheEquippedOption() {
        let look = CompanionLook(appearanceID: "ember", scale: .massive, extra: .banner)
        XCTAssertTrue(CompanionOption.appearance(.skeleton, "ember").isWorn(by: look))
        XCTAssertTrue(CompanionOption.scale(.skeleton, .massive).isWorn(by: look))
        XCTAssertTrue(CompanionOption.extra(.skeleton, .banner).isWorn(by: look))
        XCTAssertFalse(CompanionOption.appearance(.skeleton, "frost").isWorn(by: look))
    }

    func testBaseAppearanceIsWornWhenNothingIsChosen() {
        XCTAssertTrue(CompanionOption.appearance(.skeleton, "base").isWorn(by: CompanionLook()))
    }

    func testASizeOrExtraHasAFallbackButAnAppearanceDoesNot() {
        XCTAssertNil(CompanionOption.appearance(.skeleton, "ember").fallback)
        XCTAssertEqual(CompanionOption.scale(.skeleton, .massive).fallback, .scale(.skeleton, .standard))
        XCTAssertEqual(CompanionOption.extra(.skeleton, .banner).fallback, .extra(.skeleton, .none))
    }

    // MARK: Restriction

    func testUnownedChoicesFallBackOnRestriction() {
        var custom = CompanionCustomization()
        custom[.bearForm] = CompanionLook(appearanceID: "ember", scale: .massive, extra: .banner)
        let restricted = custom.restricted(to: { _ in false })
        let look = restricted[.bearForm]
        XCTAssertNil(look.appearanceID)
        XCTAssertEqual(look.scale, .standard)
        XCTAssertEqual(look.extra, .none)
    }

    func testOwnedChoicesSurviveRestriction() {
        var custom = CompanionCustomization()
        custom[.wolfForm] = CompanionLook(appearanceID: "frost", scale: .runt, extra: .banner)
        let owned: Set<String> = [
            CompanionOption.appearance(.wolfForm, "frost").id,
            CompanionOption.scale(.wolfForm, .runt).id,
            CompanionOption.extra(.wolfForm, .banner).id,
        ]
        let restricted = custom.restricted(to: { owned.contains($0.id) })
        XCTAssertEqual(restricted[.wolfForm], custom[.wolfForm])
    }

    func testEachAxisIsRestrictedIndependently() {
        var custom = CompanionCustomization()
        custom[.skeleton] = CompanionLook(appearanceID: "ember", scale: .massive, extra: .banner)
        // Only the appearance was bought.
        let owned: Set<String> = [CompanionOption.appearance(.skeleton, "ember").id]
        let restricted = custom.restricted(to: { owned.contains($0.id) })
        let look = restricted[.skeleton]
        XCTAssertEqual(look.appearanceID, "ember", "the bought appearance survives")
        XCTAssertEqual(look.scale, .standard, "the unbought size does not")
        XCTAssertEqual(look.extra, .none, "the unbought extra does not")
    }

    // MARK: Applying to a form

    func testARestyledDruidFormCarriesTheChosenAppearanceAndSize() {
        var custom = CompanionCustomization()
        custom[.bearForm] = CompanionLook(appearanceID: "frost", scale: .massive)
        let form = FormCatalog.bear.customized(with: custom)
        XCTAssertEqual(form.tint, RGBA(hex: HeroPalette.swatch("sapphire", in: HeroPalette.trim).hex))
        XCTAssertEqual(Double(form.scale), Double(FormCatalog.bear.scale) * CompanionScale.massive.multiplier,
                       accuracy: 0.001)
    }

    func testAFormWithNoChosenAppearanceKeepsTheCatalogueOne() {
        let form = FormCatalog.wolf.customized(with: CompanionCustomization())
        XCTAssertEqual(form.tint, FormCatalog.wolf.tint)
        XCTAssertEqual(form.scale, FormCatalog.wolf.scale)
    }

    func testIronFistHasNoCompanionTargetAndIsNeverRestyled() {
        XCTAssertNil(CompanionTarget(formID: FormCatalog.ironFist.id))
        var custom = CompanionCustomization()
        custom[.bearForm] = CompanionLook(appearanceID: "ember", scale: .massive)
        let form = FormCatalog.ironFist.customized(with: custom)
        XCTAssertEqual(form.scale, FormCatalog.ironFist.scale)
        XCTAssertEqual(form.tint, FormCatalog.ironFist.tint)
    }

    func testEverySummonTargetMapsBackFromItsOwnKey() {
        XCTAssertEqual(CompanionTarget(summonKey: SummonCatalog.skeleton.key), .skeleton)
        XCTAssertEqual(CompanionTarget(summonKey: SummonCatalog.boneColossus.key), .boneColossus)
        XCTAssertEqual(CompanionTarget(summonKey: SummonCatalog.hellhound.key), .hellhound)
        XCTAssertEqual(CompanionTarget(summonKey: SummonCatalog.fiend.key), .fiend)
        XCTAssertNil(CompanionTarget(summonKey: SummonCatalog.tiger.key), "the tiger isn't one of the six")
    }

    // MARK: Buying, through the profile

    func testBuyingAnAppearanceTakesTheEchoesAndKeepsIt() {
        var profile = LegacyProfile()
        profile.echoes = 1_000
        let option = CompanionOption.appearance(.hellhound, "frost")
        XCTAssertFalse(profile.owns(option))
        XCTAssertTrue(profile.buy(option))
        XCTAssertEqual(profile.echoes, 1_000 - CompanionUnlocks.cost(of: option))
        XCTAssertTrue(profile.owns(option))
        XCTAssertFalse(profile.buy(option), "already owned")
    }

    func testABrokeProfileCannotBuyACompanionAppearance() {
        var profile = LegacyProfile()
        profile.echoes = 1
        let option = CompanionOption.appearance(.boneColossus, "ember")
        XCTAssertFalse(profile.buy(option))
        XCTAssertNotNil(profile.denial(for: option))
        XCTAssertEqual(profile.echoes, 1)
    }

    func testBuyingOneAppearanceDoesNotUnlockAnother() {
        var profile = LegacyProfile()
        profile.echoes = 1_000
        XCTAssertTrue(profile.buy(.appearance(.skeleton, "ember")))
        XCTAssertFalse(profile.owns(.appearance(.skeleton, "frost")), "buying one appearance bought only that one")
        XCTAssertFalse(profile.owns(.scale(.skeleton, .massive)), "an appearance purchase is not a size purchase")
    }
}
