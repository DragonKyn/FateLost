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
    /// Seconds the held weapon stays out of the hand: a thrown boomerang is
    /// not also in the hero's grip.
    private var weaponAway: CGFloat = 0

    private let catalog: SpriteCatalog
    /// Shimmer around the player while a barrier is up.
    private let barrierGlow: SKSpriteNode
    private var currentForm: FormID?
    private var formScale: CGFloat = 1
    private var formTint: UIColor?
    /// Seconds since the last level-up; large when idle.
    private var levelUpAge: CGFloat = 10
    /// Weapon rest angle; bows are carried upright.
    private var restAngle: CGFloat
    private var weaponSprite: SpriteID

    init(catalog: SpriteCatalog, weaponSprite: SpriteID, hand: CGPoint = BodyBuild.standard.hand) {
        self.catalog = catalog
        shadowSprite = catalog.makeSprite(.shadow)
        figure = catalog.makeSprite(.playerAdventurer)
        weapon = catalog.makeSprite(weaponSprite)
        self.weaponSprite = weaponSprite
        barrierGlow = catalog.makeSprite(.fxGlow)
        restAngle = weaponSprite == .weaponBow ? -0.1 : Style.weaponRestAngle
        super.init()

        shadowSprite.zPosition = -0.5
        addChild(shadowSprite)
        addChild(body)
        body.addChild(figure)

        weapon.position = hand
        weapon.zRotation = restAngle
        weapon.zPosition = 0.1
        body.addChild(weapon)

        barrierGlow.blendMode = .add
        barrierGlow.color = UIColor(rgb: 0x8FD0FF)
        barrierGlow.colorBlendFactor = 1
        barrierGlow.size = CGSize(width: 70, height: 84)
        barrierGlow.position = CGPoint(x: 0, y: 26)
        barrierGlow.zPosition = 0.3
        barrierGlow.alpha = 0
        addChild(barrierGlow)
    }

    /// Puts a different weapon in the hand, as when one is found mid-run.
    func setWeapon(_ id: SpriteID) {
        guard id != weaponSprite else { return }
        weaponSprite = id
        if let texture = catalog.texture(id) {
            weapon.texture = texture
        }
        weapon.size = catalog.size(id)
        weapon.anchorPoint = catalog.anchor(id)
        restAngle = id == .weaponBow ? -0.1 : Style.weaponRestAngle
    }

    /// Swaps the figure for a form's (or back to the adventurer).
    func setForm(_ form: FormDefinition?) {
        guard form?.id != currentForm else { return }
        currentForm = form?.id
        let id = form?.sprite ?? .playerAdventurer
        figure.texture = catalog.texture(id)
        figure.size = catalog.size(id)
        figure.anchorPoint = catalog.anchor(id)
        formScale = form?.scale ?? 1
        formTint = form?.tint?.uiColor
        weapon.isHidden = form?.hidesWeapon ?? false
    }

    /// A golden flare and swell as the player levels up.
    func playLevelUp() {
        levelUpAge = 0
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("PlayerView is created in code")
    }

    /// A throw: the arm goes out, and the weapon is gone from the hand for the
    /// length of the flight (it is back in the hand a moment later on its own).
    func playThrow(screenDirection: CGPoint) {
        playAttack(screenDirection: screenDirection, isMelee: false)
        weaponAway = 0.55
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
        levelUpAge += dt
        weaponAway = max(0, weaponAway - dt)
        weapon.alpha = weaponAway > 0 ? 0 : 1

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
                weapon.zRotation = restAngle + 0.35 * sin(t * .pi)
            }
        } else {
            let walk = restAngle + CGFloat(sin(phase + .pi / 2)) * 0.12 * speedFraction
            let settle = (attackAge - Style.attackDuration) / Style.settleDuration
            if attackIsMelee, settle < 1 {
                // Ease back from the end of the swing to the carry pose.
                weapon.zRotation = Style.swingTo + (walk - Style.swingTo) * settle
            } else {
                weapon.zRotation = walk
            }
        }

        // Red flash on a hit, a golden flare on levelling up, otherwise the
        // form's own tint.
        let sinceHit = CGFloat(state.timeSinceHit)
        if sinceHit < Style.hurtFlashDuration {
            figure.color = Style.hurtColor
            figure.colorBlendFactor = 0.75 * (1 - sinceHit / Style.hurtFlashDuration)
        } else if levelUpAge < 0.7 {
            figure.color = UIColor(rgb: 0xFFD27A)
            figure.colorBlendFactor = 0.8 * (1 - levelUpAge / 0.7)
        } else if let formTint {
            figure.color = formTint
            figure.colorBlendFactor = 0.35
        } else {
            figure.colorBlendFactor = 0
        }
        let swell = levelUpAge < 0.5 ? 1 + 0.22 * sin(levelUpAge / 0.5 * .pi) : 1
        figure.setScale(formScale * swell)

        // Stealth turns the player to a shade; after a hit, a blink for the
        // rest of the immunity.
        if state.isStealthed {
            body.alpha = 0.32
        } else {
            body.alpha = state.isInvulnerable && sinceHit < 1 && Int(sinceHit * 16) % 2 == 1 ? 0.45 : 1
        }

        let shielded = min(1, CGFloat(state.barrier / max(state.maxHealth * 0.15, 1)))
        let shimmer = 0.75 + 0.25 * sin(CGFloat(state.strideTime + Double(attackAge)) * 4)
        barrierGlow.alpha = state.barrier > 0.5 ? 0.35 + 0.35 * shielded * shimmer : 0

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
        weapon.zRotation = restAngle - eased
        shadowSprite.setScale(1 + 0.3 * eased)
    }
}
