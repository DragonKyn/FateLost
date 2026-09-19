import SwiftUI

/// The skill tree: spend points across eleven archetypes, each with a shared
/// core and three subclass paths, and choose which abilities to carry.
///
/// Choices are a draft until confirmed, so a point can be taken back while
/// the screen is open. Unspent points can be banked for later.
struct SkillTreeView: View {
    let session: GameSession

    @Environment(AppServices.self) private var services
    @State private var draft: SkillAllocation
    @State private var slots: [AbilityID?]
    @State private var archetype: ArchetypeID
    @State private var selectedSkillID: SkillID?

    private let committed: SkillAllocation
    private let earnedPoints: Int
    private let rules = SkillTreeRules.standard

    init(session: GameSession) {
        self.session = session
        let progression = session.progression
        committed = progression.allocation
        earnedPoints = progression.earnedPoints
        _draft = State(initialValue: progression.allocation)
        _slots = State(initialValue: progression.abilitySlots)
        let favourite = ArchetypeID.allCases.max {
            progression.allocation.points(in: $0) < progression.allocation.points(in: $1)
        } ?? .warrior
        _archetype = State(initialValue: progression.allocation.points(in: favourite) > 0 ? favourite : .warrior)
    }

    private var available: Int { max(0, earnedPoints - draft.spent) }
    private var selectedSkill: SkillDefinition? { selectedSkillID.flatMap { SkillCatalog.skill($0) } }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.82), FLTheme.Palette.abyss.opacity(0.94)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                header
                HStack(alignment: .top, spacing: 12) {
                    ArchetypeRail(selection: $archetype, allocation: draft) {
                        selectedSkillID = nil
                    }
                    .frame(width: 64)

                    SkillTreeCanvas(archetype: archetype, draft: draft, committed: committed, available: available,
                                    selectedSkillID: $selectedSkillID)

                    SkillDetailPanel(archetype: archetype, skill: selectedSkill, draft: draft, committed: committed,
                                     available: available, slots: $slots,
                                     onLearn: learn, onUndo: undo)
                        .frame(width: 262)
                }
                AbilityLoadoutBar(slots: slots) { id in
                    if let skillID = SkillCatalog.skillID(forAbility: id), let skill = SkillCatalog.skill(skillID) {
                        archetype = skill.archetype
                        selectedSkillID = skillID
                    }
                }
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
            .padding(.vertical, 12)
        }
    }

    // MARK: Header

    private var header: some View {
        let title = BuildTitle.title(for: draft)
        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Level \(session.progression.level) · \(title.name)")
                    .font(FLTheme.Typeface.title(24))
                    .foregroundStyle(FLTheme.Palette.parchment)
                Text(title.subtitle ?? "Where your points go, you become.")
                    .font(FLTheme.Typeface.body(13))
                    .italic()
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
            Spacer()
            PointsBadge(points: available)
            if draft != committed {
                Button("Undo All") {
                    draft = committed
                    slots = session.progression.abilitySlots
                    services.audio.play(.uiBack)
                }
                .buttonStyle(.flSecondary)
                .frame(width: 130)
            }
            Button(available > 0 && draft == committed ? "Later" : "Confirm") {
                services.audio.play(.uiConfirm)
                session.closeSkillTree(committing: draft, slots: slots)
            }
            .buttonStyle(.flPrimary)
            .frame(width: 140)
        }
    }

    // MARK: Actions

    private func learn(_ skill: SkillDefinition) {
        guard rules.denial(for: skill, in: draft, availablePoints: available) == nil else { return }
        let wasLearned = draft.rank(of: skill.id) > 0
        draft.add(skill)
        services.audio.play(.skillLearn)
        services.haptics.play(.uiTap)
        if !wasLearned, let ability = skill.ability {
            autoEquip(ability)
        }
    }

    private func undo(_ skill: SkillDefinition) {
        guard rules.canRemove(skill, from: draft, floor: committed) else { return }
        draft.remove(skill)
        services.audio.play(.uiBack)
        if draft.rank(of: skill.id) == 0, let ability = skill.ability {
            slots = slots.map { $0 == ability.id ? nil : $0 }
        }
    }

    /// Puts a newly learned ability into a free slot of the right kind.
    private func autoEquip(_ ability: AbilityDefinition) {
        guard !slots.contains(ability.id) else { return }
        if ability.isUltimate {
            if slots[AbilitySlots.ultimate] == nil {
                slots[AbilitySlots.ultimate] = ability.id
            }
        } else if let free = (0..<AbilitySlots.ultimate).first(where: { slots[$0] == nil }) {
            slots[free] = ability.id
        }
    }
}

// MARK: - Points badge

private struct PointsBadge: View {
    let points: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
            Text(points == 1 ? "1 point" : "\(points) points")
                .font(FLTheme.Typeface.number(16))
        }
        .foregroundStyle(points > 0 ? FLTheme.Palette.abyss : FLTheme.Palette.parchmentDim)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(points > 0 ? AnyShapeStyle(FLTheme.Palette.emberBright)
                                              : AnyShapeStyle(FLTheme.Palette.stoneRaised)))
        .overlay(Capsule().strokeBorder(FLTheme.Palette.rim, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(points) skill points available")
    }
}

// MARK: - Archetype rail

/// The eleven archetypes, each showing points invested.
private struct ArchetypeRail: View {
    @Binding var selection: ArchetypeID
    let allocation: SkillAllocation
    let onSelect: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(SkillCatalog.archetypes) { archetype in
                    ArchetypeSigil(archetype: archetype, points: allocation.points(in: archetype.id),
                                   isSelected: archetype.id == selection)
                        .onTapGesture {
                            selection = archetype.id
                            onSelect()
                        }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct ArchetypeSigil: View {
    let archetype: ArchetypeDefinition
    let points: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(archetype.color.color.opacity(isSelected ? 0.9 : 0.35))
                    .frame(width: 46, height: 46)
                    .overlay(Circle().strokeBorder(isSelected ? FLTheme.Palette.emberBright : FLTheme.Palette.rim,
                                                   lineWidth: isSelected ? 2 : 1))
                    .overlay(Image(systemName: archetype.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(FLTheme.Palette.parchment))
                if points > 0 {
                    Text("\(points)")
                        .font(FLTheme.Typeface.number(11))
                        .foregroundStyle(FLTheme.Palette.abyss)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(FLTheme.Palette.emberBright))
                        .offset(x: 6, y: -3)
                }
            }
            Text(archetype.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected ? FLTheme.Palette.parchment : FLTheme.Palette.parchmentDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(archetype.name), \(points) points")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
