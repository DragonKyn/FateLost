import CoreGraphics
import Foundation

/// A stat modifier that only applies while a condition holds.
struct ConditionalModifier {
    let condition: PlayerCondition
    let modifier: StatModifier
}

/// Adds `perPoint` × the final value of `source` to a stat.
struct StatConversion {
    let source: StatID
    let perPoint: StatModifier
}

/// Extra damage or critical chance against enemies matching a condition.
struct HitBonus {
    enum Kind {
        case damage
        case critChance
        case critDamage
    }

    let condition: TargetCondition
    let kind: Kind
    let value: Double
}

/// A status direct hits may inflict.
struct Infliction {
    let filter: HitFilter
    let status: StatusApplication
}

/// A resolved proc: rank values fixed, ready to fire.
struct ProcRule {
    let trigger: SkillTrigger
    let chance: Double
    let cooldown: Double
    let target: TargetCondition?
    let requires: PlayerCondition?
    let action: EffectAction
    let skillID: SkillID
}

/// A permanent ally the build keeps alive.
struct CompanionRule {
    /// Stable identity: the granting skill plus the summon kind.
    let key: String
    let spec: SummonSpec
    let count: Int
}

/// Totals of every weapon modifier.
struct WeaponModifierSet {
    var extraProjectiles = 0
    var cleaveDegrees: Double = 0
    var reach: Double = 0
    var multistrike: Double = 0
    var added = AddedDamage()
}

/// An ability the build has learned, at its rank.
struct LearnedAbility {
    let definition: AbilityDefinition
    let rank: Int
    let skillID: SkillID
    /// The action with rank values resolved.
    let action: EffectAction
    /// Base cooldown at this rank, before cooldown reduction.
    let cooldown: Double
}

/// A skill allocation turned into what the simulation needs each step.
///
/// Compiling happens only when the build changes (a point is spent), so the
/// per-hit and per-step paths read flat arrays and never walk the skill tree.
struct CompiledBuild {
    var modifiers: [StatModifier] = []
    var conditionals: [ConditionalModifier] = []
    var conversions: [StatConversion] = []
    var hitBonuses: [HitBonus] = []
    var inflictions: [Infliction] = []
    var procs: [ProcRule] = []
    var weapon = WeaponModifierSet()
    var abilities: [AbilityID: LearnedAbility] = [:]
    var companions: [CompanionRule] = []
    var auras: [ZoneSpec] = []
    var cheatDeath: CheatDeathSpec?
    var permanentForm: FormID?
    /// Rank of the skill granting each form, for scaling its bonuses.
    var formRanks: [FormID: Int] = [:]

    // Proc indices grouped by trigger, so each event checks only its own.
    private(set) var hitProcs: [Int] = []
    private(set) var criticalProcs: [Int] = []
    private(set) var killProcs: [Int] = []
    private(set) var hurtProcs: [Int] = []
    private(set) var dodgeProcs: [Int] = []
    private(set) var intervalProcs: [Int] = []
    private(set) var castProcs: [Int] = []
    private(set) var transformProcs: [Int] = []
    private(set) var attackProcs: [Int] = []

    /// Compiles a skill allocation, and the relics carried alongside it.
    ///
    /// Relics go through the same `add` as skills, so a relic can do anything
    /// a skill effect can and combat never has to know the difference.
    /// Abilities and forms are the exception: they live in slots the tree
    /// screen manages, so a relic that names one is simply ignored.
    static func compile(_ allocation: SkillAllocation, relics: RelicInventory = RelicInventory()) -> CompiledBuild {
        var build = CompiledBuild()

        for archetype in SkillCatalog.archetypes {
            let points = allocation.points(in: archetype.id)
            guard points > 0 else { continue }
            for modifier in archetype.resonance {
                build.modifiers.append(modifier.scaled(by: Double(points)))
            }
        }

        for (skill, rank) in allocation.learned {
            for effect in skill.effects {
                build.add(effect, rank: rank, source: skill.id)
            }
        }
        for (relic, rank) in relics.held {
            for effect in relic.effects {
                switch effect {
                case .ability, .permanentForm:
                    continue
                default:
                    build.add(effect, rank: rank, source: relic.id)
                }
            }
        }
        build.indexProcs()
        return build
    }

