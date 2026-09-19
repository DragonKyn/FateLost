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

                    Button("Legacy") {}
                        .buttonStyle(.flSecondary)
                        .disabled(true)
                        .overlay(alignment: .topTrailing) { comingSoonBadge }

                    Button("Statistics") {}
                        .buttonStyle(.flSecondary)
                        .disabled(true)
                        .overlay(alignment: .topTrailing) { comingSoonBadge }

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

    private var comingSoonBadge: some View {
        Text("SOON")
            .font(.system(size: 9, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(FLTheme.Palette.abyss)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(FLTheme.Palette.parchmentDim))
            .offset(x: 6, y: -6)
    }
}
