import Foundation

/// An end-game toggle: a way to make a conquered realm harder on purpose, for
/// more echoes back. None of them unlock anything or change a rule the
/// player hasn't already beaten once — they only turn a knob the realm
/// already had.
enum DifficultyModifierID: String, CaseIterable, Codable, Hashable, Identifiable {
    case extraElites
    case elitist
    case reinforcedEnemies
    case dontStop
    case berserkerFoes
    case viciousFoes
    case glassCannon
    case ironLung
    case noSecondWind
    case swarm
    case closingIn
    case bloodthirstyBosses
    case thinIce
    case slowRecovery

    var id: String { rawValue }
}

/// One modifier's fixed identity: what it's called, how it reads, and the
/// echo bonus it is worth. `reinforcedEnemies` is the only one with a range
/// to choose within; every other modifier is a plain toggle, so its minimum
/// and maximum bonus are the same number.
struct DifficultyModifierDefinition: Identifiable {
    let id: DifficultyModifierID
    let name: String
    let tagline: String
    let hasIntensity: Bool
    let echoBonusAtMinimum: Double
    let echoBonusAtMaximum: Double
}

/// One modifier a player has switched on for a realm, with its intensity if
/// it has one. Persisted per realm in `RealmProgress`.
struct RunModifierSelection: Codable, Equatable, Hashable {
    var id: DifficultyModifierID
    /// 0...1 for a modifier with `hasIntensity`; ignored otherwise.
    var intensity: Double = 0
}

/// Every numeric effect a run's chosen modifiers add up to, folded into one
/// place so the systems that care (spawning, enemy scaling, the player's
/// stat sheet) read a single plain value instead of walking the modifier
/// list themselves.
struct DifficultyModifierEffects: Equatable {
    /// Extra fraction of health every enemy in the realm carries, from
    /// Reinforced Enemies.
    var enemyHealthBonus: Double = 0
    /// Extra fraction of damage every enemy in the realm deals, from
    /// Vicious Foes.
    var enemyDamageBonus: Double = 0
    /// Extra fraction of move speed ordinary enemies spawn with, from
    /// Berserker Foes.
    var enemyMoveSpeedBonus: Double = 0
    /// Extra fraction of damage the player takes, from Glass Cannon.
    var playerDamageTakenBonus: Double = 0
    /// Extra fraction on the spawner's rate, from Swarm.
    var spawnRateBonus: Double = 0
    /// How much closer the spawn ring is pulled, 0...1, from Closing In.
    var spawnRadiusFraction: Double = 0
    /// Extra fraction of health a realm's champions carry, on top of
    /// `enemyHealthBonus`, from Bloodthirsty Bosses.
    var championHealthBonus: Double = 0
    /// How many rare elites may be alive together, from Extra Elites.
    var maxSimultaneousElites: Int = 1
    /// Extra fraction added to a rare elite's own spawn weight, from Elitist.
    var eliteWeightBonus: Double = 0
    /// Whether an elite-related modifier is active, so a realm too early for
    /// rare elites fields them anyway.
    var includesRareElites = false
    /// Whether Don't Stop is active this run.
    var dontStopEnabled = false
    /// The summed echo payout bonus of everything switched on.
    var payoutBonus: Double = 0
    /// Stat changes some modifiers apply straight to the player, folded in
    /// with the Legacy board's own bonuses.
    var extraStatModifiers: [StatModifier] = []
}

/// Tuning for the modifiers that don't reduce to a single stat or scale.
enum DifficultyModifierTuning {
    /// Seconds a player may stand still before Don't Stop starts ticking.
    static let dontStopGraceSeconds: Double = 2
    /// Seconds between each Don't Stop tick once the grace has passed.
    static let dontStopTickInterval: Double = 1
    /// Fraction of max health each Don't Stop tick costs.
    static let dontStopDamageFraction: Double = 0.05
}

