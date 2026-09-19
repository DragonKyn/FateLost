import SwiftUI

/// One archetype's tree: the shared core on the left, then each subclass
/// path as a row running through tiers II, III, IV and its capstone.
struct SkillTreeCanvas: View {
    let archetype: ArchetypeID
    let draft: SkillAllocation
    let committed: SkillAllocation
    let available: Int
    @Binding var selectedSkillID: SkillID?
    let onSelect: (SkillDefinition) -> Void

    fileprivate enum Metrics {
        static let node: CGFloat = 60
        static let gap: CGFloat = 5
        static let connector: CGFloat = 12
        static let pathLabel: CGFloat = 68
    }

    private var definition: ArchetypeDefinition? { SkillCatalog.archetype(archetype) }
    private var skills: [SkillDefinition] { SkillCatalog.skills(for: archetype) }
    private var color: Color { definition?.color.color ?? FLTheme.Palette.ember }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                HStack(alignment: .center, spacing: 12) {
                    coreColumn
                    Rectangle()
                        .fill(FLTheme.Palette.rim.opacity(0.5))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                    pathsGrid
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            // Keep the selected skill in view when the panel slides in over it.
            .onChange(of: selectedSkillID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous)
                .fill(FLTheme.Palette.stone.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous)
                .strokeBorder(color.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: Columns

    private var coreColumn: some View {
        VStack(spacing: 6) {
            TierHeader(tier: .one, unlocked: true, threshold: 0)
                .frame(width: Metrics.node)
            ForEach(skills.filter { $0.path == nil }) { skill in
                node(for: skill)
            }
        }
    }

    private var pathsGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Color.clear.frame(width: Metrics.pathLabel, height: 1)
                tierHeader(.two, nodes: 2)
                Color.clear.frame(width: Metrics.connector, height: 1)
                tierHeader(.three, nodes: 2)
                Color.clear.frame(width: Metrics.connector, height: 1)
                tierHeader(.four, nodes: 1)
                Color.clear.frame(width: Metrics.connector, height: 1)
                tierHeader(.capstone, nodes: 1)
            }
            ForEach(definition?.paths ?? []) { path in
                pathRow(path)
            }
        }
    }

    private func tierHeader(_ tier: SkillTier, nodes: Int) -> some View {
        let threshold = SkillTreeRules.standard.threshold(for: tier)
        let unlocked = draft.points(in: archetype, below: tier) >= threshold
        return TierHeader(tier: tier, unlocked: unlocked, threshold: threshold)
            .frame(width: Metrics.node * CGFloat(nodes) + Metrics.gap * CGFloat(nodes - 1))
    }

    private func pathRow(_ path: PathDefinition) -> some View {
        let pathSkills = skills.filter { $0.path == path.id }
        return HStack(spacing: 0) {
            PathLabel(path: path, points: draft.points(inPath: path.id), color: color)
                .frame(width: Metrics.pathLabel, alignment: .leading)
            tierGroup(pathSkills, .two)
            connector(lit: learnedAny(pathSkills, .three))
            tierGroup(pathSkills, .three)
            connector(lit: learnedAny(pathSkills, .four))
            tierGroup(pathSkills, .four)
            connector(lit: learnedAny(pathSkills, .capstone))
            tierGroup(pathSkills, .capstone)
        }
    }

    private func tierGroup(_ pathSkills: [SkillDefinition], _ tier: SkillTier) -> some View {
        HStack(spacing: Metrics.gap) {
            ForEach(pathSkills.filter { $0.tier == tier }) { skill in
                node(for: skill)
            }
        }
    }

    private func connector(lit: Bool) -> some View {
        Rectangle()
            .fill(lit ? color : FLTheme.Palette.rim.opacity(0.45))
            .frame(width: Metrics.connector, height: 2)
            .offset(y: -8)
    }

    private func learnedAny(_ pathSkills: [SkillDefinition], _ tier: SkillTier) -> Bool {
        pathSkills.contains { $0.tier == tier && draft.rank(of: $0.id) > 0 }
    }

    private func node(for skill: SkillDefinition) -> some View {
        let rank = draft.rank(of: skill.id)
        let denial = SkillTreeRules.standard.denial(for: skill, in: draft, availablePoints: max(available, 1))
        let state: SkillNodeView.NodeState
        if rank >= skill.maxRank {
            state = .mastered
        } else if rank > 0 {
            state = denial == nil && available > 0 ? .learnedCanRank : .learned
        } else {
            state = denial == nil ? (available > 0 ? .available : .reachable) : .locked
        }
        return SkillNodeView(skill: skill, rank: rank, isNew: rank > committed.rank(of: skill.id), state: state,
                             color: color, isSelected: selectedSkillID == skill.id)
            .frame(width: Metrics.node)
            .id(skill.id)
            .onTapGesture { onSelect(skill) }
    }
}

