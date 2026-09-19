import SwiftUI

/// The in-run screen: the SpriteKit view plus SwiftUI chrome around it.
struct GameplayScreen: View {
    let session: GameSession

    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var showRealmTitle = true

    var body: some View {
        ZStack {
            GameViewContainer(scene: session.scene, showsDebugStatistics: false)
                .ignoresSafeArea()

            GameplayHUDOverlay(session: session,
                               onPause: { session.pause() },
                               onDeveloper: { openDeveloperPanel() })

            if showRealmTitle {
                RealmTitleCard(realm: session.realm)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if session.isPaused {
                PauseMenu(
                    onResume: { session.resume() },
                    onSettings: { router.isSettingsPresented = true },
                    onAbandon: { router.endRun() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isPaused)
        .task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 1.2)) { showRealmTitle = false }
        }
    }

    private func openDeveloperPanel() {
        session.pause()
        router.isDeveloperPanelPresented = true
    }
}

/// Minimal always-on information. Kept small and at the edges so the
/// battlefield stays readable.
private struct GameplayHUDOverlay: View {
    let session: GameSession
    let onPause: () -> Void
    let onDeveloper: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HealthBar(current: session.hud.health, maximum: session.hud.maxHealth)
                        .frame(width: 190, height: 14)
                    HStack(spacing: 10) {
                        Text("LV \(session.hud.level)")
                        Text("WAVE \(session.hud.wave)")
                        Text(formatTime(session.hud.elapsedSeconds))
                    }
                    .font(FLTheme.Typeface.number(13))
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .shadow(color: .black, radius: 2)
                }
                Spacer()
                if DeveloperOptions.isAvailable {
                    hudButton(systemImage: "wrench.and.screwdriver", label: "Developer tools", action: onDeveloper)
                }
                hudButton(systemImage: "pause.fill", label: "Pause", action: onPause)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func hudButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FLTheme.Palette.parchment)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .overlay(Circle().strokeBorder(FLTheme.Palette.rim, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct HealthBar: View {
    let current: Double
    let maximum: Double

    var body: some View {
        GeometryReader { proxy in
            let fraction = maximum > 0 ? min(1, max(0, current / maximum)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.6))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.75, green: 0.16, blue: 0.14),
                                                  Color(red: 0.52, green: 0.08, blue: 0.08)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: proxy.size.width * fraction)
                Capsule().strokeBorder(FLTheme.Palette.rim, lineWidth: 1)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Health")
        .accessibilityValue("\(Int(current)) of \(Int(maximum))")
    }
}

/// Fades in the realm name as the run begins.
private struct RealmTitleCard: View {
    let realm: RealmDefinition

    var body: some View {
        VStack(spacing: 6) {
            Text(realm.name.uppercased())
                .font(FLTheme.Typeface.title(38))
                .tracking(6)
                .foregroundStyle(FLTheme.Palette.parchment)
            Text(realm.tagline)
                .font(FLTheme.Typeface.heading(16))
                .italic()
                .foregroundStyle(FLTheme.Palette.parchmentDim)
        }
        .shadow(color: .black.opacity(0.9), radius: 10)
        .offset(y: -60)
    }
}

private struct PauseMenu: View {
    let onResume: () -> Void
    let onSettings: () -> Void
    let onAbandon: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("PAUSED")
                    .font(FLTheme.Typeface.title(34))
                    .tracking(6)
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .padding(.bottom, 6)
                Button("Resume", action: onResume)
                    .buttonStyle(.flPrimary)
                Button("Settings", action: onSettings)
                    .buttonStyle(.flSecondary)
                Button("Abandon Run", action: onAbandon)
                    .buttonStyle(.flDestructive)
            }
            .frame(width: 280)
            .padding(28)
            .flPanel()
        }
    }
}
