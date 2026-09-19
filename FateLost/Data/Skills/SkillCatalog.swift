import Foundation

/// Every archetype and skill in the game.
enum SkillCatalog {
    static let archetypes: [ArchetypeDefinition] = [
        WarriorSkills.definition, RogueSkills.definition, RangerSkills.definition,
        WizardSkills.definition, SorcererSkills.definition, WarlockSkills.definition,
        ClericSkills.definition, PaladinSkills.definition, DruidSkills.definition,
        MonkSkills.definition, BardSkills.definition,
    ]

    private static let byArchetype: [ArchetypeID: [SkillDefinition]] = [
        .warrior: WarriorSkills.skills,
        .rogue: RogueSkills.skills,
        .ranger: RangerSkills.skills,
        .wizard: WizardSkills.skills,
        .sorcerer: SorcererSkills.skills,
        .warlock: WarlockSkills.skills,
        .cleric: ClericSkills.skills,
        .paladin: PaladinSkills.skills,
        .druid: DruidSkills.skills,
        .monk: MonkSkills.skills,
        .bard: BardSkills.skills,
    ]

    static let all: [SkillDefinition] = ArchetypeID.allCases.flatMap { byArchetype[$0] ?? [] }

    private static let byID: [SkillID: SkillDefinition] = {
        var index: [SkillID: SkillDefinition] = [:]
        for skill in all {
            index[skill.id] = skill
        }
        return index
    }()

    private static let abilitiesByID: [AbilityID: AbilityDefinition] = {
        var index: [AbilityID: AbilityDefinition] = [:]
        for skill in all {
            if let ability = skill.ability {
                index[ability.id] = ability
            }
        }
        return index
    }()

    /// The skill granting each ability, for its rank.
    private static let skillByAbility: [AbilityID: SkillID] = {
        var index: [AbilityID: SkillID] = [:]
        for skill in all {
            if let ability = skill.ability {
                index[ability.id] = skill.id
            }
        }
        return index
    }()

    static func skill(_ id: SkillID) -> SkillDefinition? {
        byID[id]
    }

    static func skills(for archetype: ArchetypeID) -> [SkillDefinition] {
        byArchetype[archetype] ?? []
    }

    static func archetype(_ id: ArchetypeID) -> ArchetypeDefinition? {
        archetypes.first { $0.id == id }
    }

    static func ability(_ id: AbilityID) -> AbilityDefinition? {
        abilitiesByID[id]
    }

    static func skillID(forAbility id: AbilityID) -> SkillID? {
        skillByAbility[id]
    }

    static func path(_ id: PathID) -> PathDefinition? {
        for archetype in archetypes {
            if let path = archetype.paths.first(where: { $0.id == id }) {
                return path
            }
        }
        return nil
    }
}
