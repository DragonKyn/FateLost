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
                    Text("Forge Your Fate")
                        .font(FLTheme.Typeface.heading(17))
                        .italic()
                        .foregroundStyle(FLTheme.Palette.parchmentDim)

                    Button {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.show(.character)
                    } label: {
                        HStack(spacing: 10) {
                            HeroPortrait(look: services.hero, height: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Choose Your Fate")
                                    .font(FLTheme.Typeface.heading(15))
                                    .foregroundStyle(FLTheme.Palette.parchment)
                                Text("Character Customization")
                                    .font(FLTheme.Typeface.body(11))
                                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .flPanel()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                    .accessibilityLabel("Choose Your Fate: customise your hero")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    Button("Play") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.show(.realmSelect)
                    }
                    .buttonStyle(.flPrimary)

                    Button("Multiplayer") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.show(.multiplayer)
                    }
                    .buttonStyle(.flSecondaryCompact)

                    Button("Legacy") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.show(.legacy)
                    }
                    .buttonStyle(.flSecondaryCompact)
                    .overlay(alignment: .topTrailing) { echoBadge }

                    Button("Statistics") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.show(.statistics)
                    }
                    .buttonStyle(.flSecondaryCompact)

                    Button("Settings") {
                        router.isSettingsPresented = true
                    }
                    .buttonStyle(.flSecondaryCompact)

                    if services.isDeveloperModeOn {
                        Button {
                            router.isDeveloperPanelPresented = true
                        } label: {
                            Label("Developer", systemImage: "wrench.and.screwdriver")
                        }
                        .buttonStyle(.flSecondaryCompact)
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
