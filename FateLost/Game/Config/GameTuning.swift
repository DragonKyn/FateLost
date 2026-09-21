import CoreGraphics
import Foundation

/// Central home for feel-and-presentation tuning that is not realm content.
///
/// Values are grouped per system and injected, so tests can build systems
/// with their own numbers and balance passes never touch gameplay logic.
/// Every group is a plain value type, ready to load from JSON later.
struct GameTuning {
    var simulation = SimulationTuning()
    var player = PlayerTuning()
    var combat = CombatTuning()
    var spawning = SpawnTuning()
    var enemyAI = EnemyAITuning()
    var progression = ProgressionTuning()
    var camera = CameraTuning()
    var projection = ProjectionTuning()
    var controls = ControlsTuning()
    var rendering = RenderingTuning()
    var party = PartyTuning()

    static let standard = GameTuning()
}

struct SimulationTuning {
    /// Fixed simulation step.
    var timestep: TimeInterval = 1.0 / 60.0
    /// Upper bound on catch-up steps after a hitch.
    var maxStepsPerFrame: Int = 5
}

struct PlayerTuning {
    /// World units (tiles) per second before any modifiers.
    var baseMoveSpeed: CGFloat = 4.2
    /// Tiles per second squared when speeding up.
    var acceleration: CGFloat = 38
    /// Tiles per second squared when releasing the stick. Higher than
    /// acceleration so stopping feels crisp and dodges are precise.
    var deceleration: CGFloat = 55
    var baseMaxHealth: Double = 100
    /// Exponential decay rate of knockback on the player, per second.
    var knockbackDecay: CGFloat = 11
    /// Passive regeneration (what the build, the Legacy board and gear give,
    /// not a timed aura) counts in full up to this share of max health a
    /// second. Past it each further point counts for less and less, so a
    /// second regeneration source still helps, but stacking every one cannot
    /// make a hero unkillable.
    var regenKneeFraction: Double = 0.03
    /// The most passive regeneration can ever reach, as a share of max health
    /// a second: what any pile of sources approaches and never passes.
    var regenCeilingFraction: Double = 0.06

    /// What `raw` health per second of passive regeneration is worth to a hero
    /// with `maxHealth`: the same up to the knee, then an ever slower climb
    /// toward the ceiling.
    func effectiveRegeneration(_ raw: Double, maxHealth: Double) -> Double {
        guard raw > 0, maxHealth > 0 else { return max(0, raw) }
        let knee = maxHealth * regenKneeFraction
        guard raw > knee else { return raw }
        let room = maxHealth * (regenCeilingFraction - regenKneeFraction)
        guard room > 0 else { return knee }
        return knee + room * (1 - exp(-(raw - knee) / room))
    }
}

struct CombatTuning {
    /// World-unit radius of the player's body for enemy contact.
    var playerRadius: CGFloat = 0.34
    /// Seconds of immunity after the player is hit, so a crowd can't land
    /// every blow in the same instant.
    var invulnerabilityDuration: Double = 0.6
    /// Speed the player is shoved at when hit, in world units per second.
    var playerKnockbackSpeed: CGFloat = 6
    /// Exponential decay rate of knockback on enemies, per second. Higher
    /// stops sooner.
    var knockbackDecay: CGFloat = 11
    /// Speed an enemy is shoved at by a full-strength weapon hit.
    var weaponKnockbackSpeed: CGFloat = 6.5
    var critChance: Double = 0.05
    var critMultiplier: Double = 1.75
    /// Each hit rolls within ±this fraction of its base damage, so numbers
    /// don't repeat identically.
    var damageVariance: Double = 0.12
    /// Extra reach beyond the weapon range when choosing a melee target, so
    /// the swing starts as an enemy steps in rather than after it arrives.
    var meleeAcquireSlack: CGFloat = 0.25
    /// Enemies closer than this are hit by a melee swing whatever its arc,
    /// so nothing standing on top of the player is missed.
    var meleePointBlank: CGFloat = 0.55
    /// How far a healing or shielding ability's blessing reaches to the
    /// caster's party, in world units, before area size.
    var supportRadius: CGFloat = 6
}

struct SpawnTuning {
    /// Quiet seconds at the start of a run to get your bearings.
    var initialDelay: Double = 2
    /// Enemies per second at the start.
    var baseRate: Double = 0.7
    /// Added to the rate every minute.
    var rateGrowthPerMinute: Double = 0.55
    var maximumRate: Double = 9
    /// Natural spawning stops at this many living enemies. Developer
    /// spawning can go past it, up to `EnemyAITuning.hardCap`.
    var maximumAlive: Int = 300
    /// Distance from the player enemies appear at. The scene raises it to
    /// just beyond the visible area of the actual screen.
    var spawnRadius: CGFloat = 12
    /// Share of spawns placed ahead of a moving player, so running in one
    /// direction doesn't leave the horde behind.
    var aheadBias: Double = 0.4
    var aheadConeDegrees: Double = 70
    /// Enemies left this far behind are moved back to the spawn ring.
    var recycleDistance: CGFloat = 22
}

