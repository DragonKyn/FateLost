import XCTest
@testable import FateLost

/// The six restylable companions: the druid's two forms, and four standout
/// summons. Colour and size are one purchase per target; the extra prop is
/// its own. These hold the same guarantees the hero's own wardrobe does.
final class CompanionAppearanceTests: XCTestCase {
    // MARK: Pricing

    func testEveryCustomizeAndExtraCostsSomething() {
        for option in CompanionUnlocks.priced {
            XCTAssertGreaterThan(CompanionUnlocks.cost(of: option), 0, option.id)
        }
        XCTAssertEqual(CompanionUnlocks.cost(of: .extra(.bearForm, .none)), 0, "no extra is always free")
    }

    func testHeavierCompanionsCostMoreToRestyle() {
        let colossus = CompanionUnlocks.cost(of: .customize(.boneColossus))
        let skeleton = CompanionUnlocks.cost(of: .customize(.skeleton))
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

    // MARK: The look

    func testAFreshLookKeepsWhateverTheCatalogueAlreadyGives() {
        let look = CompanionLook()
        XCTAssertNil(look.tint)
        XCTAssertEqual(look.scale, .standard)
        XCTAssertEqual(look.extra, .none)
    }

    func testCustomizationRoundTripsThroughJSON() throws {
        var custom = CompanionCustomization()
        custom[.hellhound] = CompanionLook(tint: "ember", scale: .massive, extra: .banner)
        let restored = try JSONDecoder().decode(CompanionCustomization.self, from: JSONEncoder().encode(custom))
        XCTAssertEqual(restored[.hellhound], custom[.hellhound])
        XCTAssertEqual(restored[.fiend], CompanionLook(), "an untouched target still reads as the default")
    }

    func testGarbageJSONFallsBackToEmpty() throws {
        let custom = try JSONDecoder().decode(CompanionCustomization.self, from: Data("\"not a dictionary\"".utf8))
        XCTAssertEqual(custom, CompanionCustomization())
    }

    // MARK: Restriction

    func testUnownedChoicesFallBackOnRestriction() {
        var custom = CompanionCustomization()
        custom[.bearForm] = CompanionLook(tint: "ember", scale: .massive, extra: .charm)
        let restricted = custom.restricted(to: { _ in false })
        let look = restricted[.bearForm]
        XCTAssertNil(look.tint)
        XCTAssertEqual(look.scale, .standard)
        XCTAssertEqual(look.extra, .none)
    }

    func testOwnedChoicesSurviveRestriction() {
        var custom = CompanionCustomization()
        custom[.wolfForm] = CompanionLook(tint: "sapphire", scale: .runt, extra: .banner)
        let owned: Set<String> = [CompanionOption.customize(.wolfForm).id, CompanionOption.extra(.wolfForm, .banner).id]
        let restricted = custom.restricted(to: { owned.contains($0.id) })
        XCTAssertEqual(restricted[.wolfForm], custom[.wolfForm])
    }

    func testAnExtraAloneDoesNotNeedTheColourUnlock() {
        var custom = CompanionCustomization()
        custom[.skeleton] = CompanionLook(tint: "gold", scale: .massive, extra: .charm)
        let owned: Set<String> = [CompanionOption.extra(.skeleton, .charm).id]
        let restricted = custom.restricted(to: { owned.contains($0.id) })
        let look = restricted[.skeleton]
        XCTAssertNil(look.tint, "colour needs its own unlock")
        XCTAssertEqual(look.scale, .standard)
        XCTAssertEqual(look.extra, .charm, "the extra was bought on its own")
    }

    // MARK: Applying to a form

    func testARestyledDruidFormCarriesTheChosenColourAndSize() {
        var custom = CompanionCustomization()
        custom[.bearForm] = CompanionLook(tint: "sapphire", scale: .massive)
        let form = FormCatalog.bear.customized(with: custom)
        XCTAssertEqual(form.tint, RGBA(hex: HeroPalette.swatch("sapphire", in: HeroPalette.trim).hex))
        XCTAssertEqual(Double(form.scale), Double(FormCatalog.bear.scale) * CompanionScale.massive.multiplier,
                       accuracy: 0.001)
    }

    func testAFormWithNoChosenColourKeepsTheCatalogueOne() {
        let form = FormCatalog.wolf.customized(with: CompanionCustomization())
        XCTAssertEqual(form.tint, FormCatalog.wolf.tint)
        XCTAssertEqual(form.scale, FormCatalog.wolf.scale)
    }

    func testIronFistHasNoCompanionTargetAndIsNeverRestyled() {
        XCTAssertNil(CompanionTarget(formID: FormCatalog.ironFist.id))
        var custom = CompanionCustomization()
        custom[.bearForm] = CompanionLook(tint: "gold", scale: .massive)
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

    func testBuyingACustomizationTakesTheEchoesAndKeepsIt() {
        var profile = LegacyProfile()
        profile.echoes = 1_000
        let option = CompanionOption.customize(.hellhound)
        XCTAssertFalse(profile.owns(option))
        XCTAssertTrue(profile.buy(option))
        XCTAssertEqual(profile.echoes, 1_000 - CompanionUnlocks.cost(of: option))
        XCTAssertTrue(profile.owns(option))
        XCTAssertFalse(profile.buy(option), "already owned")
    }

    func testABrokeProfileCannotBuyACompanionRestyle() {
        var profile = LegacyProfile()
        profile.echoes = 1
        let option = CompanionOption.customize(.boneColossus)
        XCTAssertFalse(profile.buy(option))
        XCTAssertNotNil(profile.denial(for: option))
        XCTAssertEqual(profile.echoes, 1)
    }
}
