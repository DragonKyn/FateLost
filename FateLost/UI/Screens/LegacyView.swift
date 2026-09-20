import SwiftUI

/// Legacy: five hundred permanent upgrades, and a rack of weapons to start
/// runs with. Both are bought with echoes, so the two tabs compete for the
/// same currency — long-term power against a different opening.
///
/// Laid out for a phone in landscape, like the skill tree: a strand rail on
/// the left, the board filling the middle, and a detail card that slides in
/// only while a node is selected. A strand is a column of ten tiers, five
/// nodes across, and it scrolls under your thumb.
struct LegacyView: View {
    /// Which half of Legacy is on show.
    private enum Tab: String, CaseIterable, Identifiable {
        case board
        case armoury

        var id: String { rawValue }
        var title: String { self == .board ? "Board" : "Armoury" }
    }

    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services

    @State private var tab: Tab = .board
    @State private var branch: LegacyBranch = .body
    @State private var selected: LegacyNode?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.85), FLTheme.Palette.abyss.opacity(0.95)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                toolbar
                if tab == .armoury {
                    ArmouryBoard(profile: services.profile, onBuy: buy(weapon:), onMaster: master(weapon:))
                } else {
                    board
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .animation(.easeOut(duration: 0.18), value: selected)
        .animation(.easeOut(duration: 0.18), value: branch)
        .animation(.easeOut(duration: 0.18), value: tab)
    }

    private var board: some View {
        HStack(spacing: 8) {
            StrandRail(selection: $branch, profile: services.profile) { tapped in
                services.haptics.play(.uiTap)
                branch = tapped
                selected = nil
            }
            .frame(width: 62)

            BranchBoard(branch: branch, profile: services.profile, selected: selected) { node in
                services.haptics.play(.uiTap)
                selected = selected?.id == node.id ? nil : node
            }

            if let node = selected {
                NodeCard(node: node, profile: services.profile,
                         onBuy: { buy(node) },
                         onClose: { selected = nil })
                    .frame(width: 262)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("LEGACY")
                    .font(FLTheme.Typeface.title(22))
                    .tracking(5)
                    .foregroundStyle(FLTheme.Palette.parchment)
                Text(subtitle)
                    .font(FLTheme.Typeface.body(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 176)
            .onChange(of: tab) { _, _ in
                services.haptics.play(.uiTap)
                selected = nil
            }

            EchoBadge(echoes: services.profile.echoes)

            Button("Back") {
                services.audio.play(.uiBack)
                router.show(.mainMenu)
            }
            .buttonStyle(.flSecondaryCompact)
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 46)
    }

    private var subtitle: String {
        switch tab {
        case .board:
            return "\(services.profile.unlocked.count) of \(LegacyTree.all.count) taken"
        case .armoury:
            let held = StarterWeapons.all.filter { services.profile.isUnlocked($0) }.count
            return "\(held) of \(StarterWeapons.all.count) weapons on the rack"
        }
    }

    private func buy(weapon: WeaponDefinition) {
        guard services.buyWeapon(weapon) else {
            services.audio.play(.uiBack)
            return
        }
        services.audio.play(.skillLearn)
        services.haptics.play(.uiTap)
    }

    private func master(weapon: WeaponDefinition) {
        guard services.masterWeapon(weapon) else {
            services.audio.play(.uiBack)
            return
        }
        services.audio.play(.skillLearn)
        services.haptics.play(.uiTap)
    }

    private func buy(_ node: LegacyNode) {
        guard services.buyLegacy(node) else {
            services.audio.play(.uiBack)
            return
        }
        services.audio.play(.skillLearn)
        services.haptics.play(.uiTap)
        // Keep the card on screen so the next tier is one tap away.
        selected = LegacyTree.node(node.id)
    }
}

// MARK: - Echoes

private struct EchoBadge: View {
    let echoes: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("\(echoes)")
                .font(FLTheme.Typeface.number(17))
        }
        .foregroundStyle(FLTheme.Palette.abyss)
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Capsule().fill(FLTheme.Palette.emberBright))
        .overlay(Capsule().strokeBorder(FLTheme.Palette.rim, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(echoes) echoes")
    }
}

// MARK: - Strand rail