// MARK: - Pieces

private struct TierHeader: View {
    let tier: SkillTier
    let unlocked: Bool
    let threshold: Int

    var body: some View {
        HStack(spacing: 4) {
            if !unlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(tier == .capstone ? "CAPSTONE" : tier.displayName.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.2)
            if threshold > 0 {
                Text("\(threshold)")
                    .font(FLTheme.Typeface.number(10))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
        }
        .foregroundStyle(unlocked ? FLTheme.Palette.parchment : FLTheme.Palette.locked)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityLabel("\(tier.displayName), needs \(threshold) points")
    }
}

private struct PathLabel: View {
    let path: PathDefinition
    let points: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(path.name)
                .font(FLTheme.Typeface.heading(13))
                .foregroundStyle(points > 0 ? color : FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(points > 0 ? "\(points) pts" : "—")
                .font(FLTheme.Typeface.number(10))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
        }
        .padding(.trailing, 6)
    }
}

/// A single skill: its sigil, rank pips and name.
struct SkillNodeView: View {
    enum NodeState {
        /// Requirements unmet.
        case locked
        /// Requirements met but no points to spend.
        case reachable
        /// Can be learned now.
        case available
        case learned
        /// Learned, and another rank can be bought now.
        case learnedCanRank
        case mastered
    }

    let skill: SkillDefinition
    let rank: Int
    /// Points added in this visit to the tree.
    let isNew: Bool
    let state: NodeState
    let color: Color
    let isSelected: Bool

    private var isKeystone: Bool { skill.tier == .capstone }
    private var isUltimate: Bool { skill.kind == .ultimate }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                sigil
                    .frame(width: 46, height: 46)
                Image(systemName: skill.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
                if isNew {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(FLTheme.Palette.emberBright)
                        .offset(x: 18, y: -18)
                }
                Text("\(rank)/\(skill.maxRank)")
                    .font(FLTheme.Typeface.number(9))
                    .foregroundStyle(rank > 0 ? FLTheme.Palette.abyss : FLTheme.Palette.parchmentDim)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(rank > 0 ? AnyShapeStyle(FLTheme.Palette.parchment)
                                                        : AnyShapeStyle(FLTheme.Palette.stone)))
                    .offset(y: 22)
            }
            .frame(width: 54, height: 54)
            Text(skill.name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(state == .locked ? FLTheme.Palette.locked : FLTheme.Palette.parchment)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(height: 22, alignment: .top)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(skill.name), rank \(rank) of \(skill.maxRank)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var sigil: some View {
        if isKeystone {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(rim, lineWidth: rimWidth))
                .rotationEffect(.degrees(45))
                .scaleEffect(0.78)
        } else {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(rim, lineWidth: rimWidth))
                .overlay(isUltimate ? Circle().strokeBorder(FLTheme.Palette.ember.opacity(0.8), lineWidth: 1)
                    .padding(4) : nil)
        }
    }

    private var fill: AnyShapeStyle {
        switch state {
        case .locked, .reachable:
            return AnyShapeStyle(FLTheme.Palette.stone)
        case .available:
            return AnyShapeStyle(FLTheme.Palette.stoneRaised)
        case .learned, .learnedCanRank:
            return AnyShapeStyle(color.opacity(0.6))
        case .mastered:
            return AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom))
        }
    }

    private var rim: Color {
        if isSelected { return .white }
        switch state {
        case .locked: return FLTheme.Palette.locked.opacity(0.6)
        case .reachable: return FLTheme.Palette.rim
        case .available, .learnedCanRank: return FLTheme.Palette.emberBright
        case .learned: return color
        case .mastered: return Color(red: 1, green: 0.84, blue: 0.45)
        }
    }

    private var rimWidth: CGFloat {
        isSelected || state == .available || state == .learnedCanRank || state == .mastered ? 2.5 : 1.2
    }

    private var iconColor: Color {
        switch state {
        case .locked: return FLTheme.Palette.locked
        case .reachable: return FLTheme.Palette.parchmentDim
        default: return FLTheme.Palette.parchment
        }
    }
}
