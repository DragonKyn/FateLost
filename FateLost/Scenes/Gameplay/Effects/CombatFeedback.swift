import SpriteKit
import QuartzCore

/// Turns combat events into what the player sees, hears and feels.
///
/// This is where "game feel" lives: hit flashes, sparks, damage numbers,
/// falling bodies, skill effects, camera shake, hit-stop, sounds and
/// haptics. The simulation only reports what happened; every presentation
/// choice is made here, so tuning the feel never touches game rules.
@MainActor
final class CombatFeedback {
    struct Tuning {
        /// Seconds the game freezes when the player is hit, to sell the blow.
        var playerHitStop: TimeInterval = 0.07
        var criticalHitStop: TimeInterval = 0.03
        var playerHitTrauma: CGFloat = 0.42
        var criticalTrauma: CGFloat = 0.14
        var burstTrauma: CGFloat = 0.1
        var explosionTrauma: CGFloat = 0.35
        var levelUpTrauma: CGFloat = 0.4
        var deathTrauma: CGFloat = 0.8
        /// Minimum seconds between haptic pulses of the same kind.
        var hapticInterval: TimeInterval = 0.12
        /// Collections closer together than this climb the ember chime scale.
        var emberComboWindow: TimeInterval = 0.4
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
    private let fateFlash: SKSpriteNode
    /// A wash of the rift's colour over everything while the party is in one.
    private let riftTint: SKSpriteNode
    private var riftLevel: CGFloat = 0
    /// The rift the party is in, if any: set every frame by the scene.
    var riftKind: RiftKind? {
        didSet {
            guard let kind = riftKind, kind != oldValue else { return }
            riftTint.color = UIColor(rgb: kind.tint)
        }
    }

    private var lastCriticalHaptic: TimeInterval = 0
    private var lastHurtHaptic: TimeInterval = 0
    /// 0…1 strength of the red edge flash after taking damage.
    private var hurtFlash: CGFloat = 0
    /// 0…1 strength of the golden edge flash on levelling up.
    private var levelFlash: CGFloat = 0
    private var emberCombo = 0
    private var lastEmberTime: TimeInterval = 0
    private var dotNumberToggle = false

    /// Seconds of hit-stop the scene should apply; the scene consumes it.
    private(set) var pendingHitStop: TimeInterval = 0
    /// The player's look, for dash afterimages.
    var playerSpriteID: SpriteID = .playerAdventurer
    var playerPosition: CGPoint = .zero
    /// In a party a fall is not the end of the run: the defeat music and the
    /// silenced ambience are for a lone hero, and a revive would not undo them.
    var isParty = false
    /// The level-up burst's reach, for sizing its rings.
    var levelUpRadius: CGFloat = 4.2

    init(effects: EffectsRenderer, enemies: EnemyRenderer, player: PlayerView, camera: CameraController,
         projection: IsometricProjection, audio: AudioManager, haptics: HapticsProviding) {
        self.effects = effects
        self.enemies = enemies
        self.player = player
        self.camera = camera
        self.projection = projection
        self.audio = audio
        self.haptics = haptics

        damageFlash = SKSpriteNode(texture: SKTexture(image: PlaceholderArt.vignette(color: RGBA(hex: 0xB0141A))))
        damageFlash.zPosition = DepthSorting.Band.overlays + 5
        damageFlash.alpha = 0
        camera.camera.addChild(damageFlash)

        fateFlash = SKSpriteNode(texture: SKTexture(image: PlaceholderArt.vignette(color: RGBA(hex: 0xFFB84A))))
        fateFlash.zPosition = DepthSorting.Band.overlays + 6
        fateFlash.blendMode = .add
        fateFlash.alpha = 0
        camera.camera.addChild(fateFlash)

        riftTint = SKSpriteNode(texture: SKTexture(image: PlaceholderArt.vignette(color: RGBA(hex: 0xFFFFFF))))
        riftTint.zPosition = DepthSorting.Band.overlays + 4
        riftTint.colorBlendFactor = 1
        riftTint.alpha = 0
        camera.camera.addChild(riftTint)

        audio.preload([.swordSwing, .hit, .criticalHit, .goblinDeath, .bowShot, .arcaneCast, .arcaneBurst,
                       .playerHurt, .playerDeath, .levelUp, .abilityImpact, .abilityFire, .abilityFrost,
                       .abilityLightning, .abilityHoly, .abilityShadow, .abilityNature, .abilitySonic, .abilityBuff,
                       .summon, .dash, .heal, .dodge, .kegBlast, .shapeshift] + SoundCue.emberChimes)
    }