private struct StrandRail: View {
    @Binding var selection: LegacyBranch
    let profile: LegacyProfile
    let onSelect: (LegacyBranch) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(LegacyBranch.allCases) { branch in
                    sigil(branch)
                        .onTapGesture { onSelect(branch) }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func sigil(_ branch: LegacyBranch) -> some View {
        let isSelected = branch == selection
        let taken = profile.count(in: branch)
        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isSelected ? FLTheme.Palette.emberBright : Color.clear)
                .frame(width: 3, height: 34)
            VStack(spacing: 1) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(branch.tint.color.opacity(isSelected ? 0.9 : 0.28))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(isSelected ? FLTheme.Palette.emberBright
                                                                 : FLTheme.Palette.rim,
                                                       lineWidth: isSelected ? 2 : 1))
                        .overlay(Image(systemName: branch.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FLTheme.Palette.parchment))
                    if taken > 0 {
                        Text("\(taken)")
                            .font(FLTheme.Typeface.number(10))
                            .foregroundStyle(FLTheme.Palette.abyss)
                            .padding(.horizontal, 4)
                            .background(Capsule().fill(FLTheme.Palette.emberBright))
                            .offset(x: 5, y: -2)
                    }
                }
                Text(branch.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isSelected ? FLTheme.Palette.parchment : FLTheme.Palette.parchmentDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(branch.name), \(taken) taken")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Board

/// One strand: ten tiers down the screen, five nodes across each.
private struct BranchBoard: View {
    let branch: LegacyBranch
    let profile: LegacyProfile
    let selected: LegacyNode?
    let onSelect: (LegacyNode) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text(branch.subtitle)
                    .font(FLTheme.Typeface.body(12))
                    .italic()
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .padding(.leading, 2)

                ForEach(1...LegacyTree.tierCount, id: \.self) { tier in
                    tierRow(tier)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tierRow(_ tier: Int) -> some View {
        let nodes = LegacyTree.nodes(in: branch, tier: tier)
        let open = nodes.first.map { profile.isReachable($0) } ?? false
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("TIER \(tier)")
                    .font(FLTheme.Typeface.label(10))
                    .foregroundStyle(open ? FLTheme.Palette.parchmentDim : FLTheme.Palette.locked)
                if !open {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(FLTheme.Palette.locked)
                }
                Rectangle()
                    .fill(FLTheme.Palette.rim.opacity(0.5))
                    .frame(height: 1)
            }
            HStack(spacing: 6) {
                ForEach(nodes) { node in
                    NodePip(node: node,
                            isTaken: profile.isUnlocked(node),
                            isOpen: open,
                            isAffordable: profile.canAfford(node),
                            isSelected: selected?.id == node.id)
                        .onTapGesture { onSelect(node) }
                }
            }
        }
    }
}

private struct NodePip: View {
    let node: LegacyNode
    let isTaken: Bool
    let isOpen: Bool
    let isAffordable: Bool
    let isSelected: Bool

    private var fill: Color {
        if isTaken { return node.branch.tint.color.opacity(0.85) }
        if !isOpen { return FLTheme.Palette.stoneRaised.opacity(0.4) }
        return FLTheme.Palette.stoneRaised.opacity(isAffordable ? 0.95 : 0.6)
    }

    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(fill)
                .frame(height: 38)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? FLTheme.Palette.emberBright : FLTheme.Palette.rim,
                                  lineWidth: isSelected ? 2 : 1))
                .overlay(
                    Image(systemName: isTaken ? "checkmark" : (isOpen ? node.branch.symbol : "lock.fill"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isTaken ? FLTheme.Palette.abyss
                                                 : (isOpen ? FLTheme.Palette.parchment : FLTheme.Palette.locked))
                )
            Text(node.effectText)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(isTaken ? FLTheme.Palette.parchment : FLTheme.Palette.parchmentDim)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(node.name), \(node.effectText)")
        .accessibilityValue(isTaken ? "Taken" : "Costs \(node.cost) echoes")
    }
}

// MARK: - Detail

private struct NodeCard: View {
    let node: LegacyNode
    let profile: LegacyProfile
    let onBuy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(node.branch.name.uppercased())
                        .font(FLTheme.Typeface.label(10))
                        .tracking(2)
                        .foregroundStyle(node.branch.tint.color)
                    Text(node.name)
                        .font(FLTheme.Typeface.heading(19))
                        .foregroundStyle(FLTheme.Palette.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 24)
                    Text(node.effectText)
                        .font(FLTheme.Typeface.number(17))
                        .foregroundStyle(FLTheme.Palette.emberBright)
                    Text("A small thing, kept forever. Tier \(node.tier) of \(LegacyTree.tierCount).")
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }

            VStack(spacing: 6) {
                if let denial = profile.denial(for: node) {
                    Text(denial)
                        .font(FLTheme.Typeface.body(11))
                        .foregroundStyle(profile.isUnlocked(node) ? FLTheme.Palette.parchmentDim
                                                                  : FLTheme.Palette.blood)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                Button("Take · \(node.cost)", action: onBuy)
                    .buttonStyle(.flPrimaryCompact)
                    .disabled(profile.denial(for: node) != nil)
                    .frame(maxWidth: .infinity)
            }
            .padding(14)
            .background(Color.black.opacity(0.25))
        }
        .flPanel()
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .frame(width: 30, height: 30)
            }
            .accessibilityLabel("Close")
        }
    }
}
