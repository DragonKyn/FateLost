import CoreGraphics
import Foundation

/// Shorthand for writing skill trees as data.
///
/// Each archetype's content type conforms and gets these helpers, so a skill
/// reads close to its design note. Every skill is its own `static let`,
/// which keeps each expression small for the compiler and each skill easy to
/// find.
protocol SkillContent {
    static var archetype: ArchetypeID { get }
}

extension SkillContent {
    static func skill(_ id: String, _ name: String, path: String? = nil, tier: SkillTier, ranks: Int,
                      kind: SkillKind, symbol: String, text: String, values: [RankValue] = [],
                      effects: [SkillEffect], requires: [String] = [], tags: Set<CombatTag> = []) -> SkillDefinition {
        SkillDefinition(
            id: "\(archetype.rawValue).\(id)",
            name: name,
            archetype: archetype,
            path: path.map { pathID($0) },
            tier: tier,
            maxRank: ranks,
            kind: kind,
            symbol: symbol,
            text: text,
            values: values,
            effects: effects,
            prerequisites: requires.map { "\(archetype.rawValue).\($0)" },
            tags: tags
        )
    }

    static func pathID(_ name: String) -> PathID {
        "\(archetype.rawValue).\(name)"
    }

    static func abilityID(_ name: String) -> AbilityID {
        "\(archetype.rawValue).\(name)"
    }

    static func rv(_ first: Double, _ perRank: Double = 0) -> RankValue {
        RankValue(first, perRank)
    }

    // MARK: Stats

    /// `stat` increased by `first`, and by `perRank` more each rank (defaults to `first`).
    static func inc(_ stat: StatID, _ first: Double, _ perRank: Double? = nil) -> SkillEffect {
        .stat(ModifierSpec(stat, .increased, RankValue(first, perRank ?? first)))
    }

    static func flat(_ stat: StatID, _ first: Double, _ perRank: Double? = nil) -> SkillEffect {
        .stat(ModifierSpec(stat, .flat, RankValue(first, perRank ?? first)))
    }

    static func more(_ stat: StatID, _ first: Double, _ perRank: Double? = nil) -> SkillEffect {
        .stat(ModifierSpec(stat, .more, RankValue(first, perRank ?? first)))
    }

    static func whileIn(_ condition: PlayerCondition, _ stat: StatID, _ kind: ModifierKind, _ first: Double,
                        _ perRank: Double? = nil) -> SkillEffect {
        .statWhile(condition, ModifierSpec(stat, kind, RankValue(first, perRank ?? first)))
    }

    static func mod(_ stat: StatID, _ kind: ModifierKind, _ first: Double, _ perRank: Double = 0) -> ModifierSpec {
        ModifierSpec(stat, kind, RankValue(first, perRank))
    }

    // MARK: Damage and statuses

    static func dmg(_ first: Double, _ perRank: Double, _ type: DamageType, _ tags: TagMask = [],
                    knockback: CGFloat = 0.5, crit: Double = 0) -> DamageSpec {
        DamageSpec(RankValue(first, perRank), type, tags: tags, knockback: knockback, critBonus: crit)
    }

    static func status(_ kind: StatusKind, chance: RankValue = 1, potency: RankValue = 0,
                       duration: RankValue) -> StatusApplication {
        StatusApplication(kind, chance: chance, potency: potency, duration: duration)
    }

    // MARK: Effects

    static func ability(_ id: String, _ name: String, symbol: String, cooldown: RankValue, ultimate: Bool = false,
                        _ action: EffectAction) -> SkillEffect {
        .ability(AbilityDefinition(id: abilityID(id), name: name, symbol: symbol, cooldown: cooldown,
                                   isUltimate: ultimate, action: action))
    }

    static func proc(_ trigger: SkillTrigger, chance: RankValue = 1, cooldown: Double = 0,
                     target: TargetCondition? = nil, requires: PlayerCondition? = nil,
                     _ action: EffectAction) -> SkillEffect {
        .proc(ProcSpec(trigger: trigger, chance: chance, cooldown: cooldown, target: target, requires: requires,
                       action: action))
    }

    static func buff(_ id: String, _ modifiers: [ModifierSpec], duration: RankValue,
                     stacks: Int = 1) -> EffectAction {
        .buff(BuffSpec(id: "\(archetype.rawValue).\(id)", modifiers: modifiers, duration: duration,
                       maxStacks: stacks))
    }

    static func nova(_ radius: RankValue, _ damage: DamageSpec?, status: StatusApplication? = nil,
                     at anchor: ActionAnchor = .player, _ visual: VisualStyle) -> EffectAction {
        .nova(NovaSpec(radius: radius, damage: damage, status: status, anchor: anchor, visual: visual))
    }

    static func zone(_ radius: RankValue, duration: RankValue, tick: Double = 0.5, _ damage: DamageSpec?,
                     status: StatusApplication? = nil, pull: CGFloat = 0, strikes: Int = 0,
                     buff: [ModifierSpec] = [], follows: Bool = false, at anchor: ActionAnchor = .player,
                     _ visual: VisualStyle) -> ZoneSpec {
        ZoneSpec(radius: radius, duration: duration, tick: tick, damage: damage, status: status, pull: pull,
                 strikesPerTick: strikes, playerBuff: buff, follows: follows, anchor: anchor, visual: visual)
    }
}
