import SpriteKit

/// Draws lasting areas on the ground: fields, storms and auras.
///
/// Each zone is a tinted disc with a brighter rim lying flat on the
/// isometric ground, breathing gently, fading in and out at its ends. Auras
/// from passives are drawn fainter so a stack of them never hides the fight.
@MainActor
final class ZoneRenderer {
    @MainActor
    private final class ZoneView {
        let container = SKNode()
        let disc: SKSpriteNode
        let rim: SKSpriteNode
        var lastSeenFrame = 0

        init(catalog: SpriteCatalog, pointsPerWorldUnit: CGFloat) {
            disc = catalog.makeSprite(.fxDisc)
            rim = catalog.makeSprite(.fxRing)
            container.xScale = pointsPerWorldUnit
            container.yScale = -pointsPerWorldUnit / 2
            for sprite in [disc, rim] {
                sprite.blendMode = .add
                sprite.colorBlendFactor = 1
                container.addChild(sprite)
            }
        }
    }

    private let catalog: SpriteCatalog
    private let projection: IsometricProjection
    private let pointsPerWorldUnit: CGFloat
    private weak var layer: SKNode?
    private var views: [Int: ZoneView] = [:]
    private var spare: [ZoneView] = []
    private var departed: [Int] = []
    private var frameNumber = 0

    init(catalog: SpriteCatalog, projection: IsometricProjection, pointsPerWorldUnit: CGFloat, layer: SKNode) {
        self.catalog = catalog
        self.projection = projection
        self.pointsPerWorldUnit = pointsPerWorldUnit
        self.layer = layer
    }

    var activeCount: Int { views.count }

    func update(zones: [Zone], frame: WrappedRenderFrame, time: TimeInterval) {
        frameNumber &+= 1
        guard let layer else { return }
        let seconds = CGFloat(time)

        for zone in zones {
            let view: ZoneView
            if let existing = views[zone.id] {
                view = existing
            } else {
                view = spare.popLast() ?? ZoneView(catalog: catalog, pointsPerWorldUnit: pointsPerWorldUnit)
                layer.addChild(view.container)
                views[zone.id] = view
                let color = zone.spec.visual.color
                view.disc.color = color
                view.rim.color = color
            }
            view.lastSeenFrame = frameNumber

            view.container.position = projection.toScreen(frame.unwrapped(zone.position))
            let diameter = zone.radius * 2
            let breathe = 1 + 0.03 * sin(seconds * 3 + CGFloat(zone.id))
            view.disc.size = CGSize(width: diameter * breathe, height: diameter * breathe)
            view.rim.size = CGSize(width: diameter, height: diameter)

            let strength: CGFloat = zone.isAura ? 0.28 : 0.75
            let fadeIn = min(1, CGFloat(zone.age) / 0.3)
            let fadeOut = zone.remaining.isFinite ? min(1, CGFloat(zone.remaining) / 0.4) : 1
            let pulse = 0.85 + 0.15 * sin(seconds * 5 + CGFloat(zone.id))
            view.container.alpha = strength * fadeIn * fadeOut * pulse
        }

        departed.removeAll(keepingCapacity: true)
        for (id, view) in views where view.lastSeenFrame != frameNumber {
            departed.append(id)
        }
        for id in departed {
            if let view = views.removeValue(forKey: id) {
                view.container.removeFromParent()
                spare.append(view)
            }
        }
    }
}