enum DifficultyModifierCatalog {
    static let all: [DifficultyModifierDefinition] = [
        DifficultyModifierDefinition(
            id: .extraElites, name: "Extra Elites",
            tagline: "More than one rare elite can be alive at once.",
            hasIntensity: false, echoBonusAtMinimum: 0.08, echoBonusAtMaximum: 0.08),
        DifficultyModifierDefinition(
            id: .elitist, name: "Elitist",
            tagline: "Rare elites come around more often than they used to.",
            hasIntensity: false, echoBonusAtMinimum: 0.06, echoBonusAtMaximum: 0.06),
        DifficultyModifierDefinition(
            id: .reinforcedEnemies, name: "Reinforced Enemies",
            tagline: "Every enemy in the realm carries more health into the fight.",
            hasIntensity: true, echoBonusAtMinimum: 0.02, echoBonusAtMaximum: 0.20),
        DifficultyModifierDefinition(
            id: .dontStop, name: "Don't Stop",
            tagline: "Stand still too long and the realm makes you regret it.",
            hasIntensity: false, echoBonusAtMinimum: 0.06, echoBonusAtMaximum: 0.06),
        DifficultyModifierDefinition(
            id: .berserkerFoes, name: "Berserker Foes",
            tagline: "Everything in the realm moves like it's already angry.",
            hasIntensity: false, echoBonusAtMinimum: 0.07, echoBonusAtMaximum: 0.07),
        DifficultyModifierDefinition(
            id: .viciousFoes, name: "Vicious Foes",
            tagline: "Every hit from the horde lands harder than it should.",
            hasIntensity: false, echoBonusAtMinimum: 0.10, echoBonusAtMaximum: 0.10),
        DifficultyModifierDefinition(
            id: .glassCannon, name: "Glass Cannon",
            tagline: "You hit harder. So does everything else.",
            hasIntensity: false, echoBonusAtMinimum: 0.09, echoBonusAtMaximum: 0.09),
        DifficultyModifierDefinition(
            id: .ironLung, name: "Iron Lung",
            tagline: "Healing finds you half as often as it used to.",
            hasIntensity: false, echoBonusAtMinimum: 0.06, echoBonusAtMaximum: 0.06),
        DifficultyModifierDefinition(
            id: .noSecondWind, name: "No Second Wind",
            tagline: "Whatever mended you on its own no longer does.",
            hasIntensity: false, echoBonusAtMinimum: 0.05, echoBonusAtMaximum: 0.05),
        DifficultyModifierDefinition(
            id: .swarm, name: "Swarm",
            tagline: "The realm doesn't wait between arrivals.",
            hasIntensity: false, echoBonusAtMinimum: 0.09, echoBonusAtMaximum: 0.09),
        DifficultyModifierDefinition(
            id: .closingIn, name: "Closing In",
            tagline: "The ring the horde appears on is pulled in tight.",
            hasIntensity: false, echoBonusAtMinimum: 0.07, echoBonusAtMaximum: 0.07),
        DifficultyModifierDefinition(
            id: .bloodthirstyBosses, name: "Bloodthirsty Bosses",
            tagline: "Every champion the realm sends is a harder fight than it was.",
            hasIntensity: false, echoBonusAtMinimum: 0.08, echoBonusAtMaximum: 0.08),
        DifficultyModifierDefinition(
            id: .thinIce, name: "Thin Ice",
            tagline: "Whatever used to let you slip a hit, doesn't anymore.",
            hasIntensity: false, echoBonusAtMinimum: 0.07, echoBonusAtMaximum: 0.07),
        DifficultyModifierDefinition(
            id: .slowRecovery, name: "Slow Recovery",
            tagline: "Everything you cast comes back to you slower.",
            hasIntensity: false, echoBonusAtMinimum: 0.05, echoBonusAtMaximum: 0.05),
    ]

    private static let byID: [DifficultyModifierID: DifficultyModifierDefinition] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func definition(_ id: DifficultyModifierID) -> DifficultyModifierDefinition {
        // Every case in `DifficultyModifierID` has an entry above; covered by
        // `testEveryModifierHasACatalogEntry`.
        byID[id]!
    }

    /// The echo bonus one selection is worth: fixed for a toggle, interpolated
    /// by `intensity` for a modifier that has a range.
    static func payoutBonus(for selection: RunModifierSelection) -> Double {
        let definition = definition(selection.id)
        guard definition.hasIntensity else { return definition.echoBonusAtMinimum }
        let t = min(1, max(0, selection.intensity))
        return definition.echoBonusAtMinimum + (definition.echoBonusAtMaximum - definition.echoBonusAtMinimum) * t
    }

    /// Folds a run's chosen modifiers into the single set of numbers the
    /// simulation reads from.
    static func effects(for selections: [RunModifierSelection]) -> DifficultyModifierEffects {
        var effects = DifficultyModifierEffects()
        for selection in selections {
            let t = min(1, max(0, selection.intensity))
            switch selection.id {
            case .extraElites:
                effects.maxSimultaneousElites = max(effects.maxSimultaneousElites, 2)
                effects.includesRareElites = true
            case .elitist:
                effects.eliteWeightBonus += 0.12
                effects.includesRareElites = true
            case .reinforcedEnemies:
                effects.enemyHealthBonus += 0.5 + t * 2.0
            case .dontStop:
                effects.dontStopEnabled = true
            case .berserkerFoes:
                effects.enemyMoveSpeedBonus += 0.2
            case .viciousFoes:
                effects.enemyDamageBonus += 0.25
            case .glassCannon:
                effects.playerDamageTakenBonus += 0.2
                effects.extraStatModifiers.append(StatModifier(.damage, .increased, 0.2))
            case .ironLung:
                effects.extraStatModifiers.append(StatModifier(.healingReceived, .increased, -0.5))
            case .noSecondWind:
                effects.extraStatModifiers.append(StatModifier(.healthRegen, .more, -1))
            case .swarm:
                effects.spawnRateBonus += 0.2
            case .closingIn:
                effects.spawnRadiusFraction = min(0.9, effects.spawnRadiusFraction + 0.2)
            case .bloodthirstyBosses:
                effects.championHealthBonus += 0.4
            case .thinIce:
                effects.extraStatModifiers.append(StatModifier(.dodgeChance, .flat, -1))
            case .slowRecovery:
                effects.extraStatModifiers.append(StatModifier(.cooldownReduction, .flat, -0.05))
            }
            effects.payoutBonus += payoutBonus(for: selection)
        }
        return effects
    }
}
