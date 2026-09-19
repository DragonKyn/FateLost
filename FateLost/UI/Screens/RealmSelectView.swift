import SwiftUI

struct RealmSelectView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 20)

            VStack(alignment: .leading, spacing: 18) {
                FLScreenHeader(title: "Choose a Realm",
                               subtitle: "Each conquered realm opens the way to the next.") {
                    services.audio.play(.uiBack)
                    router.show(.mainMenu)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(RealmCatalog.all) { realm in
                            let unlocked = services.isRealmUnlocked(realm)
                            RealmCard(realm: realm,
                                      isUnlocked: unlocked,
                                      isConquered: services.realmProgress.conquered.contains(realm.id),
                                      prerequisite: RealmUnlockRules.prerequisite(for: realm, catalog: RealmCatalog.all))
                                .onTapGesture {
                                    guard unlocked else { return }
                                    services.haptics.play(.uiTap)
                                    services.audio.play(.uiConfirm)
                                    router.show(.weaponSelect(realm.id))
                                }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(FLTheme.Metrics.screenPadding)
        }
    }
}

private struct RealmCard: View {
    let realm: RealmDefinition
    let isUnlocked: Bool
    let isConquered: Bool
    let prerequisite: RealmDefinition?

    private var accent: Color {
        realm.arena.theme.atmosphere.particleColor.withAlpha(1).color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(romanNumeral(realm.order))
                    .font(FLTheme.Typeface.heading(15))
                    .foregroundStyle(isUnlocked ? accent : FLTheme.Palette.locked)
                Spacer()
                if isConquered {
                    Label("Conquered", systemImage: "crown.fill")
                        .font(FLTheme.Typeface.label(11))
                        .foregroundStyle(FLTheme.Palette.ember)
                } else if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(FLTheme.Palette.locked)
                }
            }

            groundSwatch
                .frame(height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(realm.name)
                .font(FLTheme.Typeface.heading(20))
                .foregroundStyle(isUnlocked ? FLTheme.Palette.parchment : FLTheme.Palette.locked)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(realm.tagline)
                .font(FLTheme.Typeface.body(13))
                .italic()
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if isUnlocked {
                HStack(spacing: 14) {
                    stat(label: "Conquest", value: realm.conquestWave.map { "Wave \($0)" } ?? "Endless")
                    stat(label: "Legacy", value: String(format: "×%.2f", realm.legacyMultiplier))
                }
            } else if let prerequisite {
                Text("Conquer \(prerequisite.name) to unlock")
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.locked)
            }
        }
        .padding(16)
        .frame(width: 230, height: 290)
        .flPanel(highlighted: isUnlocked && !isConquered)
        .opacity(isUnlocked ? 1 : 0.6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isUnlocked ? "Opens weapon selection" : "Locked")
    }

    /// Stripes of the realm's ground palette as a quick visual identity.
    private var groundSwatch: some View {
        let styles = realm.arena.theme.groundStyles
        return HStack(spacing: 0) {
            ForEach(styles.indices, id: \.self) { index in
                styles[index].base.color
                    .overlay(styles[index].detail.color.opacity(0.35).frame(height: 10), alignment: .bottom)
            }
        }
        .saturation(isUnlocked ? 1 : 0)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FLSectionLabel(text: label)
            Text(value)
                .font(FLTheme.Typeface.number(15))
                .foregroundStyle(FLTheme.Palette.parchment)
        }
    }

    private func romanNumeral(_ number: Int) -> String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
        return number >= 1 && number <= numerals.count ? numerals[number - 1] : "\(number)"
    }
}
