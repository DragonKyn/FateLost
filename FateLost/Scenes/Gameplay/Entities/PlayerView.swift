import SpriteKit

/// Visual representation of the player. Reads `PlayerState`; never writes it.
@MainActor
final class PlayerView: SKNode {
    private let shadowSprite: SKSpriteNode
    /// Everything that bobs and flips with the walk cycle.
    private let body = SKNode()
    private let figure: SKSpriteNode
    private let weapon: SKSpriteNode

    private enum Style {
        static let bobHeight: CGFloat = 2.6
        /// Full bob cycles per second of stride time at base speed.
        static let strideFrequency: Double = 2.2
        static let sway: CGFloat = 0.05
        static let weaponOffset = CGPoint(x: 11, y: 20)
        static let weaponRestAngle: CGFloat = -0.35
        /// Minimum horizontal screen motion before the figure turns around,
        /// so moving almost straight up/down does not flicker the facing.
        static let turnThreshold: CGFloat = 0.15
    }

    private var facingSign: CGFloat = 1

    init(catalog: SpriteCatalog, weaponSprite: SpriteID) {
        shadowSprite = catalog.makeSprite(.shadow)
        figure = catalog.makeSprite(.playerAdventurer)
        weapon = catalog.makeSprite(weaponSprite)
        super.init()

        shadowSprite.zPosition = -0.5
        addChild(shadowSprite)
        addChild(body)
        body.addChild(figure)

        weapon.position = Style.weaponOffset
        weapon.zRotation = Style.weaponRestAngle
        weapon.zPosition = 0.1
        body.addChild(weapon)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("PlayerView is created in code")
    }

    /// - Parameter screenVelocity: Player velocity projected to screen space,
    ///   used for facing (players read direction on screen, not in world).
    func apply(_ state: PlayerState, screenVelocity: CGPoint) {
        let speedFraction = min(1, screenVelocity.length / 120)

        if abs(screenVelocity.x) > Style.turnThreshold * max(1, screenVelocity.length) {
            facingSign = screenVelocity.x >= 0 ? 1 : -1
        }
        body.xScale = facingSign

        let phase = state.strideTime * Style.strideFrequency * 2 * .pi
        let bob = CGFloat(abs(sin(phase))) * Style.bobHeight * speedFraction
        body.position = CGPoint(x: 0, y: bob)
        body.zRotation = CGFloat(sin(phase)) * Style.sway * speedFraction * facingSign
        weapon.zRotation = Style.weaponRestAngle + CGFloat(sin(phase + .pi / 2)) * 0.12 * speedFraction

        // The shadow tightens slightly as the body rises.
        shadowSprite.setScale(1 - bob * 0.015)
    }
}
