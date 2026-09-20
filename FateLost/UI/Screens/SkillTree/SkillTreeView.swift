import SwiftUI

/// The skill tree: spend points across eleven archetypes, each with a shared
/// core and three subclass paths, plus the eight orders that only open once
/// two archetypes have been invested in. Choose which abilities to carry.
///
/// Laid out for a phone held in landscape: one bar of controls across the
/// top, the tree filling the rest, and a detail panel that slides in only
/// while something is selected. Choices are a draft until confirmed, so a
/// point can be taken back while the screen is open, and unspent points can
/// be banked for later.
struct SkillTreeView: View {
    let session: GameSession

    @Environment(AppServices.self) private var services
    @State private var draft: SkillAllocation
    @State private var slots: [AbilityID?]
    @State private var board: TreeBoard
    @State private var selectedSkillID: SkillID?
    @State private var showsOverview = true

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
        let start = progression.allocation.points(in: favourite) > 0 ? favourite : ArchetypeID.warrior
        _board = State(initialValue: .archetype(start))
    }

    private var available: Int { max(0, earnedPoints - draft.spent) }
    private var selectedSkill: SkillDefinition? { selectedSkillID.flatMap { SkillCatalog.skill($0) } }
    private var showsPanel: Bool { selectedSkillID != nil || showsOverview }
    private var hasChanges: Bool { draft != committed }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.82), FLTheme.Palette.abyss.opacity(0.94)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                toolbar
                HStack(spacing: 8) {
                    BoardRail(selection: $board, allocation: draft) { tapped in
                        select(board: tapped)
                    }
                    .frame(width: 56)

                    SkillTreeCanvas(board: board, draft: draft, committed: committed, available: available,
                                    selectedSkillID: $selectedSkillID) { skill in
                        select(skill: skill)
                    }

                    if showsPanel {
                        SkillDetailPanel(board: board, skill: selectedSkill, draft: draft,
                                         committed: committed, available: available, slots: $slots,
                                         onLearn: learn, onUndo: undo, onClose: closePanel)
                            .frame(width: 272)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .animation(.easeOut(duration: 0.18), value: showsPanel)
        .animation(.easeOut(duration: 0.18), value: selectedSkillID)
        .animation(.easeOut(duration: 0.18), value: board)
    }

    // MARK: Toolbar

    private var toolbar: some View {
        let title = BuildTitle.title(for: draft)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title.name)
                    .font(FLTheme.Typeface.title(20))
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Level \(session.progression.level) · \(title.subtitle ?? "spend your points")")
                    .font(FLTheme.Typeface.body(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LoadoutStrip(slots: slots) { id in
                if let skillID = SkillCatalog.skillID(forAbility: id), let skill = SkillCatalog.skill(skillID) {
                    board = skill.order.map(TreeBoard.order) ?? .archetype(skill.archetype)
                    select(skill: skill)
                }
            }
            PointsBadge(points: available)
            if hasChanges {
                Button {
                    draft = committed
                    slots = session.progression.abilitySlots
                    services.audio.play(.uiBack)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.flSecondaryCompact)
                .frame(width: 48)
                .accessibilityLabel("Undo all changes")
            }
            Button(confirmTitle) {
                services.audio.play(.uiConfirm)
                session.closeSkillTree(committing: draft, slots: slots)
            }
            .buttonStyle(hasChanges ? .flPrimaryCompact : .flSecondaryCompact)
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 46)
    }

    private var confirmTitle: String {
        if hasChanges { return "Confirm" }
        return available > 0 ? "Later" : "Close"
    }

    // MARK: Selection

    private func select(board tapped: TreeBoard) {
        let sameAgain = tapped == board && showsOverview && selectedSkillID == nil
        board = tapped
        selectedSkillID = nil
        showsOverview = !sameAgain
        services.haptics.play(.uiTap)
    }

    private func select(skill: SkillDefinition) {
        if selectedSkillID == skill.id {
            selectedSkillID = nil
            showsOverview = false
        } else {
            selectedSkillID = skill.id
            showsOverview = false
        }
        services.haptics.play(.uiTap)
    }

    private func closePanel() {
        selectedSkillID = nil
        showsOverview = false
        services.audio.play(.uiBack)
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
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
            Text("\(points)")
                .font(FLTheme.Typeface.number(17))
        }
        .foregroundStyle(points > 0 ? FLTheme.Palette.abyss : FLTheme.Palette.parchmentDim)
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Capsule().fill(points > 0 ? AnyShapeStyle(FLTheme.Palette.emberBright)
                                              : AnyShapeStyle(FLTheme.Palette.stoneRaised)))
        .overlay(Capsule().strokeBorder(FLTheme.Palette.rim, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(points) skill points available")
    }
}

// MARK: - Loadout

