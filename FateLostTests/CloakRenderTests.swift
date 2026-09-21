import SpriteKit
import XCTest
@testable import FateLost

/// Draws the hero in a real SpriteKit view and looks at the pixels.
///
/// The first attempt at swaying the cloak bent it with SpriteKit's warp grid,
/// and on a device it drew the cloak turned 90 degrees, a fault no unit test of
/// the numbers could see. These tests look at what is actually drawn: the
/// pieces must add up to the whole figure, and a walking hero's cloak must
/// stay recognisably where it is.
@MainActor
final class CloakRenderTests: XCTestCase {
    private struct Picture {
        let width: Int
        let height: Int
        let rgba: [UInt8]

        func alpha(_ x: Int, _ y: Int) -> UInt8 { rgba[(y * width + x) * 4 + 3] }

        /// The box round everything drawn: minX, minY, maxX, maxY.
        var bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
            var box = (minX: width, minY: height, maxX: -1, maxY: -1)
            for y in 0..<height {
                for x in 0..<width where alpha(x, y) > 40 {
                    box.minX = min(box.minX, x)
                    box.maxX = max(box.maxX, x)
                    box.minY = min(box.minY, y)
                    box.maxY = max(box.maxY, y)
                }
            }
            return box.maxX < 0 ? nil : box
        }

        var drawnPixels: Int {
            (0..<(width * height)).reduce(0) { $0 + (rgba[$1 * 4 + 3] > 40 ? 1 : 0) }
        }

        /// How many pixels differ noticeably from the same place in `other`.
        func differences(from other: Picture) -> Int {
            var count = 0
            for index in 0..<(width * height) {
                let base = index * 4
                var sum = 0
                for channel in 0..<4 { sum += abs(Int(rgba[base + channel]) - Int(other.rgba[base + channel])) }
                if sum > 90 { count += 1 }
            }
            return count
        }
    }

    private func picture(of scene: SKScene) throws -> Picture {
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        view.presentScene(scene)
        guard let texture = view.texture(from: scene) else { throw XCTSkip("SpriteKit cannot render offscreen here") }
        let image = texture.cgImage()
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drew: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { throw XCTSkip("no bitmap context") }
        return Picture(width: width, height: height, rgba: bytes)
    }

    private func scene() -> SKScene {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        scene.anchorPoint = .zero
        scene.backgroundColor = .clear
        return scene
    }

    private var paladin: HeroAppearance {
        var look = HeroAppearance()
        look.cloak = .paladin
        look.cloakColor = "royal"
        look.detail = .pauldrons
        look.wings = .angel
        return look
    }

    private func fit(_ node: SKNode, catalog: SpriteCatalog) {
        node.setScale(200 / catalog.size(.playerAdventurer).height)
        node.position = CGPoint(x: 150, y: 40)
    }

    func testThePiecesDrawTheSameFigureAsTheWholeSprite() throws {
        for look in [HeroAppearance.standard, paladin] {
            let catalog = SpriteCatalog(preloading: [.playerAdventurer, .playerBehind, .playerCloak, .playerFront],
                                        hero: look)
            let whole = scene()
            let single = catalog.makeSprite(.playerAdventurer)
            let root = SKNode()
            root.addChild(single)
            fit(root, catalog: catalog)
            whole.addChild(root)

            let stacked = scene()
            let pieces = SKNode()
            for (index, id) in [SpriteID.playerBehind, .playerCloak, .playerFront].enumerated() {
                let piece = catalog.makeSprite(id)
                piece.zPosition = CGFloat(index + 1)
                pieces.addChild(piece)
            }
            fit(pieces, catalog: catalog)
            stacked.addChild(pieces)

            let a = try picture(of: whole)
            let b = try picture(of: stacked)
            XCTAssertGreaterThan(a.drawnPixels, 2000, "the whole sprite drew nothing")
            XCTAssertLessThan(Double(a.differences(from: b)), Double(a.drawnPixels) * 0.01,
                              "the three pieces do not add up to the figure")
        }
    }

    private func walking(_ catalog: SpriteCatalog, look: HeroAppearance, velocity: CGPoint, frames: Int) -> SKScene {
        let scene = scene()
        let view = PlayerView(catalog: catalog, weaponSprite: .weaponSword, hand: look.build.hand,
                              cloth: look.cloak.clothiness, shoulders: look.build.shoulderHeight)
        fit(view, catalog: catalog)
        scene.addChild(view)
        let state = PlayerState(position: .zero, maxHealth: 100)
        for _ in 0..<frames {
            view.apply(state, screenVelocity: velocity, dt: 1.0 / 60)
        }
        return scene
    }

    func testAWalkingHerosCloakStaysWhereItIsAndTheRightWayUp() throws {
        for look in [HeroAppearance.standard, paladin] {
            let catalog = SpriteCatalog(preloading: [.playerAdventurer, .playerBehind, .playerCloak, .playerFront,
                                                     .weaponSword, .shadow, .fxGlow], hero: look)
            let still = try picture(of: walking(catalog, look: look, velocity: .zero, frames: 120))
            let running = try picture(of: walking(catalog, look: look, velocity: CGPoint(x: 240, y: 0), frames: 120))
            let turning = try picture(of: walking(catalog, look: look, velocity: CGPoint(x: -240, y: 0), frames: 120))
            guard let a = still.bounds, let b = running.bounds, let c = turning.bounds else {
                return XCTFail("nothing was drawn")
            }
            XCTAssertGreaterThan(still.drawnPixels, 2000)
            let height = Double(a.maxY - a.minY)
            let width = Double(a.maxX - a.minX)
            for other in [b, c] {
                // The figure keeps its size: a cloak turned on its side would not.
                XCTAssertEqual(Double(other.maxY - other.minY), height, accuracy: height * 0.08, "height changed")
                XCTAssertEqual(Double(other.maxX - other.minX), width, accuracy: width * 0.15, "width changed")
            }
            // Most of it is exactly where it was: only the swing (and the arm) differs.
            let changed = Double(still.differences(from: running)) / Double(still.drawnPixels)
            XCTAssertLessThan(changed, 0.15, "the walking cloak is not the same shape as the standing one (\(changed))")
        }
    }
}
