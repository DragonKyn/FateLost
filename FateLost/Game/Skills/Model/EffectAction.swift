import CoreGraphics
import Foundation

typealias FormID = String

/// Where an effect is centred.
enum ActionAnchor: Equatable {
    /// On the player.
    case player
    /// Where the trigger happened: the enemy struck or killed, or the player
    /// for abilities and timed effects.
    case origin
    /// On the densest group of enemies near the player.
    case cluster
}

/// Damage an effect deals, as a multiple of skill power.
///
/// Skill power grows with character level (see `SkillPower`), so every
/// skill keeps pace with the run whenever it was learned. That's deliberate:
/// taking a skill early is never a trap, and no rigid pick order is needed to
/// stay competitive.
struct DamageSpec: Equatable {
    var power: RankValue
    var type: DamageType
    var tags: TagMask
    /// Fraction of standard knockback.
    var knockback: CGFloat
    /// Extra critical chance for this damage.
    var critBonus: Double

    init(_ power: RankValue, _ type: DamageType, tags: TagMask = [], knockback: CGFloat = 0.5,
         critBonus: Double = 0) {
        self.power = power
        self.type = type
        self.tags = tags
        self.knockback = knockback
        self.critBonus = critBonus
    }

    func resolved(_ rank: Int) -> DamageSpec {
        DamageSpec(power.resolved(rank), type, tags: tags, knockback: knockback, critBonus: critBonus)
    }
}

/// A stat change whose size depends on rank.
struct ModifierSpec: Equatable {
    var stat: StatID
    var kind: ModifierKind
    var value: RankValue

    init(_ stat: StatID, _ kind: ModifierKind, _ value: RankValue) {
        self.stat = stat
        self.kind = kind
        self.value = value
    }

    func at(_ rank: Int) -> StatModifier {
        StatModifier(stat, kind, value.at(rank))
    }
}

/// Damage (and optionally a status) to everything within a radius.
struct NovaSpec: Equatable {
    var radius: RankValue
    var damage: DamageSpec?
    var status: StatusApplication?
    var anchor: ActionAnchor = .player
    var visual: VisualStyle

    func resolved(_ rank: Int) -> NovaSpec {
        NovaSpec(radius: radius.resolved(rank), damage: damage?.resolved(rank), status: status?.resolved(rank),
                 anchor: anchor, visual: visual)
    }
}

/// Damage in a wedge in front of the player, toward the nearest enemy.
struct ConeSpec: Equatable {
    var range: RankValue
    var arcDegrees: Double
    var damage: DamageSpec
    var status: StatusApplication?
    var visual: VisualStyle

    func resolved(_ rank: Int) -> ConeSpec {
        ConeSpec(range: range.resolved(rank), arcDegrees: arcDegrees, damage: damage.resolved(rank),
                 status: status?.resolved(rank), visual: visual)
    }
}

/// Damage leaping from enemy to enemy.
struct ChainSpec: Equatable {
    var jumps: RankValue
    /// Furthest a single leap can reach.
    var range: CGFloat = 3.5
    var damage: DamageSpec
    var status: StatusApplication?
    var visual: VisualStyle

    func resolved(_ rank: Int) -> ChainSpec {
        ChainSpec(jumps: jumps.resolved(rank), range: range, damage: damage.resolved(rank),
                  status: status?.resolved(rank), visual: visual)
    }
}

enum VolleyPattern: Equatable {
    /// A fan toward the nearest enemy.
    case aimed(spreadDegrees: Double)
    /// Evenly around the player.
    case radial
}

/// Projectiles launched from the player (or the trigger point).
struct VolleySpec: Equatable {
    var count: RankValue
    var pattern: VolleyPattern
    var damage: DamageSpec
    var speed: CGFloat = 12
    var pierce: Int = 0
    var splash: CGFloat = 0
    /// Body radius of each projectile.
    var size: CGFloat = 0.2
    /// How far the projectiles fly.
    var range: CGFloat = 8
    var status: StatusApplication?
    var sprite: SpriteID = .projectileBolt
    var anchor: ActionAnchor = .player
    var visual: VisualStyle

    func resolved(_ rank: Int) -> VolleySpec {
        var copy = self
        copy.count = count.resolved(rank)
        copy.damage = damage.resolved(rank)
        copy.status = status?.resolved(rank)
        return copy
    }
}

