import SwiftUI

/// The Armoury: the second half of Legacy.
///
/// The board makes the hero permanently a little better; the rack changes
/// what the first five minutes of a run feel like. Buying a weapon opens it
/// for every future run, and each of its five ranks of mastery only ever
/// counts on runs actually started with it — so mastery is a reason to come
/// back to a weapon rather than a tax on trying a new one.
struct ArmouryBoard: View {
    let profile: LegacyProfile
    let onBuy: (WeaponDefinition) -> Void
    let onMaster: (WeaponDefinition) -> Void

    @State private var selectedID: WeaponID = StarterWeapons.sword.id

    private var selected: WeaponDefinition {
        StarterWeapons.definition(for: selectedID) ?? StarterWeapons.sword
    }

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                    ForEach(StarterWeapons.all) { weapon in
                        RackTile(weapon: weapon,
                                 isUnlocked: profile.isUnlocked(weapon),
                                 rank: profile.rank(of: weapon),
                                 isSelected: weapon.id == selectedID)
                            .onTapGesture { selectedID = weapon.id }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity)

            WeaponCard(weapon: selected, profile: profile,
                       onBuy: { onBuy(selected) }, onMaster: { onMaster(selected) })
                .frame(width: 288)
        }
        .animation(.easeOut(duration: 0.16), value: selectedID)
    }
}

/// What a weapon looks like on the rack: enough to choose by, no more.
private struct RackTile: View {
    let weapon: WeaponDefinition
    let isUnlocked: Bool
    let rank: Int
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if isUnlocked {
                    WeaponIcon(weapon: weapon, size: 30)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FLTheme.Palette.locked)
                        .frame(width: 30, height: 30)
                }
                Spacer(minLength: 0)
                Text(weapon.damageType.displayName)
                    .font(FLTheme.Typeface.label(10))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
            Text(weapon.name)
                .font(FLTheme.Typeface.heading(14))
                .foregroundStyle(isUnlocked ? FLTheme.Palette.parchment : FLTheme.Palette.parchmentDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if isUnlocked {
                MasteryPips(rank: rank)
            } else {
                Text("\(WeaponMastery.unlockCost(weapon)) echoes")
                    .font(FLTheme.Typeface.number(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .flPanel(highlighted: isSelected)
        .opacity(isUnlocked ? 1 : 0.7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var label: String {
        guard isUnlocked else {
            return "\(weapon.name), locked, \(WeaponMastery.unlockCost(weapon)) echoes"
        }
        return "\(weapon.name), mastery \(rank) of \(WeaponMastery.maxRank)"
    }
}

/// Five pips: how far along a weapon's mastery is, at a glance.
private struct MasteryPips: View {
    let rank: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<WeaponMastery.maxRank, id: \.self) { index in
                Circle()
                    .fill(index < rank ? FLTheme.Palette.emberBright : FLTheme.Palette.stoneRaised)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().strokeBorder(FLTheme.Palette.rim, lineWidth: 0.5))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The selected weapon in full, with whatever can be bought for it.
private struct WeaponCard: View {
    let weapon: WeaponDefinition
    let profile: LegacyProfile
    let onBuy: () -> Void
    let onMaster: () -> Void

    private var rank: Int { profile.rank(of: weapon) }
    private var isUnlocked: Bool { profile.isUnlocked(weapon) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 10) {
                        WeaponIcon(weapon: weapon, size: 40)
                        Text(weapon.name)
                            .font(FLTheme.Typeface.title(19))
                            .foregroundStyle(FLTheme.Palette.parchment)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(.trailing, 4)

                    Text(weapon.summary)
                        .font(FLTheme.Typeface.body(13))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .fixedSize(horizontal: false, vertical: true)

                    FLSectionLabel(text: "In Hand")
                    statRow("Damage", String(format: "%.0f", weapon.baseDamage))
                    statRow("Speed", String(format: "%.2f/s", weapon.attackSpeed))
                    statRow("Range", String(format: "%.1f", weapon.range))
                    statRow("Reaches", WeaponGlyph.deliveryText(for: weapon))

                    FLSectionLabel(text: "Mastery")
                    HStack(spacing: 8) {
                        MasteryPips(rank: rank)
                        Text("\(rank) of \(WeaponMastery.maxRank)")
                            .font(FLTheme.Typeface.number(12))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                    }
                    Text(WeaponMastery.rankText(for: weapon))
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                    if rank > 0 {
                        Text(heldText)
                            .font(FLTheme.Typeface.body(12))
                            .foregroundStyle(FLTheme.Palette.emberBright)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Mastery only counts on runs started with this weapon.")
                        .font(FLTheme.Typeface.body(11))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let denial = denial {
                    Label(denial, systemImage: "lock.fill")
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !isUnlocked {
                    Button("Unlock · \(WeaponMastery.unlockCost(weapon))") { onBuy() }
                        .buttonStyle(.flPrimaryCompact)
                        .disabled(profile.weaponDenial(for: weapon) != nil)
                } else if rank < WeaponMastery.maxRank {
                    Button("Master · \(WeaponMastery.rankCost(rank + 1))") { onMaster() }
                        .buttonStyle(.flPrimaryCompact)
                        .disabled(profile.masteryDenial(for: weapon) != nil)
                } else {
                    Text("Mastered")
                        .font(FLTheme.Typeface.heading(15))
                        .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.45))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(12)
            .background(FLTheme.Palette.abyss.opacity(0.5))
        }
        .frame(maxHeight: .infinity)
        .flPanel()
        .clipShape(RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous))
    }

    /// What the ranks already bought are worth, spelled out.
    private var heldText: String {
        let held = WeaponMastery.modifiers(for: weapon, rank: rank)
        return "Held: " + held.map(\.displayText).joined(separator: ", ")
    }

    private var denial: String? {
        let reason = isUnlocked ? profile.masteryDenial(for: weapon) : profile.weaponDenial(for: weapon)
        return reason == "Mastered" || reason == "Already on the rack" ? nil : reason
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
            Spacer(minLength: 4)
            Text(value)
                .font(FLTheme.Typeface.number(12))
                .foregroundStyle(FLTheme.Palette.parchment)
        }
        .accessibilityElement(children: .combine)
    }
}

/// How a weapon is shown when there is no room for its art.
enum WeaponGlyph {
    static func symbol(for weapon: WeaponDefinition) -> String {
        switch weapon.delivery {
        case .meleeArc(let degrees):
            return degrees >= 200 ? "arrow.triangle.2.circlepath" : "shield.lefthalf.filled"
        case .projectile(let profile):
            if profile.returns { return "arrow.uturn.left" }
            return profile.splashRadius > 0 ? "sparkles" : "scope"
        }
    }

    static func deliveryText(for weapon: WeaponDefinition) -> String {
        switch weapon.delivery {
        case .meleeArc(let degrees):
            return "\(Int(degrees))° arc"
        case .projectile(let profile):
            if profile.returns { return "Thrown, returns" }
            if profile.splashRadius > 0 { return "Bursts on impact" }
            return profile.pierce > 0 ? "Passes through \(profile.pierce)" : "Single target"
        }
    }
}
