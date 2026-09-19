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

            VStack(alignment: .leading, spacing: 18) {
                FLScreenHeader(title: "Take Up a Weapon",
                               subtitle: "\(realm.name) — your weapon does not decide what you become.") {
                    services.audio.play(.uiBack)
                    router.show(.realmSelect)
                }

                HStack(spacing: 16) {
                    ForEach(StarterWeapons.all) { weapon in
                        let unlocked = StarterWeapons.defaultUnlocked.contains(weapon.id)
                        WeaponCard(weapon: weapon, isSelected: weapon.id == selectedID, isUnlocked: unlocked)
                            .onTapGesture {
                                guard unlocked else { return }
                                services.haptics.play(.uiTap)
                                services.audio.play(.uiConfirm)
                                selectedID = weapon.id
                            }
                    }
                }
                .frame(maxHeight: .infinity)

                HStack {
                    Text("More weapons are unlocked through Legacy.")
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
            .padding(FLTheme.Metrics.screenPadding)
        }
    }
}

private struct WeaponCard: View {
    let weapon: WeaponDefinition
    let isSelected: Bool
    let isUnlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isSelected ? FLTheme.Palette.ember : FLTheme.Palette.parchmentDim)
                Spacer()
                Text(weapon.damageType.displayName)
                    .font(FLTheme.Typeface.label(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }

            Text(weapon.name)
                .font(FLTheme.Typeface.heading(21))
                .foregroundStyle(FLTheme.Palette.parchment)

            Text(weapon.summary)
                .font(FLTheme.Typeface.body(13))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            VStack(spacing: 6) {
                statRow("Damage", value: String(format: "%.0f", weapon.baseDamage), fraction: weapon.baseDamage / 14)
                statRow("Speed", value: String(format: "%.2f/s", weapon.attackSpeed), fraction: weapon.attackSpeed / 1.4)
                statRow("Range", value: String(format: "%.1f", weapon.range), fraction: weapon.range / 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .flPanel(highlighted: isSelected)
        .opacity(isUnlocked ? 1 : 0.5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var symbol: String {
        switch weapon.delivery {
        case .meleeArc: return "shield.lefthalf.filled"
        case .projectile(let profile): return profile.splashRadius > 0 ? "sparkles" : "scope"
        }
    }

    private func statRow(_ label: String, value: String, fraction: Double) -> some View {
        HStack(spacing: 8) {
            FLSectionLabel(text: label)
                .frame(width: 58, alignment: .leading)
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
