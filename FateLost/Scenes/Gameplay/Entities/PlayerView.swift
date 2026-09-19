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
        /// Seconds an attack animation lasts, and holds the facing.
        static let attackDuration: CGFloat = 0.22
        /// Weapon angles at the start and end of a swing (radians, facing right).
        static let swingFrom: CGFloat = 1.5
        static let swingTo: CGFloat = -2.1
        static let settleDuration: CGFloat = 0.14
        static let hurtFlashDuration: CGFloat = 0.18
        static let hurtColor = UIColor(red: 1, green: 0.2, blue: 0.15, alpha: 1)
    }

    private var facingSign: CGFloat = 1
    /// Seconds since the last attack began; large when idle.
    private var attackAge: CGFloat = 10
    private var attackIsMelee = true
    private var attackFacing: CGFloat = 1
    private var defeatAge: CGFloat?

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

    /// Starts the attack animation toward a screen-space direction.
    func playAttack(screenDirection: CGPoint, isMelee: Bool) {
        attackAge = 0
        attackIsMelee = isMelee
        if abs(screenDirection.x) > 0.01 {
            attackFacing = screenDirection.x >= 0 ? 1 : -1
        }
    }

    /// - Parameters:
    ///   - screenVelocity: Player velocity projected to screen space, used
    ///     for facing (players read direction on screen, not in world).
    ///   - dt: Seconds since the last frame, for animation timers.
    func apply(_ state: PlayerState, screenVelocity: CGPoint, dt: CGFloat) {
        attackAge += dt

        if state.isDefeated {
            applyDefeat(dt: dt)
            return
        }

        let attacking = attackAge < Style.attackDuration
        if attacking {
            facingSign = attackFacing
        } else if abs(screenVelocity.x) > Style.turnThreshold * max(1, screenVelocity.length) {
            facingSign = screenVelocity.x >= 0 ? 1 : -1
        }
        body.xScale = facingSign

        let speedFraction = min(1, screenVelocity.length / 120)
        let phase = state.strideTime * Style.strideFrequency * 2 * .pi
        let bob = CGFloat(abs(sin(phase))) * Style.bobHeight * speedFraction
        body.position = CGPoint(x: 0, y: bob)
        body.zRotation = CGFloat(sin(phase)) * Style.sway * speedFraction * facingSign

        if attacking {
            let t = attackAge / Style.attackDuration
            if attackIsMelee {
                // Fast out, slow settle: most of the arc in the first third.
                let eased = 1 - pow(1 - t, 3)
                weapon.zRotation = Style.swingFrom + (Style.swingTo - Style.swingFrom) * eased
            } else {
                // A short recoil for bows and staves.
                weapon.zRotation = Style.weaponRestAngle + 0.35 * sin(t * .pi)
            }
        } else {
            let walk = Style.weaponRestAngle + CGFloat(sin(phase + .pi / 2)) * 0.12 * speedFraction
            let settle = (attackAge - Style.attackDuration) / Style.settleDuration
            if attackIsMelee, settle < 1 {
                // Ease back from the end of the swing to the carry pose.
                weapon.zRotation = Style.swingTo + (walk - Style.swingTo) * settle
            } else {
                weapon.zRotation = walk
            }
        }

        // Red flash on a hit, then a blink for the rest of the immunity.
        let sinceHit = CGFloat(state.timeSinceHit)
        if sinceHit < Style.hurtFlashDuration {
            figure.color = Style.hurtColor
            figure.colorBlendFactor = 0.75 * (1 - sinceHit / Style.hurtFlashDuration)
        } else {
            figure.colorBlendFactor = 0
        }
        body.alpha = state.isInvulnerable && Int(sinceHit * 16) % 2 == 1 ? 0.45 : 1

        // The shadow tightens slightly as the body rises.
        shadowSprite.setScale(1 - bob * 0.015)
    }

    private func applyDefeat(dt: CGFloat) {
        let age = (defeatAge ?? 0) + dt
        defeatAge = age
        let fall = min(1, age / 0.45)
        let eased = 1 - (1 - fall) * (1 - fall)
        body.alpha = 1
        body.position = .zero
        body.zRotation = eased * (.pi / 2) * facingSign
        figure.color = UIColor(white: 0.15, alpha: 1)
        figure.colorBlendFactor = 0.5 * eased
        weapon.zRotation = Style.weaponRestAngle - eased
        shadowSprite.setScale(1 + 0.3 * eased)
    }
}
