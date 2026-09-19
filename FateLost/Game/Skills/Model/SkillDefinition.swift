import CoreGraphics
import Foundation

typealias SkillID = String
typealias AbilityID = String
typealias PathID = String

/// Rows of an archetype's tree. Each needs more points in the archetype;
/// the numbers live in `SkillTreeRules`, not here.
enum SkillTier: Int, CaseIterable, Comparable {
    case one = 1
    case two
    case three
    case four
    case capstone

    static func < (lhs: SkillTier, rhs: SkillTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .one: return "Tier I"
        case .two: return "Tier II"
        case .three: return "Tier III"
        case .four: return "Tier IV"
        case .capstone: return "Capstone"
        }
    }
}

/// How a skill presents in the tree.
enum SkillKind: String, CaseIterable {
    case passive
    case proc
    case active
    case ultimate
    case summon
    case form
    case aura

    var displayName: String {
        switch self {
        case .passive: return "Passive"
        case .proc: return "Trigger"
        case .active: return "Ability"
        case .ultimate: return "Ultimate"
        case .summon: return "Companion"
        case .form: return "Form"
        case .aura: return "Aura"
        }
    }
}

/// An ability the player can equip and trigger from the HUD.
struct AbilityDefinition: Equatable {
    let id: AbilityID
    let name: String
    /// SF Symbol shown on its button.
    let symbol: String
    let cooldown: RankValue
    let isUltimate: Bool
    let action: EffectAction
}

/// A triggered effect: when `trigger` happens (and the conditions hold),
/// roll `chance` and run `action`.
struct ProcSpec: Equatable {
    var trigger: SkillTrigger
    var chance: RankValue = 1
    /// Minimum seconds between activations.
    var cooldown: Double = 0
    /// Only when the enemy involved matches.
    var target: TargetCondition?
    /// Only while the player matches.
    var requires: PlayerCondition?
    var action: EffectAction
}

/// Which direct hits an on-hit effect applies to.
struct HitFilter: Equatable {
    var tags: TagMask = []
    var type: DamageType?

    static let any = HitFilter()
}

/// Changes to the automatic weapon attack. Written weapon-agnostically: each
/// has a sensible meaning for melee and ranged weapons alike, so no starter
/// weapon locks a player out of a branch.
enum WeaponModifier: Equatable {
    /// More projectiles; melee weapons gain a chance to strike again instead.
    case extraProjectiles(RankValue)
    /// Projectiles pass through more enemies; melee weapons reach further.
    case pierce(RankValue)
    /// Degrees added to a melee arc; projectiles gain a small burst instead.
    case cleave(RankValue)
    /// Fraction more range.
    case reach(RankValue)
    /// Chance an attack is immediately followed by another.
    case multistrike(RankValue)
    /// Fraction of weapon damage added as another damage type.
    case addedDamage(DamageType, RankValue)
}

/// Surviving a lethal blow, on a cooldown.
struct CheatDeathSpec: Equatable {
    var cooldown: Double
    /// Fraction of max health restored.
    var restore: Double
    var invulnerability: Double
    var action: EffectAction?
}

/// What learning a skill does. A skill may carry several.
enum SkillEffect: Equatable {
    case stat(ModifierSpec)
    case statWhile(PlayerCondition, ModifierSpec)
    /// `target`'s value is multiplied by the final value of `source`
    /// (e.g. +0.2% damage per point of armour).
    case statFromStat(source: StatID, target: ModifierSpec)
    /// Extra damage (a fraction) against enemies matching the condition.
    case damageAgainst(TargetCondition, RankValue)
    case critChanceAgainst(TargetCondition, RankValue)
    /// Extra critical damage multiplier against matching enemies.
    case critDamageAgainst(TargetCondition, RankValue)
    /// Direct hits matching the filter may inflict a status.
    case inflict(HitFilter, StatusApplication)
    case proc(ProcSpec)
    case weapon(WeaponModifier)
    case ability(AbilityDefinition)
    /// A permanent ally. Its count and strength follow the skill's rank.
    case companion(SummonSpec)
    /// A permanent zone that follows the player.
    case aura(ZoneSpec)
    case cheatDeath(CheatDeathSpec)
    /// Replaces the weapon attack for the rest of the run.
    case permanentForm(FormID)
}

/// One node in an archetype's tree.
///
/// Descriptions are templates: `{0}` is replaced by `values[0]` at the
/// relevant rank, `{0%}` by the same value as a percentage.
struct SkillDefinition: Identifiable, Equatable {
    let id: SkillID
    let name: String
    let archetype: ArchetypeID
    /// The subclass path, or nil for the archetype's shared core.
    let path: PathID?
    let tier: SkillTier
    let maxRank: Int
    let kind: SkillKind
    /// SF Symbol for the node.
    let symbol: String
    let text: String
    let values: [RankValue]
    let effects: [SkillEffect]
    /// Any one of these must be learned first.
    let prerequisites: [SkillID]
    let tags: Set<CombatTag>
    /// Reserved for hybrid nodes (multiclass synergies): a second archetype
    /// that must also be invested in.
    let synergy: ArchetypeID?

    init(id: SkillID, name: String, archetype: ArchetypeID, path: PathID?, tier: SkillTier, maxRank: Int,
         kind: SkillKind, symbol: String, text: String, values: [RankValue] = [], effects: [SkillEffect],
         prerequisites: [SkillID] = [], tags: Set<CombatTag> = [], synergy: ArchetypeID? = nil) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.path = path
        self.tier = tier
        self.maxRank = maxRank
        self.kind = kind
        self.symbol = symbol
        self.text = text
        self.values = values
        self.effects = effects
        self.prerequisites = prerequisites
        self.tags = tags
        self.synergy = synergy
    }

    /// The ability this skill grants, if any.
    var ability: AbilityDefinition? {
        for effect in effects {
            if case .ability(let definition) = effect {
                return definition
            }
        }
        return nil
    }

    /// Description with values filled in for `rank` (rank 1 if unlearned).
    func description(atRank rank: Int) -> String {
        var result = text
        for (index, value) in values.enumerated() {
            let amount = value.at(max(rank, 1))
            result = result.replacingOccurrences(of: "{\(index)%}", with: Self.format(amount * 100) + "%")
            result = result.replacingOccurrences(of: "{\(index)}", with: Self.format(amount))
        }
        return result
    }

    static func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.05 {
            return String(Int(rounded.rounded()))
        }
        return String(format: "%.1f", rounded)
    }
}
