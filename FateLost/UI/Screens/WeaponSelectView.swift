import SwiftUI

/// Pick the weapon to start with. It shapes the opening minutes of a run —
/// never the class.
struct WeaponSelectView: View {
    let realm: RealmDefinition

    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var selectedID: WeaponID = StarterWeapons.sword.id

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 20)

            VStack(alignment: .leading, spacing: 10) {
                FLScreenHeader(title: "Take Up a Weapon",
                               subtitle: "\(realm.name) — your weapon does not decide what you become.") {
                    services.audio.play(.uiBack)
                    router.show(.realmSelect)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(StarterWeapons.all) { weapon in
                            let unlocked = services.isUnlocked(weapon)
                            WeaponCard(weapon: weapon, isSelected: weapon.id == selectedID,
                                       isUnlocked: unlocked, mastery: services.profile.rank(of: weapon))
                                .frame(width: 236)
                                .onTapGesture {
                                    guard unlocked else { return }
                                    services.haptics.play(.uiTap)
                                    services.audio.play(.uiConfirm)
                                    selectedID = weapon.id
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
                .frame(maxHeight: .infinity)

                HStack {
                    Text("More weapons, and mastery of the ones you have, come from the Legacy armoury.")
                        .font(FLTheme.Typeface.body(13))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                    Spacer()
                    Button("Enter the Realm") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.startRun(.new(realm: realm.id, weapon: selectedID), services: services)
                    }
                    .buttonStyle(.flPrimary)
                    .frame(width: 260)
                }
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
            .padding(.vertical, FLTheme.Metrics.screenPaddingVertical)
        }
    }
}

private struct WeaponCard: View {
    let weapon: WeaponDefinition
    let isSelected: Bool
    let isUnlocked: Bool
    var mastery = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: isUnlocked ? symbol : "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? FLTheme.Palette.ember : FLTheme.Palette.parchmentDim)
                Spacer()
                Text(weapon.damageType.displayName)
                    .font(FLTheme.Typeface.label(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }

            Text(weapon.name)
                .font(FLTheme.Typeface.heading(20))
                .foregroundStyle(FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(weapon.summary)
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 2)

            if isUnlocked, mastery > 0 {
                Text("Mastery \(mastery) of \(WeaponMastery.maxRank)")
                    .font(FLTheme.Typeface.number(12))
                    .foregroundStyle(FLTheme.Palette.emberBright)
            } else if !isUnlocked {
                Text("Locked · \(WeaponMastery.unlockCost(weapon)) echoes")
                    .font(FLTheme.Typeface.number(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }

            VStack(spacing: 5) {
                statRow("Damage", value: String(format: "%.0f", weapon.baseDamage),
                        fraction: weapon.baseDamage / 24)
                statRow("Speed", value: String(format: "%.2f/s", weapon.attackSpeed),
                        fraction: weapon.attackSpeed / 2.4)
                statRow("Range", value: String(format: "%.1f", weapon.range), fraction: weapon.range / 8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .flPanel(highlighted: isSelected)
        .opacity(isUnlocked ? 1 : 0.5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var symbol: String { WeaponGlyph.symbol(for: weapon) }

    private func statRow(_ label: String, value: String, fraction: Double) -> some View {
        HStack(spacing: 8) {
            FLSectionLabel(text: label)
                .frame(width: 68, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(FLTheme.Palette.abyss)
                    Capsule()
                        .fill(isSelected ? FLTheme.Palette.ember : FLTheme.Palette.rim)
                        .frame(width: proxy.size.width * min(1, max(0.05, fraction)))
                }
            }
            .frame(height: 6)
            Text(value)
                .font(FLTheme.Typeface.number(13))
                .foregroundStyle(FLTheme.Palette.parchment)
                .frame(width: 52, alignment: .trailing)
        }
    }
}
