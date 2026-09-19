import SwiftUI

/// The right-hand panel: the selected skill in full (or the archetype's
/// overview when none is selected), with learning and equipping controls.
struct SkillDetailPanel: View {
    let archetype: ArchetypeID
    let skill: SkillDefinition?
    let draft: SkillAllocation
    let committed: SkillAllocation
    let available: Int
    @Binding var slots: [AbilityID?]
    let onLearn: (SkillDefinition) -> Void
    let onUndo: (SkillDefinition) -> Void

    private var rules: SkillTreeRules { .standard }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                if let skill {
                    SkillDetails(skill: skill, rank: draft.rank(of: skill.id))
                    actions(for: skill)
                    if let ability = skill.ability, draft.rank(of: skill.id) > 0 {
                        EquipControls(ability: ability, slots: $slots)
                    }
                } else if let definition = SkillCatalog.archetype(archetype) {
                    ArchetypeOverview(definition: definition, allocation: draft)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
        .flPanel()
    }

    @ViewBuilder
    private func actions(for skill: SkillDefinition) -> some View {
        let denial = rules.denial(for: skill, in: draft, availablePoints: available)
        let rank = draft.rank(of: skill.id)
        VStack(alignment: .leading, spacing: 8) {
            if let denial, denial != .maxRank {
                Label(message(for: denial, skill: skill), systemImage: "lock.fill")
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                if rank < skill.maxRank {
                    Button(rank == 0 ? "Learn" : "Rank Up") { onLearn(skill) }
                        .buttonStyle(.flPrimary)
                        .disabled(denial != nil)
                } else {
                    Text("Mastered")
                        .font(FLTheme.Typeface.heading(16))
                        .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.45))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                if rules.canRemove(skill, from: draft, floor: committed) {
                    Button {
                        onUndo(skill)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.flSecondary)
                    .frame(width: 64)
                    .accessibilityLabel("Take back a point")
                }
            }
        }
    }

    private func message(for denial: SkillTreeRules.Denial, skill: SkillDefinition) -> String {
        let archetypeName = SkillCatalog.archetype(skill.archetype)?.name ?? "this"
        switch denial {
        case .noPoints:
            return "No skill points to spend. Level up to earn more."
        case .maxRank:
            return "Mastered."
        case .needsPoints(let count):
            return "Spend \(count) more \(count == 1 ? "point" : "points") in the \(archetypeName) tree's lower tiers."
        case .needsPrerequisite(let ids):
            let names = ids.compactMap { SkillCatalog.skill($0)?.name }
            return "Requires \(names.joined(separator: " or "))."
        case .capstoneTaken(let id):
            let name = SkillCatalog.skill(id)?.name ?? "another capstone"
            return "You have already chosen \(name). Each archetype allows one capstone."
        }
    }
}

// MARK: - Skill details

private struct SkillDetails: View {
    let skill: SkillDefinition
    let rank: Int

    private var pathName: String {
        if let path = skill.path, let definition = SkillCatalog.path(path) {
            return definition.name
        }
        return "Core"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: skill.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(FLTheme.Palette.emberBright)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(skill.name)
                        .font(FLTheme.Typeface.title(19))
                        .foregroundStyle(FLTheme.Palette.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(skill.kind.displayName) · \(pathName) · \(skill.tier.displayName)")
                        .font(FLTheme.Typeface.label(11))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
            }
            if let ability = skill.ability {
                Text("Cooldown \(SkillDefinition.format(ability.cooldown.at(max(rank, 1)))) s")
                    .font(FLTheme.Typeface.number(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
            Text(skill.description(atRank: max(rank, 1)))
                .font(FLTheme.Typeface.body(14))
                .foregroundStyle(FLTheme.Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)
            if rank > 0, rank < skill.maxRank, !skill.values.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    FLSectionLabel(text: "Next rank")
                    Text(skill.description(atRank: rank + 1))
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Rank \(rank) of \(skill.maxRank)")
                .font(FLTheme.Typeface.number(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
        }
    }
}

// MARK: - Equipping

/// Choose which slot an ability sits in.
private struct EquipControls: View {
    let ability: AbilityDefinition
    @Binding var slots: [AbilityID?]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FLSectionLabel(text: ability.isUltimate ? "Ultimate slot" : "Ability slot")
            HStack(spacing: 6) {
                if ability.isUltimate {
                    slotButton(AbilitySlots.ultimate, label: "Ultimate")
                } else {
                    ForEach(0..<AbilitySlots.ultimate, id: \.self) { slot in
                        slotButton(slot, label: ["I", "II", "III"][slot])
                    }
                }
            }
        }
    }

    private func slotButton(_ slot: Int, label: String) -> some View {
        let equipped = slots[slot] == ability.id
        let occupant = slots[slot].flatMap { SkillCatalog.ability($0) }
        return Button {
            if equipped {
                slots[slot] = nil
            } else {
                slots = slots.map { $0 == ability.id ? nil : $0 }
                slots[slot] = ability.id
            }
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(FLTheme.Typeface.heading(14))
                Text(equipped ? "Equipped" : (occupant?.name ?? "Empty"))
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(equipped ? FLTheme.Palette.abyss : FLTheme.Palette.parchment)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(equipped ? AnyShapeStyle(FLTheme.Palette.emberBright)
                               : AnyShapeStyle(FLTheme.Palette.stoneRaised)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(FLTheme.Palette.rim, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(equipped ? "Unequip from slot \(label)" : "Equip in slot \(label)")
    }
}

// MARK: - Archetype overview

private struct ArchetypeOverview: View {
    let definition: ArchetypeDefinition
    let allocation: SkillAllocation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: definition.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(definition.color.color)
                Text(definition.name)
                    .font(FLTheme.Typeface.title(22))
                    .foregroundStyle(FLTheme.Palette.parchment)
            }
            Text(definition.tagline)
                .font(FLTheme.Typeface.heading(14))
                .italic()
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 2) {
                FLSectionLabel(text: "Resonance")
                Text(definition.resonanceText)
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(definition.paths) { path in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(path.name)
                            .font(FLTheme.Typeface.heading(14))
                            .foregroundStyle(definition.color.color)
                        Spacer()
                        Text("\(allocation.points(inPath: path.id)) pts")
                            .font(FLTheme.Typeface.number(11))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                    }
                    Text(path.summary)
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Tap a skill to see it. Tiers open as you spend points in the tiers below; each archetype allows one capstone.")
                .font(FLTheme.Typeface.body(11))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Loadout bar

/// The equipped abilities along the bottom of the tree.
struct AbilityLoadoutBar: View {
    let slots: [AbilityID?]
    let onSelect: (AbilityID) -> Void

    var body: some View {
        HStack(spacing: 10) {
            FLSectionLabel(text: "Abilities")
            ForEach(0..<AbilitySlots.count, id: \.self) { slot in
                chip(slot)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ slot: Int) -> some View {
        let ability = slots[slot].flatMap { SkillCatalog.ability($0) }
        let isUltimate = slot == AbilitySlots.ultimate
        return Button {
            if let ability { onSelect(ability.id) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: ability?.symbol ?? (isUltimate ? "star" : "circle.dashed"))
                    .font(.system(size: 14, weight: .semibold))
                Text(ability?.name ?? (isUltimate ? "Ultimate" : "Empty"))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(ability == nil ? FLTheme.Palette.parchmentDim : FLTheme.Palette.parchment)
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(Capsule().fill(FLTheme.Palette.stoneRaised.opacity(0.85)))
            .overlay(Capsule().strokeBorder(isUltimate ? FLTheme.Palette.ember : FLTheme.Palette.rim, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(ability == nil)
    }
}
