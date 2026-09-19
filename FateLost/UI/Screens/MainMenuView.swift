import SwiftUI

struct MainMenuView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services

    var body: some View {
        ZStack {
            EmberBackground()

            HStack(alignment: .center, spacing: 48) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("FATE LOST")
                        .font(FLTheme.Typeface.title(56))
                        .tracking(8)
                        .foregroundStyle(FLTheme.Palette.parchment)
                        .shadow(color: FLTheme.Palette.ember.opacity(0.4), radius: 16)
                    Text("Fate forgot you. Make it remember.")
                        .font(FLTheme.Typeface.heading(17))
                        .italic()
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    Button("Play") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.show(.realmSelect)
                    }
                    .buttonStyle(.flPrimary)

                    Button("Legacy") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.show(.legacy)
                    }
                    .buttonStyle(.flSecondary)
                    .overlay(alignment: .topTrailing) { echoBadge }

                    Button("Statistics") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.show(.statistics)
                    }
                    .buttonStyle(.flSecondary)

                    Button("Settings") {
                        router.isSettingsPresented = true
                    }
                    .buttonStyle(.flSecondary)

                    if DeveloperOptions.isAvailable {
                        Button {
                            router.isDeveloperPanelPresented = true
                        } label: {
                            Label("Developer", systemImage: "wrench.and.screwdriver")
                        }
                        .buttonStyle(.flSecondary)
                    }
                }
                .frame(width: 260)
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding * 2)
        }
    }

    /// Unspent echoes, so the board asks to be visited without nagging.
    @ViewBuilder
    private var echoBadge: some View {
        let echoes = services.profile.echoes
        if echoes > 0 {
            Text("\(echoes)")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(FLTheme.Palette.abyss)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(FLTheme.Palette.emberBright))
                .offset(x: 6, y: -6)
                .accessibilityLabel("\(echoes) echoes to spend")
        }
    }
}