    func layout(screenSize: CGSize) {
        let size = CGSize(width: screenSize.width * 1.05, height: screenSize.height * 1.05)
        damageFlash.size = size
        fateFlash.size = size
        riftTint.size = size
    }

    func consumeHitStop() -> TimeInterval {
        defer { pendingHitStop = 0 }
        return pendingHitStop
    }

    /// Swings at least this long are heavy enough to shake the camera a little.
    static let heavySwingRange: CGFloat = 2.3

    /// Whether something that happened at `point` was this phone's own hero
    /// (an attack starts at the hero's feet).
    private func isOwn(_ point: CGPoint) -> Bool {
        let dx = point.x - playerPosition.x
        let dy = point.y - playerPosition.y
        return dx * dx + dy * dy < 1.5 * 1.5
    }

    /// Presents one frame's worth of events.
    ///
    /// - Parameter lowHealth: Whether the player is in danger, which keeps a
    ///   faint pulse on the damage vignette.
    func present(_ events: [CombatEvent], lowHealth: Bool, frame: WrappedRenderFrame, dt: CGFloat) {
        var hits = 0
        var critFlares = 0
        for event in events {
            switch event {
            case let .meleeSwing(origin, direction, range, _):
                effects.slash(at: origin, direction: direction, range: range)
                // Sparks off the edge of the blade at the end of its sweep.
                effects.motes(at: origin + direction * (range * 0.85), count: range >= CombatFeedback.heavySwingRange ? 6 : 3,
                              color: UIColor(rgb: 0xFFF0D0), spread: 0.35, lifetime: 0.35)
                if isOwn(origin) {
                    player.playAttack(screenDirection: projection.toScreen(direction), isMelee: true)
                    // A long, heavy blade (the claymore) is felt in the camera.
                    if range >= CombatFeedback.heavySwingRange { camera.addTrauma(0.1) }
                }
                audio.play(.swordSwing)

            case let .projectileFired(spriteID, origin, direction):
                // In a party every hero's attacks reach every phone; only this
                // phone's own hero raises an arm for them.
                let own = isOwn(origin)
                let screenDirection = projection.toScreen(direction)
                switch spriteID {
                case .projectileArrow:
                    if own { player.playAttack(screenDirection: screenDirection, isMelee: false) }
                    audio.play(.bowShot)
                case .projectileArcaneBolt:
                    if own { player.playAttack(screenDirection: screenDirection, isMelee: false) }
                    audio.play(.arcaneCast)
                case .projectileBoomerang:
                    // A visible throw: the arm goes out and the boomerang leaves
                    // the hand until it is caught again.
                    if own { player.playThrow(screenDirection: screenDirection) }
                    audio.play(.swordSwing)
                default:
                    // Wand bolts and the rest: the arm still goes out.
                    if own { player.playAttack(screenDirection: screenDirection, isMelee: false) }
                    audio.play(.arcaneCast)
                }

            case let .enemyHit(enemyID, position, amount, isCritical, _, type, isDot):
                if isDot {
                    // Damage over time shows as small tinted numbers, every other tick.
                    dotNumberToggle.toggle()
                    if dotNumberToggle {
                        effects.damageNumber(amount, at: position, isCritical: false, color: type.numberColor,
                                             small: true)
                    }
                    continue
                }
                hits += 1
                enemies.flash(enemyID: enemyID)
                let tint: UIColor? = type == .physical ? nil : type.numberColor
                effects.spark(at: position, isCritical: isCritical, color: isCritical ? nil : tint)
                effects.damageNumber(amount, at: position, isCritical: isCritical, color: tint)
                if isCritical, critFlares < 3 {
                    // A ring and a second spark: a critical is seen as well as read.
                    critFlares += 1
                    effects.ring(at: position, radius: 0.9, color: UIColor(rgb: 0xFFC24A), lifetime: 0.3)
                    effects.spark(at: position, isCritical: true, color: UIColor(rgb: 0xFFE9A8))
                }
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
                effects.corpse(at: position, spriteID: spriteID, facing: fall, tint: UIColor(rgb: 0x1C1A14),
                               scale: look?.scale ?? 1)
                effects.splat(at: position, color: UIColor(rgb: 0x2A3316))
                if let definition = EnemyCatalog.definition(for: kind), definition.rank >= .elite {
                    effects.grandDeath(at: position, rank: definition.rank,
                                       color: VisualStyle.matching(definition.damageType).color)
                    if definition.rank == .elite { camera.addTrauma(0.15) }
                }
                audio.play(.goblinDeath)

            case .enemyWindup:
                break

            case let .burst(position, radius, visual):
                effects.burst(at: position, radius: radius, color: visual.color, glows: visual.glows)
                effects.flare(visual, at: position, radius: radius)
                audio.play(visual.sound)
                camera.addTrauma(tuning.burstTrauma * min(1.5, radius / 2))

            case let .cone(origin, direction, range, arcDegrees, visual):
                effects.cone(at: origin, direction: direction, range: range, arcDegrees: arcDegrees, color: visual.color)
                effects.flare(visual, at: origin + direction * (range * 0.7), radius: range * 0.5)
                player.playAttack(screenDirection: projection.toScreen(direction), isMelee: true)
                audio.play(visual.sound)
                camera.addTrauma(tuning.burstTrauma)

            case let .chain(points, visual):
                effects.chain(through: points, color: visual.color, frame: frame)
                audio.play(.abilityLightning)

            case let .strikeIncoming(position, radius, delay, visual):
                effects.telegraph(at: position, radius: radius, delay: CGFloat(delay), color: visual.color)

            case let .bolt(position, visual):
                effects.pillar(at: position, color: visual.color, width: 0.45, height: 1.2, lifetime: 0.22)
                effects.spark(at: position, isCritical: true, color: visual.color)
                effects.flare(visual, at: position, radius: 1.1)
                audio.play(visual.sound)

            case let .dash(from, to, visual):
                effects.afterimages(from: from, to: to, spriteID: playerSpriteID, color: visual.color,
                                    facing: projection.toScreen(to - from).x >= 0 ? 1 : -1)
                audio.play(.dash)

            case let .abilityCast(_, visual):
                effects.motes(at: playerPosition, count: 8, color: visual.color, spread: 0.5, lifetime: 0.7)
                // A ring at the caster's feet: the cast is visible even when its effect is elsewhere.
                effects.ring(at: playerPosition, radius: 1.3, color: visual.color, lifetime: 0.35)
                audio.play(visual.sound)
                haptics.play(.uiTap)

            case let .summoned(position, visual):
                effects.burst(at: position, radius: 1.2, color: visual.color, glows: true)
                effects.motes(at: position, count: 8, color: visual.color, spread: 0.8, lifetime: 0.8)
                audio.play(.summon)

            case let .allyFell(position, visual):
                // Whatever held it together comes apart and sinks away.
                effects.motes(at: position, count: 10, color: visual.color, spread: 1, lifetime: 0.7)
                effects.splat(at: position, color: UIColor(rgb: 0x1A1A22))
                audio.play(.summon)

            case .summonsDismissed, .summonsRecalled:
                audio.play(.uiBack)

            case .waveBegan:
                audio.play(.uiConfirm)

            case .bossArrived:
                // A champion landing is felt before it is read.
                camera.addTrauma(0.9)
                haptics.play(.criticalHit)
                audio.play(.abilityImpact)

            case .bossDefeated, .realmConquered:
                camera.addTrauma(0.6)
                audio.play(.levelUp)

            case let .enemyExploded(position, radius):
                effects.burst(at: position, radius: radius, color: VisualStyle.fire.color)
                effects.motes(at: position, count: 10, color: UIColor(rgb: 0xFFB040), spread: radius * 0.5,
                              lifetime: 0.7)
                effects.splat(at: position, color: UIColor(rgb: 0x1A1612))
                audio.play(.kegBlast)
                camera.addTrauma(tuning.explosionTrauma)

            case .playerHit:
                hurtFlash = 1
                audio.play(.playerHurt)
                camera.addTrauma(tuning.playerHitTrauma)
                pendingHitStop = max(pendingHitStop, tuning.playerHitStop)
                playHaptic(.majorDamage, last: &lastHurtHaptic)

            case .playerDodged:
                effects.floatingText("Dodge", at: playerPosition, color: UIColor(rgb: 0xC8E0FF), size: 15,
                                     lifetime: 0.7)
                audio.play(.dodge)

            case .playerHealed(let amount):
                effects.floatingText("+\(Int(amount.rounded()))", at: playerPosition, color: UIColor(rgb: 0x8FE07A),
                                     size: 15, lifetime: 0.8)
                audio.play(.heal)

            case .barrierGained:
                effects.ring(at: playerPosition, radius: 1.1, color: UIColor(rgb: 0x8FD0FF), lifetime: 0.4)
                audio.play(.heal)

            case .stealthStarted:
                effects.burst(at: playerPosition, radius: 1.2, color: UIColor(rgb: 0x3A2A4A), glows: false)
                audio.play(.abilityShadow)

            case .formChanged:
                effects.burst(at: playerPosition, radius: 1.6, color: VisualStyle.nature.color)
                effects.motes(at: playerPosition, count: 10, color: VisualStyle.nature.color, spread: 0.6)
                audio.play(.shapeshift)

            case .cheatedDeath:
                levelFlash = 1
                effects.levelUp(at: playerPosition, radius: 3)
                effects.floatingText("Fate Defied", at: playerPosition, color: VisualStyle.fate.color, size: 20,
                                     lifetime: 1.4)
                audio.play(.levelUp)
                haptics.play(.levelUp)
                camera.addTrauma(tuning.levelUpTrauma)

            case .experienceCollected:
                let now = CACurrentMediaTime()
                emberCombo = now - lastEmberTime < tuning.emberComboWindow ? min(emberCombo + 1, 4) : 0
                lastEmberTime = now
                audio.play(SoundCue.emberChimes[emberCombo])

            case let .shrineAppeared(kind, position):
                effects.ring(at: position, radius: 2.2, color: ShrineRenderer.tint(for: kind), lifetime: 0.9)
                effects.floatingText("A shrine stirs", at: playerPosition, color: ShrineRenderer.tint(for: kind),
                                     size: 15, lifetime: 1.6)
                audio.play(.abilityShadow)

            case let .riftOpened(kind, position):
                let tint = UIColor(rgb: kind.tint)
                effects.ring(at: position, radius: 3, color: tint, lifetime: 1.2)
                effects.motes(at: position, count: 18, color: tint, spread: 1.6)
                effects.floatingText("A rift opens", at: playerPosition, color: tint, size: 17, lifetime: 2.2)
                camera.addTrauma(0.35)
                audio.play(.abilityShadow)

            case let .riftEntered(kind):
                effects.floatingText(kind.name, at: playerPosition, color: UIColor(rgb: kind.tint), size: 20,
                                     lifetime: 2.4)
                camera.addTrauma(1.0)
                haptics.play(.criticalHit)
                audio.play(.abilityImpact)

            case let .shrineUsed(kind, position):
                let tint = ShrineRenderer.tint(for: kind)
                effects.ring(at: position, radius: 2.6, color: tint, lifetime: 0.8)
                effects.motes(at: position, count: 16, color: tint, spread: 1.2)
                effects.floatingText(kind.name, at: playerPosition, color: tint, size: 17, lifetime: 1.5)
                audio.play(kind == .ruin ? .abilityShadow : .abilityHoly)
                if kind == .ruin {
                    camera.addTrauma(tuning.explosionTrauma)
                }

            case let .dropCollected(kind, position):
                switch kind {
                case .vial:
                    effects.ring(at: position, radius: 1.0, color: UIColor(rgb: 0xE0505A), lifetime: 0.5)
                    effects.floatingText("Draught", at: playerPosition, color: UIColor(rgb: 0xFF9AA0), size: 15,
                                         lifetime: 0.9)
                    audio.play(.heal)
                case .magnet:
                    effects.ring(at: position, radius: 2.4, color: UIColor(rgb: 0xE8C25A), lifetime: 0.6)
                    effects.floatingText("Magnet", at: playerPosition, color: UIColor(rgb: 0xF0D58A), size: 15,
                                         lifetime: 0.9)
                    audio.play(SoundCue.emberChimes[4])
                case .chest(let tier):
                    effects.ring(at: position, radius: 1.6, color: Self.tierColor(tier), lifetime: 0.7)
                    effects.motes(at: position, count: 12, color: Self.tierColor(tier), spread: 0.8)
                    audio.play(.skillTreeOpen)
                }

            case let .weaponWielded(title, rarity):
                let color = rarity.color.uiColor
                effects.ring(at: playerPosition, radius: 1.6, color: color, lifetime: 0.7)
                effects.floatingText(title, at: playerPosition, color: color, size: 17, lifetime: 1.8)
                audio.play(.skillLearn)
                if rarity >= .epic {
                    haptics.play(.legendaryItem)
                }

            case let .relicGained(id, rank):
                guard let relic = RelicCatalog.relic(id) else { break }
                let color = relic.rarity.color.uiColor
                effects.ring(at: playerPosition, radius: 1.4, color: color, lifetime: 0.6)
                effects.floatingText(relic.title(atRank: rank), at: playerPosition, color: color, size: 17,
                                     lifetime: 1.6)
                audio.play(.skillLearn)
                if relic.rarity >= .epic {
                    haptics.play(.legendaryItem)
                }

            case let .levelUp(level, position):
                levelFlash = 1
                effects.levelUp(at: position, radius: levelUpRadius)
                effects.floatingText("Level \(level)", at: position, color: VisualStyle.fate.color, size: 22,
                                     lifetime: 1.4)
                player.playLevelUp()
                audio.play(.levelUp)
                haptics.play(.levelUp)
                camera.addTrauma(tuning.levelUpTrauma)

            case .playerDefeated:
                hurtFlash = 1
                audio.play(.playerDeath)
                if !isParty {
                    audio.playMusic(.musicDefeat, fadeDuration: 0.6, loops: false)
                    audio.stopAmbience(fadeDuration: 2)
                }
                camera.addTrauma(tuning.deathTrauma)
                haptics.play(.playerDeath)

            case let .heroFell(_, position):
                effects.ring(at: position, radius: 1.5, color: UIColor(rgb: 0xC8B4E8), lifetime: 0.9)
                effects.burst(at: position, radius: 1.0, color: UIColor(rgb: 0x3A2A4A), glows: false)

            case .reviveStarted:
                audio.play(.uiConfirm)

            case .reviveInterrupted:
                audio.play(.uiBack)

            case let .heroRevived(_, position):
                effects.ring(at: position, radius: 1.8, color: UIColor(rgb: 0x8FE07A), lifetime: 0.8)
                effects.motes(at: position, count: 14, color: UIColor(rgb: 0xB8F0A0), spread: 0.8)
                effects.floatingText("Revived", at: position, color: UIColor(rgb: 0xB8F0A0), size: 18, lifetime: 1.4)
                audio.play(.skillLearn)
            }
        }
        if hits > 0 {
            audio.play(.hit)
        }

        riftLevel += ((riftKind == nil ? 0 : 1) - riftLevel) * min(1, dt * 2)
        riftTint.alpha = riftLevel * 0.5

        // The edge flash fades quickly, but never below a faint pulse when
        // health is low.
        hurtFlash = max(0, hurtFlash - dt * 2.4)
        let danger: CGFloat = lowHealth ? 0.28 + 0.12 * CGFloat(sin(CACurrentMediaTime() * 4)) : 0
        damageFlash.alpha = max(hurtFlash * 0.9, danger)
        levelFlash = max(0, levelFlash - dt * 1.3)
        fateFlash.alpha = levelFlash * 0.75
    }

    private static func tierColor(_ tier: LootTier) -> UIColor {
        switch tier {
        case .cache: return ItemRarity.common.color.uiColor
        case .chest: return ItemRarity.rare.color.uiColor
        case .hoard, .rift: return ItemRarity.legendary.color.uiColor
        }
    }

    private func playHaptic(_ event: HapticEvent, last: inout TimeInterval) {
        let now = CACurrentMediaTime()
        guard now - last >= tuning.hapticInterval else { return }
        last = now
        haptics.play(event)
    }
}