struct EnemyAITuning {
    /// Hard ceiling on living enemies, including developer spawns.
    var hardCap: Int = 800
    /// Speed, in world units per second per unit of overlap, at which
    /// crowded enemies push apart.
    var separationStrength: CGFloat = 5
    /// Separation is recomputed for one of this many groups each tick, so
    /// its cost is spread across frames.
    var separationGroups: Int = 2
    /// Spatial grid cell size in world units.
    var gridCellSize: CGFloat = 1.5
    /// Fraction of normal speed an enemy moves at while winding up a strike.
    var windupSpeedFactor: CGFloat = 0.25
    /// Enemies vary their speed by up to ± this fraction so crowds don't
    /// march in lockstep.
    var speedVariance: CGFloat = 0.12
}

/// Experience, levels and the pace at which the player and the horde grow.
struct ProgressionTuning {
    /// Experience to reach level 2.
    var baseRequirement: Double = 14
    /// Added per level to the requirement.
    var linearGrowth: Double = 11
    /// Added per level squared, so late levels take a little longer.
    var quadraticGrowth: Double = 0.3
    /// Weapon and skill damage gained per level. Everyone gets stronger with
    /// levels whatever they pick, so points buy new ways to fight rather
    /// than the baseline needed to keep up.
    var damageGrowthPerLevel: Double = 0.07
    var healthPerLevel: Double = 4
    /// Fraction of max health restored on levelling up.
    var levelUpHeal: Double = 0.15

    /// The burst of fate energy released on levelling up.
    var levelUpBurstRadius: CGFloat = 4.2
    /// As a multiple of skill power.
    var levelUpBurstPower: Double = 3
    var levelUpBurstKnockback: CGFloat = 3.4
    var levelUpImmunity: Double = 1

    /// Enemy health multiplier grows by this per minute…
    var enemyHealthPerMinute: Double = 0.1
    /// …and this per minute squared.
    var enemyHealthPerMinuteSquared: Double = 0.012
    var enemyDamagePerMinute: Double = 0.05

    /// Experience needed to go from `level` to the next.
    func requirement(toAdvanceFrom level: Int) -> Int {
        let steps = Double(max(level, 1) - 1)
        return Int((baseRequirement + linearGrowth * steps + quadraticGrowth * steps * steps).rounded())
    }
}

struct CameraTuning {
    /// How quickly the camera closes on its target; higher is tighter.
    var followSharpness: CGFloat = 7.5
    /// World units the camera leads ahead of the player at full speed.
    var lookAhead: CGFloat = 1.1
    /// How quickly the lead responds to direction changes.
    var lookAheadSharpness: CGFloat = 3
    /// Screen height, in scene points, the camera aims to show. The scale is
    /// derived from the device so an iPhone and an iPad frame similar space.
    var targetVisibleHeight: CGFloat = 470
    var minimumScale: CGFloat = 0.72
    var maximumScale: CGFloat = 1.45
    /// Trauma lost per second; shake intensity is trauma squared.
    var shakeDecay: CGFloat = 1.6
    /// Offset in scene points at full trauma.
    var shakeMaxOffset: CGFloat = 16
    var shakeFrequency: CGFloat = 28
}

struct ProjectionTuning {
    /// On-screen size of one ground tile diamond, in scene points.
    var tileWidth: CGFloat = 80
    var tileHeight: CGFloat = 40
}

struct ControlsTuning {
    /// Knob travel from base centre, in points, before scaling for device.
    var joystickRadius: CGFloat = 58
    /// Fraction of travel ignored around the centre.
    var joystickDeadZone: CGFloat = 0.12
    /// Fraction of the screen width, from the left, that summons the stick.
    var joystickZoneWidthFraction: CGFloat = 0.5
    /// When the thumb drags past the rim, the base follows it this far behind,
    /// so reversing direction never needs a long drag back.
    var joystickFollowsThumb: Bool = true
    var abilityButtonSize: CGFloat = 62
    var ultimateButtonSize: CGFloat = 82
    /// Controls are designed on a 390pt-tall phone and scaled up to this
    /// factor on larger screens.
    var referenceScreenHeight: CGFloat = 390
    var maximumControlScale: CGFloat = 1.45
    /// Minimum distance from any screen edge after safe-area insets.
    var edgeMargin: CGFloat = 22
}

struct RenderingTuning {
    /// Extra world units around the visible area in which decorations are
    /// kept live, so they are in place before they scroll into view.
    var decorationMargin: CGFloat = 3
    /// Once the unwrapped camera focus drifts this many arena sizes from the
    /// origin, it is shifted back to preserve floating-point precision.
    var rebaseThresholdPeriods: CGFloat = 4
    var preferredFramesPerSecond: Int = 60
}