/// Impacts from above after a short warning: arrow rain, meteors, pillars
/// of light.
struct StrikeSpec: Equatable {
    var count: RankValue
    var radius: RankValue
    /// Impacts land within this distance of the anchor.
    var scatter: CGFloat
    /// Seconds between the warning and the impact.
    var delay: Double = 0.45
    /// Impacts seek out individual enemies near the anchor where possible.
    var seeksEnemies: Bool = true
    var damage: DamageSpec
    var status: StatusApplication?
    var anchor: ActionAnchor = .cluster
    var visual: VisualStyle

    func resolved(_ rank: Int) -> StrikeSpec {
        var copy = self
        copy.count = count.resolved(rank)
        copy.radius = radius.resolved(rank)
        copy.damage = damage.resolved(rank)
        copy.status = status?.resolved(rank)
        return copy
    }
}

/// A lasting area: consecrated ground, a blizzard, an aura that follows you.
struct ZoneSpec: Equatable {
    var radius: RankValue
    /// Seconds it lasts. Zero or less means permanent (auras from passives).
    var duration: RankValue
    /// Seconds between pulses.
    var tick: Double = 0.5
    var damage: DamageSpec?
    var status: StatusApplication?
    /// Speed enemies are drawn toward the centre.
    var pull: CGFloat = 0
    /// When above zero, each pulse strikes only this many random enemies
    /// inside (lightning from a storm) rather than all of them.
    var strikesPerTick: Int = 0
    /// Stat changes the player enjoys while inside.
    var playerBuff: [ModifierSpec] = []
    /// Moves with the player.
    var follows: Bool = false
    var anchor: ActionAnchor = .player
    var visual: VisualStyle

    func resolved(_ rank: Int) -> ZoneSpec {
        var copy = self
        copy.radius = radius.resolved(rank)
        copy.duration = duration.resolved(rank)
        copy.damage = damage?.resolved(rank)
        copy.status = status?.resolved(rank)
        copy.playerBuff = playerBuff.map { ModifierSpec($0.stat, $0.kind, $0.value.resolved(rank)) }
        return copy
    }
}

enum AllyBehavior: Equatable {
    /// Runs at enemies and strikes in melee.
    case melee(range: CGFloat)
    /// Keeps near the player and shoots.
    case ranged(range: CGFloat, projectileSpeed: CGFloat, sprite: SpriteID)
    /// Circles the player, striking whatever it touches.
    case orbit(radius: CGFloat, angularSpeed: CGFloat)
}

/// A minion, companion or orbiting blade.
struct SummonSpec: Equatable {
    /// Identifies the kind for renderers and for keeping companion counts.
    var key: String
    var name: String
    var sprite: SpriteID
    var tint: RGBA?
    var scale: CGFloat = 1
    var behavior: AllyBehavior
    var damage: DamageSpec
    /// Seconds between attacks.
    var attackInterval: Double = 1
    var moveSpeed: CGFloat = 4
    var radius: CGFloat = 0.3
    /// Radius of the area each attack strikes; zero hits one enemy.
    var splash: CGFloat = 0
    /// Nearby enemies turn on it instead of the player.
    var taunts: Bool = false
    var status: StatusApplication?
    var count: RankValue = 1
    /// Seconds it lasts. Zero or less means it stays (companions).
    var duration: RankValue = 0
    var visual: VisualStyle = .physical
    /// Alternative looks, one picked per ally so a horde isn't identical.
    /// Empty means always `sprite`.
    var variants: [SpriteID] = []
    /// Toughness, as a multiple of a footsoldier's life (see
    /// `SummonVitality`). Zero means it cannot be hurt at all: conjured
    /// blades and orbs have no body to cut.
    var vitality: Double = 0
    /// Seconds a fallen companion of this kind stays gone before it can be
    /// called back. Heavier things take longer to rebuild.
    var resummonCooldown: Double = 8

    /// Whether enemies can hurt it.
    var isMortal: Bool { vitality > 0 }

    /// The look for one particular ally.
    func sprite(forAlly id: Int) -> SpriteID {
        variants.isEmpty ? sprite : variants[id % variants.count]
    }

    func resolved(_ rank: Int) -> SummonSpec {
        var copy = self
        copy.damage = damage.resolved(rank)
        copy.status = status?.resolved(rank)
        copy.count = count.resolved(rank)
        copy.duration = duration.resolved(rank)
        return copy
    }
}

/// A temporary boost to the player's stats.
struct BuffSpec: Equatable {
    var id: String
    var modifiers: [ModifierSpec]
    var duration: RankValue
    var maxStacks: Int = 1

