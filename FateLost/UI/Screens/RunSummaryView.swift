import SwiftUI

/// Shown when the player falls ("Fate Sealed"): what the run achieved, and
/// the way back in.
///
/// Legacy rewards join this screen in Phase 6; conquest gets its own
/// variant when realm bosses arrive.
struct RunSummaryView: View {
    let summary: RunSummary
    let realm: RealmDefinition
    let weapon: WeaponDefinition
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.35), Color.black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            HStack(alignment: .center, spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("FATE SEALED")
                        .font(FLTheme.Typeface.title(52))
                        .tracking(8)
                        .foregroundStyle(FLTheme.Palette.parchment)
                        .shadow(color: FLTheme.Palette.blood.opacity(0.8), radius: 18)
                    Text("\(realm.name) · \(weapon.name)")
                        .font(FLTheme.Typeface.heading(17))
                        .italic()
                        .foregroundStyle(FLTheme.Palette.parchmentDim)

                    Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
                        statRow("Survived", formatTime(summary.secondsSurvived))
                        statRow("Enemies slain", "\(summary.stats.kills)")
                        statRow("Damage dealt", "\(Int(summary.stats.damageDealt.rounded()))")
                        statRow("Critical hits", "\(summary.stats.criticalHits)")
                        statRow("Largest horde", "\(summary.stats.mostEnemiesAlive)")
                    }
                    .padding(.top, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    Button("Rise Again", action: onRetry)
                        .buttonStyle(.flPrimary)
                    Button("Return to Menu", action: onMenu)
                        .buttonStyle(.flSecondary)
                }
                .frame(width: 250)
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding * 2)
        }
        .accessibilityElement(children: .contain)
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        GridRow {
            FLSectionLabel(text: title)
            Text(value)
                .font(FLTheme.Typeface.number(20))
                .foregroundStyle(FLTheme.Palette.parchment)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
