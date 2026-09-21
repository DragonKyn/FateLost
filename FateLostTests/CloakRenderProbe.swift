import SpriteKit
import XCTest
@testable import FateLost

/// Draws the hero four ways in a real SpriteKit view and prints the picture
/// (as base64 PNG) into the test log, so how SpriteKit actually renders the
/// pieces and the sway warp can be looked at rather than guessed.
@MainActor
final class CloakRenderProbe: XCTestCase {
    private let scale: CGFloat = 3

    private func pieces(_ catalog: SpriteCatalog, at x: CGFloat, in scene: SKScene) -> SKSpriteNode {
        let behind = catalog.makeSprite(.playerBehind)
        let cloak = catalog.makeSprite(.playerCloak)
        let front = catalog.makeSprite(.playerFront)
        for (index, piece) in [behind, cloak, front].enumerated() {
            piece.position = CGPoint(x: x, y: 20 * scale)
            piece.setScale(scale)
            piece.zPosition = CGFloat(index + 1)
            scene.addChild(piece)
        }
        return cloak
    }

    private func sheet(for look: HeroAppearance, label: String) throws {
        let catalog = SpriteCatalog(preloading: [.playerAdventurer, .playerBehind, .playerCloak, .playerFront], hero: look)
        let width = 4 * 100 * scale
        let scene = SKScene(size: CGSize(width: width, height: 100 * scale))
        scene.backgroundColor = UIColor(white: 0.25, alpha: 1)
        scene.anchorPoint = .zero

        // 1: the whole figure, as it was drawn before the pieces existed.
        let whole = catalog.makeSprite(.playerAdventurer)
        whole.position = CGPoint(x: 50 * scale, y: 20 * scale)
        whole.setScale(scale)
        scene.addChild(whole)

        // 2: the three pieces, no warp.
        _ = pieces(catalog, at: 150 * scale, in: scene)

        // 3: the pieces with an identity warp (source == destination).
        let cloakIdentity = pieces(catalog, at: 250 * scale, in: scene)
        var still = CapeSway()
        let restWarp = still.warp(imageSize: cloakIdentity.size, cloth: 1)
        still.reset()
        cloakIdentity.warpGeometry = SKWarpGeometryGrid(
            columns: CapeSway.columns.count - 1, rows: CapeSway.rows.count - 1,
            sourcePositions: restWarp.source, destinationPositions: restWarp.destination)

        // 4: the pieces with the sway of a hero walking hard to the right.
        let cloakSwaying = pieces(catalog, at: 350 * scale, in: scene)
        var sway = CapeSway()
        for _ in 0..<90 { sway.step(dt: 1.0 / 60, velocity: CGPoint(x: -200, y: 0), time: 0) }
        let warp = sway.warp(imageSize: cloakSwaying.size, cloth: 1)
        cloakSwaying.warpGeometry = SKWarpGeometryGrid(
            columns: CapeSway.columns.count - 1, rows: CapeSway.rows.count - 1,
            sourcePositions: warp.source, destinationPositions: warp.destination)
        print("CLOAKPROBE \(label) sway offset x=\(sway.offset.x) y=\(sway.offset.y) cloakSize=\(cloakSwaying.size) "
              + "wholeSize=\(whole.size) anchor=\(cloakSwaying.anchorPoint) textureRect=\(cloakSwaying.texture?.textureRect() ?? .zero)")

        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        view.presentScene(scene)
        guard let texture = view.texture(from: scene) else {
            throw XCTSkip("SpriteKit could not render offscreen here")
        }
        let image = UIImage(cgImage: texture.cgImage())
        guard let png = image.pngData() else { throw XCTSkip("no PNG") }
        print("CLOAKPROBE-IMAGE \(label) \(png.base64EncodedString())")
    }

    func testPaladinWithWingsAndPauldrons() throws {
        var look = HeroAppearance()
        look.cloak = .paladin
        look.cloakColor = "royal"
        look.detail = .pauldrons
        look.wings = .angel
        try sheet(for: look, label: "paladin")
    }

    func testTheDefaultHero() throws {
        try sheet(for: .standard, label: "default")
    }
}
