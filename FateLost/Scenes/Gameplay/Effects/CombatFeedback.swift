import SpriteKit
import QuartzCore

/// Turns combat events into what the player sees, hears and feels.
///
/// This is where "game feel" lives: hit flashes, sparks, damage numbers,
/// falling bodies, camera shake, hit-stop, sounds and haptics. The simulation
/// only reports what happened; every presentation choice is made here, so
/// tuning the feel never touches game rules.
@MainActor
final class CombatFeedback {
    struct Tuning {
        /// Seconds the game freezes when the player is hit, to sell the blow.
        var playerHitStop: TimeInterval = 0.07
        var criticalHitStop: TimeInterval = 0.03
        var playerHitTrauma: CGFloat = 0.42
        var criticalTrauma: CGFloat = 0.14
        var burstTrauma: CGFloat = 0.12
        var deathTrauma: CGFloat = 0.8
        /// Minimum seconds between haptic pulses of the same kind.
        var hapticInterval: TimeInterval = 0.12
    }

    private let tuning = Tuning()
    private let effects: EffectsRenderer
    private let enemies: EnemyRenderer
    private let player: PlayerView
    private let camera: CameraController
    private let projection: IsometricProjection
    private let audio: AudioManager
    private let haptics: HapticsProviding
    private let damageFlash: SKSpriteNode

    private var lastCriticalHaptic: TimeInterval = 0
    private var lastHurtHaptic: TimeInterval = 0
    /// 0…1 strength of the red edge flash after taking damage.
    private var hurtFlash: CGFloat = 0

    /// Seconds of hit-stop the scene should apply; the scene consumes it.
    private(set) var pendingHitStop: TimeInterval = 0

    init(effects: EffectsRenderer, enemies: EnemyRenderer, player: PlayerView, camera: CameraController,
         projection: IsometricProjection, audio: AudioManager, haptics: HapticsProviding) {
        self.effects = effects
        self.enemies = enemies
        self.player = player
        self.camera = camera
        self.projection = projection
        self.audio = audio
        self.haptics = haptics

        damageFlash = SKSpriteNode(texture: SKTexture(image: PlaceholderArt.vignette(
            color: RGBA(hex: 0xB0141A)
        )))
        damageFlash.zPosition = DepthSorting.Band.overlays + 5
        damageFlash.alpha = 0
        camera.camera.addChild(damageFlash)

        audio.preload([.swordSwing, .hit, .criticalHit, .goblinDeath, .bowShot, .arcaneCast, .arcaneBurst,
                       .playerHurt, .playerDeath])
    }

    func layout(screenSize: CGSize) {
        damageFlash.size = CGSize(width: screenSize.width * 1.05, height: screenSize.height * 1.05)
    }

    func consumeHitStop() -> TimeInterval {
        defer { pendingHitStop = 0 }
        return pendingHitStop
    }

    /// Presents one frame's worth of events.
    ///
    /// - Parameter lowHealth: Whether the player is in danger, which keeps a
    ///   faint pulse on the damage vignette.
    func present(_ events: [CombatEvent], lowHealth: Bool, dt: CGFloat) {
        var hits = 0
        for event in events {
            switch event {
            case let .meleeSwing(origin, direction, range, _):
                effects.slash(at: origin, direction: direction, range: range)
                player.playAttack(screenDirection: projection.toScreen(direction), isMelee: true)
                audio.play(.swordSwing)

            case let .projectileFired(spriteID, _, direction):
                player.playAttack(screenDirection: projection.toScreen(direction), isMelee: false)
                audio.play(spriteID == .projectileArcaneBolt ? .arcaneCast : .bowShot)

            case let .enemyHit(enemyID, position, amount, isCritical, _):
                hits += 1
                enemies.flash(enemyID: enemyID)
                effects.spark(at: position, isCritical: isCritical)
                effects.damageNumber(amount, at: position, isCritical: isCritical)
                if isCritical {
                    audio.play(.criticalHit)
                    camera.addTrauma(tuning.criticalTrauma)
                    pendingHitStop = max(pendingHitStop, tuning.criticalHitStop)
                    playHaptic(.criticalHit, last: &lastCriticalHaptic)
                }

            case let .enemyKilled(enemyID, kind, position, direction):
                let look = enemies.snapshot(enemyID: enemyID)
                let spriteID = look?.spriteID ?? EnemyCatalog.definition(for: kind)?.spriteID ?? .enemyGoblin
                // Bodies topple away from the blow.
                let screenPush = projection.toScreen(direction).x
                let fall: CGFloat = abs(screenPush) > 0.01 ? (screenPush >= 0 ? 1 : -1) : (look?.facing ?? 1)
                effects.corpse(at: position, spriteID: spriteID, facing: fall, tint: UIColor(rgb: 0x1C1A14))
                effects.splat(at: position, color: UIColor(rgb: 0x2A3316))
                audio.play(.goblinDeath)

            case .enemyWindup:
                break

            case let .explosion(position, radius):
                effects.burst(at: position, radius: radius, color: UIColor(rgb: 0xA070FF))
                audio.play(.arcaneBurst)
                camera.addTrauma(tuning.burstTrauma)

            case .playerHit:
                hurtFlash = 1
                audio.play(.playerHurt)
                camera.addTrauma(tuning.playerHitTrauma)
                pendingHitStop = max(pendingHitStop, tuning.playerHitStop)
                playHaptic(.majorDamage, last: &lastHurtHaptic)

            case .playerDefeated:
                hurtFlash = 1
                audio.play(.playerDeath)
                audio.playMusic(.musicDefeat, fadeDuration: 0.6, loops: false)
                audio.stopAmbience(fadeDuration: 2)
                camera.addTrauma(tuning.deathTrauma)
                haptics.play(.playerDeath)
            }
        }
        if hits > 0 {
            audio.play(.hit)
        }

        // The edge flash fades quickly, but never below a faint pulse when
        // health is low.
        hurtFlash = max(0, hurtFlash - dt * 2.4)
        let danger: CGFloat = lowHealth ? 0.28 + 0.12 * CGFloat(sin(CACurrentMediaTime() * 4)) : 0
        damageFlash.alpha = max(hurtFlash * 0.9, danger)
    }

    private func playHaptic(_ event: HapticEvent, last: inout TimeInterval) {
        let now = CACurrentMediaTime()
        guard now - last >= tuning.hapticInterval else { return }
        last = now
        haptics.play(event)
    }
}