    func resolved(_ rank: Int) -> BuffSpec {
        BuffSpec(id: id, modifiers: modifiers.map { ModifierSpec($0.stat, $0.kind, $0.value.resolved(rank)) },
                 duration: duration.resolved(rank), maxStacks: maxStacks)
    }
}

/// A burst of movement, optionally damaging everything passed through.
struct DashSpec: Equatable {
    var distance: RankValue
    var damage: DamageSpec?
    var status: StatusApplication?
    /// Seconds of immunity granted.
    var invulnerability: Double = 0.25
    var visual: VisualStyle

    func resolved(_ rank: Int) -> DashSpec {
        DashSpec(distance: distance.resolved(rank), damage: damage?.resolved(rank), status: status?.resolved(rank),
                 invulnerability: invulnerability, visual: visual)
    }
}

/// Something a skill makes happen: the shared vocabulary of abilities and
/// procs. Every active ability and triggered effect in the game is built
/// from these, which is what keeps hundreds of skills data rather than code.
indirect enum EffectAction: Equatable {
    case nova(NovaSpec)
    case cone(ConeSpec)
    case chain(ChainSpec)
    case volley(VolleySpec)
    case strikes(StrikeSpec)
    case zone(ZoneSpec)
    case summon(SummonSpec)
    case buff(BuffSpec)
    /// A barrier worth this fraction of max health.
    case barrier(RankValue)
    /// Heals this fraction of max health.
    case heal(RankValue)
    /// Costs this fraction of current health. Never lethal.
    case selfDamage(RankValue)
    /// Seconds of immunity.
    case invulnerable(RankValue)
    case dash(DashSpec)
    /// Seconds of stealth: enemies lose track of you and every hit is a
    /// critical.
    case stealth(RankValue)
    /// Takes on a form, or leaves it if already in it.
    case transform(FormID)
    /// A status on the target (radius zero) or everything around the origin.
    case afflict(StatusApplication, radius: RankValue)
    /// Draws enemies toward the origin.
    case pull(radius: RankValue, strength: CGFloat)
    /// Takes this many seconds off every ability cooldown.
    case reduceCooldowns(RankValue)
    /// One of these, chosen at random.
    case random([EffectAction])
    /// All of these, in order.
    case all([EffectAction])

    func resolved(_ rank: Int) -> EffectAction {
        switch self {
        case .nova(let spec): return .nova(spec.resolved(rank))
        case .cone(let spec): return .cone(spec.resolved(rank))
        case .chain(let spec): return .chain(spec.resolved(rank))
        case .volley(let spec): return .volley(spec.resolved(rank))
        case .strikes(let spec): return .strikes(spec.resolved(rank))
        case .zone(let spec): return .zone(spec.resolved(rank))
        case .summon(let spec): return .summon(spec.resolved(rank))
        case .buff(let spec): return .buff(spec.resolved(rank))
        case .barrier(let value): return .barrier(value.resolved(rank))
        case .heal(let value): return .heal(value.resolved(rank))
        case .selfDamage(let value): return .selfDamage(value.resolved(rank))
        case .invulnerable(let value): return .invulnerable(value.resolved(rank))
        case .dash(let spec): return .dash(spec.resolved(rank))
        case .stealth(let value): return .stealth(value.resolved(rank))
        case .transform(let form): return .transform(form)
        case let .afflict(status, radius): return .afflict(status.resolved(rank), radius: radius.resolved(rank))
        case let .pull(radius, strength): return .pull(radius: radius.resolved(rank), strength: strength)
        case .reduceCooldowns(let value): return .reduceCooldowns(value.resolved(rank))
        case .random(let actions): return .random(actions.map { $0.resolved(rank) })
        case .all(let actions): return .all(actions.map { $0.resolved(rank) })
        }
    }

    /// The look of the action, for cast sounds and flashes.
    var visual: VisualStyle {
        switch self {
        case .nova(let spec): return spec.visual
        case .cone(let spec): return spec.visual
        case .chain(let spec): return spec.visual
        case .volley(let spec): return spec.visual
        case .strikes(let spec): return spec.visual
        case .zone(let spec): return spec.visual
        case .summon(let spec): return spec.visual
        case .dash(let spec): return spec.visual
        case .heal, .barrier, .invulnerable: return .holy
        case .selfDamage: return .blood
        case .stealth: return .shadow
        case .transform: return .nature
        case .afflict(let status, _): return status.kind == .chill || status.kind == .freeze ? .frost : .arcane
        case .pull: return .arcane
        case .buff, .reduceCooldowns: return .fate
        case .random: return .arcane
        case .all(let actions): return actions.first?.visual ?? .physical
        }
    }
}