    private mutating func add(_ effect: SkillEffect, rank: Int, source: SkillID) {
        switch effect {
        case .stat(let spec):
            modifiers.append(spec.at(rank))
        case let .statWhile(condition, spec):
            conditionals.append(ConditionalModifier(condition: condition, modifier: spec.at(rank)))
        case let .statFromStat(source, target):
            conversions.append(StatConversion(source: source, perPoint: target.at(rank)))
        case let .damageAgainst(condition, value):
            hitBonuses.append(HitBonus(condition: condition, kind: .damage, value: value.at(rank)))
        case let .critChanceAgainst(condition, value):
            hitBonuses.append(HitBonus(condition: condition, kind: .critChance, value: value.at(rank)))
        case let .critDamageAgainst(condition, value):
            hitBonuses.append(HitBonus(condition: condition, kind: .critDamage, value: value.at(rank)))
        case let .inflict(filter, status):
            inflictions.append(Infliction(filter: filter, status: status.resolved(rank)))
        case .proc(let spec):
            procs.append(ProcRule(trigger: spec.trigger, chance: spec.chance.at(rank), cooldown: spec.cooldown,
                                  target: spec.target, requires: spec.requires, action: spec.action.resolved(rank),
                                  skillID: source))
        case .weapon(let modifier):
            add(modifier, rank: rank)
        case .ability(let definition):
            abilities[definition.id] = LearnedAbility(definition: definition, rank: rank, skillID: source,
                                                      action: definition.action.resolved(rank),
                                                      cooldown: max(0.5, definition.cooldown.at(rank)))
            if case .transform(let form) = definition.action {
                formRanks[form] = rank
            }
        case .companion(let spec):
            let resolved = spec.resolved(rank)
            companions.append(CompanionRule(key: "\(source)|\(spec.key)", spec: resolved,
                                            count: max(1, Int(resolved.count.value))))
        case .aura(let spec):
            auras.append(spec.resolved(rank))
        case .cheatDeath(let spec):
            // The strongest refusal wins if two skills grant one.
            if let current = cheatDeath, current.restore >= spec.restore { break }
            cheatDeath = spec
        case .permanentForm(let form):
            permanentForm = form
            formRanks[form] = max(formRanks[form] ?? 0, rank)
        }
    }

    private mutating func add(_ modifier: WeaponModifier, rank: Int) {
        switch modifier {
        case .extraProjectiles(let value):
            weapon.extraProjectiles += Int(value.at(rank).rounded())
        case .pierce(let value):
            // Melee weapons turn pierce into reach.
            weapon.reach += value.at(rank) * 0.08
        case .cleave(let value):
            weapon.cleaveDegrees += value.at(rank)
        case .reach(let value):
            weapon.reach += value.at(rank)
        case .multistrike(let value):
            weapon.multistrike += value.at(rank)
        case let .addedDamage(type, value):
            weapon.added.add(type, value.at(rank))
        }
    }

    private mutating func indexProcs() {
        for (index, rule) in procs.enumerated() {
            switch rule.trigger {
            case .hit: hitProcs.append(index)
            case .criticalHit: criticalProcs.append(index)
            case .kill: killProcs.append(index)
            case .hurt: hurtProcs.append(index)
            case .dodge: dodgeProcs.append(index)
            case .interval: intervalProcs.append(index)
            case .abilityCast: castProcs.append(index)
            case .transform: transformProcs.append(index)
            case .attack, .everyNthAttack: attackProcs.append(index)
            }
        }
    }
}
