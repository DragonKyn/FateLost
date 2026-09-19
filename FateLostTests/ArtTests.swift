import XCTest
@testable import FateLost

/// Art is data: every sprite the game asks for must resolve to something, or
/// it shows up in play as a magenta square.
@MainActor
final class ArtTests: XCTestCase {
    func testEveryGameplaySpriteHasArt() {
        for id in SpriteCatalog.gameplaySprites {
            XCTAssertNotNil(PlaceholderArt.sprite(for: id), "no art for \(id.rawValue)")
        }
    }

    func testSummonSpritesArePreloaded() {
        let preloaded = Set(SpriteCatalog.gameplaySprites)
        for summon in SummonCatalog.all {
            XCTAssertTrue(preloaded.contains(summon.sprite), "\(summon.key) uses an unloaded sprite")
            for variant in summon.variants {
                XCTAssertTrue(preloaded.contains(variant), "\(summon.key) variant \(variant.rawValue) is not loaded")
            }
        }
        for form in FormCatalog.all {
            XCTAssertTrue(preloaded.contains(form.sprite), "\(form.id) uses an unloaded sprite")
        }
    }

    func testSummonVariantsCycleByAllyID() {
        var spec = SummonCatalog.skeleton
        XCTAssertEqual(spec.sprite(forAlly: 0), spec.variants[0])
        XCTAssertEqual(spec.sprite(forAlly: spec.variants.count), spec.variants[0])
        XCTAssertEqual(spec.sprite(forAlly: 1), spec.variants[1])
        spec.variants = []
        XCTAssertEqual(spec.sprite(forAlly: 7), spec.sprite)
    }
}
