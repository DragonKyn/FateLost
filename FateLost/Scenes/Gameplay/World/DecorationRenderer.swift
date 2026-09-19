import SpriteKit

/// Keeps nodes alive only for decorations near the camera.
///
/// An arena holds well over a thousand decorations; only a few dozen are ever
/// visible. The renderer queries a spatial grid around the focus, recycles
/// nodes for decorations that left the area, and places newcomers at the
/// wrapped image nearest the player. It only re-queries when the focus
/// crosses a grid cell, so most frames cost nothing.
@MainActor
final class DecorationRenderer {
    private let placements: [DecorationPlacement]
    private let grid: ToroidalSpatialGrid
    private let projection: IsometricProjection
    private let catalog: SpriteCatalog
    private weak var standingLayer: SKNode?
    private weak var decalLayer: SKNode?

    private var active: [Int: SKSpriteNode] = [:]
    private var pools: [SpriteID: NodePool<SKSpriteNode>] = [:]
    private var queryBuffer: [Int] = []
    private var visibleBuffer = Set<Int>()
    private var lastCell: (column: Int, row: Int)?
    private var lastRadius: CGFloat = 0

    init(placements: [DecorationPlacement], world: ToroidalWorld, projection: IsometricProjection,
         catalog: SpriteCatalog, standingLayer: SKNode, decalLayer: SKNode, cellSize: CGFloat = 6) {
        self.placements = placements
        self.projection = projection
        self.catalog = catalog
        self.standingLayer = standingLayer
        self.decalLayer = decalLayer

        var grid = ToroidalSpatialGrid(world: world, cellSize: cellSize)
        for (index, placement) in placements.enumerated() {
            grid.insert(index, at: placement.position)
        }
        self.grid = grid
    }

    var activeCount: Int { active.count }

    /// - Parameters:
    ///   - radius: World-unit radius that must be populated around the focus.
    ///   - force: Refresh even if the focus has not changed cell (after a
    ///     rebase or resize).
    func update(frame: WrappedRenderFrame, radius: CGFloat, force: Bool = false) {
        let cell = grid.cellCoordinate(for: frame.focusWrapped)
        let sameCell = lastCell.map { $0.column == cell.column && $0.row == cell.row } ?? false
        guard force || !sameCell || radius > lastRadius else { return }
        lastCell = cell
        lastRadius = radius

        // Pad by one cell so the set stays valid while the focus roams
        // anywhere within its current cell.
        let queryRadius = radius + grid.cellSize
        queryBuffer.removeAll(keepingCapacity: true)
        grid.query(around: frame.focusWrapped, radius: queryRadius, into: &queryBuffer)

        visibleBuffer.removeAll(keepingCapacity: true)
        let limitSquared = queryRadius * queryRadius
        for index in queryBuffer where frame.world.distanceSquared(frame.focusWrapped,
                                                                     placements[index].position) <= limitSquared {
            visibleBuffer.insert(index)
        }

        for (index, node) in active where !visibleBuffer.contains(index) {
            pool(for: placements[index].kind).release(node)
            active[index] = nil
        }

        for index in visibleBuffer {
            let placement = placements[index]
            let node: SKSpriteNode
            if let existing = active[index] {
                node = existing
            } else {
                node = pool(for: placement.kind).acquire()
                configure(node, for: placement)
                active[index] = node
            }
            // Positions are re-derived every refresh: after a rebase, or as a
            // far-away object's nearest image changes, they move too.
            let screen = projection.toScreen(frame.unwrapped(placement.position))
            node.position = screen
            node.zPosition = DepthSorting.z(forScreenY: screen.y)
        }
    }

    private func configure(_ node: SKSpriteNode, for placement: DecorationPlacement) {
        let spec = DecorationCatalog.spec(for: placement.kind)
        node.setScale(placement.scale)
        node.xScale = placement.mirrored ? -placement.scale : placement.scale
        let parent = spec.layer == .groundDecal ? decalLayer : standingLayer
        parent?.addChild(node)
    }

    private func pool(for kind: DecorationKind) -> NodePool<SKSpriteNode> {
        let spec = DecorationCatalog.spec(for: kind)
        if let pool = pools[spec.spriteID] { return pool }
        let catalog = self.catalog
        let pool = NodePool<SKSpriteNode>(make: {
            let sprite = catalog.makeSprite(spec.spriteID)
            DecorationEffects.attach(spec.animation, to: sprite, catalog: catalog)
            return sprite
        })
        pools[spec.spriteID] = pool
        return pool
    }
}

/// Animated embellishments for decorations (flames, magical glows).
@MainActor
enum DecorationEffects {
    static func attach(_ animation: DecorationAnimation, to sprite: SKSpriteNode, catalog: SpriteCatalog) {
        switch animation {
        case .none:
            return
        case .flicker:
            let glow = catalog.makeSprite(.fxGlow)
            glow.color = SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.alpha = 0.55
            glow.setScale(2.6)
            glow.position = CGPoint(x: 0, y: 8)
            glow.zPosition = -0.01
            sprite.addChild(glow)

            let flame = catalog.makeSprite(.fxFlame)
            flame.position = CGPoint(x: 0, y: 2)
            flame.zPosition = 0.01
            sprite.addChild(flame)

            // Slightly irregular timings so neighbouring fires never pulse in sync.
            let jitter = Double.random(in: 0.9...1.2)
            flame.run(.repeatForever(.sequence([
                .group([.scaleY(to: 1.18, duration: 0.13 * jitter), .scaleX(to: 0.9, duration: 0.13 * jitter)]),
                .group([.scaleY(to: 0.92, duration: 0.17 * jitter), .scaleX(to: 1.06, duration: 0.17 * jitter)]),
            ])))
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.7, duration: 0.21 * jitter),
                .fadeAlpha(to: 0.45, duration: 0.26 * jitter),
            ])))
        case .pulse:
            let glow = catalog.makeSprite(.fxGlow)
            glow.color = SKColor(red: 0.95, green: 0.68, blue: 0.3, alpha: 1)
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.alpha = 0.3
            glow.setScale(1.5)
            glow.position = CGPoint(x: 0, y: 36)
            glow.zPosition = 0.01
            sprite.addChild(glow)
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 1.4),
                .fadeAlpha(to: 0.2, duration: 1.6),
            ])))
        }
    }
}

/// Depth ordering for the isometric view: things lower on screen are nearer
/// the viewer and draw on top.
enum DepthSorting {
    /// Scene-wide z bands. Everything within a band is sorted by screen y.
    enum Band {
        static let ground: CGFloat = -1000
        static let groundDecals: CGFloat = -500
        static let standing: CGFloat = 0
        static let overlays: CGFloat = 500
        static let hud: CGFloat = 1000
    }

    /// Converts screen y to a z offset small enough to stay inside a band
    /// for any reachable position (see the render-frame rebase threshold).
    private static let depthPerPoint: CGFloat = 0.001

    static func z(forScreenY y: CGFloat) -> CGFloat {
        -y * depthPerPoint
    }
}