/// The four equipped abilities, as they appear on the HUD.
private struct LoadoutStrip: View {
    let slots: [AbilityID?]
    let onSelect: (AbilityID) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<AbilitySlots.count, id: \.self) { slot in
                button(slot)
            }
        }
    }

    private func button(_ slot: Int) -> some View {
        let ability = slots[slot].flatMap { SkillCatalog.ability($0) }
        let isUltimate = slot == AbilitySlots.ultimate
        return Button {
            if let ability { onSelect(ability.id) }
        } label: {
            Image(systemName: ability?.symbol ?? (isUltimate ? "star" : "circle.dashed"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ability == nil ? FLTheme.Palette.locked : FLTheme.Palette.parchment)
                .frame(width: 42, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(FLTheme.Palette.stoneRaised.opacity(0.85)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isUltimate ? FLTheme.Palette.ember.opacity(0.9) : FLTheme.Palette.rim,
                                  lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(ability == nil)
        .accessibilityLabel(ability.map { "\($0.name) in slot \(slot + 1)" } ?? "Empty ability slot \(slot + 1)")
    }
}

// MARK: - Board rail

/// The eleven archetypes, then the eight orders beneath a rule. Orders sit
/// last because that is the order a build discovers them in: nobody reaches
/// one without having spent a while further up the rail.
private struct BoardRail: View {
    @Binding var selection: TreeBoard
    let allocation: SkillAllocation
    let onSelect: (TreeBoard) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(SkillCatalog.archetypes) { archetype in
                    ArchetypeSigil(archetype: archetype, points: allocation.points(in: archetype.id),
                                   isSelected: selection == .archetype(archetype.id))
                        .onTapGesture { onSelect(.archetype(archetype.id)) }
                }

                VStack(spacing: 3) {
                    Rectangle()
                        .fill(FLTheme.Palette.rim.opacity(0.6))
                        .frame(height: 1)
                    Text("ORDERS")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)

                ForEach(HybridOrders.all) { order in
                    OrderSigil(order: order, points: BuildTitle.points(in: order.id, of: allocation),
                               isOpen: isOpen(order), isSelected: selection == .order(order.id))
                        .onTapGesture { onSelect(.order(order.id)) }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Whether the order's first nodes could be taken right now.
    private func isOpen(_ order: HybridOrderDefinition) -> Bool {
        let rules = SkillTreeRules.standard
        return allocation.points(in: order.primary, below: .two) >= rules.threshold(for: .two)
            && allocation.points(in: order.synergy) >= rules.synergyThreshold(for: .two)
    }
}

/// One order in the rail. Dim until both its trees have been fed.
private struct OrderSigil: View {
    let order: HybridOrderDefinition
    let points: Int
    let isOpen: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isSelected ? FLTheme.Palette.emberBright : Color.clear)
                .frame(width: 3, height: 34)
            VStack(spacing: 1) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(order.color.color.opacity(isSelected ? 0.9 : (isOpen ? 0.34 : 0.16)))
                        .frame(width: 38, height: 38)
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(isSelected ? FLTheme.Palette.emberBright : FLTheme.Palette.rim,
                                          lineWidth: isSelected ? 2 : 1))
                        .overlay(Image(systemName: order.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isOpen ? FLTheme.Palette.parchment : FLTheme.Palette.locked))
                    if points > 0 {
                        Text("\(points)")
                            .font(FLTheme.Typeface.number(10))
                            .foregroundStyle(FLTheme.Palette.abyss)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 0.5)
                            .background(Capsule().fill(FLTheme.Palette.emberBright))
                            .offset(x: 5, y: -2)
                    }
                }
                Text(order.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isSelected ? FLTheme.Palette.parchment : FLTheme.Palette.parchmentDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(order.name) order, \(points) points, \(isOpen ? "open" : "locked")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ArchetypeSigil: View {
    let archetype: ArchetypeDefinition
    let points: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            // A lit bar marks the archetype on show.
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isSelected ? FLTheme.Palette.emberBright : Color.clear)
                .frame(width: 3, height: 34)
            VStack(spacing: 1) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(archetype.color.color.opacity(isSelected ? 0.9 : 0.3))
                        .frame(width: 38, height: 38)
                        .overlay(Circle().strokeBorder(isSelected ? FLTheme.Palette.emberBright : FLTheme.Palette.rim,
                                                       lineWidth: isSelected ? 2 : 1))
                        .overlay(Image(systemName: archetype.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FLTheme.Palette.parchment))
                    if points > 0 {
                        Text("\(points)")
                            .font(FLTheme.Typeface.number(10))
                            .foregroundStyle(FLTheme.Palette.abyss)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 0.5)
                            .background(Capsule().fill(FLTheme.Palette.emberBright))
                            .offset(x: 5, y: -2)
                    }
                }
                Text(archetype.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isSelected ? FLTheme.Palette.parchment : FLTheme.Palette.parchmentDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(archetype.name), \(points) points")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
