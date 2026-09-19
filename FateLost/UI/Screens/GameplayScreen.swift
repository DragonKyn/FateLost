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
                               onSkills: { session.openSkillTree() },
                               onSummons: { session.toggleSummons() },
                               onDeveloper: { openDeveloperPanel() })

            if showRealmTitle {
                RealmTitleCard(realm: session.realm)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if let summary = session.summary {
                RunSummaryView(
                    summary: summary,
                    realm: session.realm,
                    weapon: session.weapon,
                    onRetry: {
                        services.audio.play(.uiConfirm)
                        router.restartRun(services: services)
                    },
                    onMenu: {
                        services.audio.play(.uiBack)
                        router.endRun()
                    }
                )
                .transition(.opacity)
                .onAppear {
                    // Taking a realm is what opens the next one.
                    if summary.outcome == .conquered {
                        services.realmProgress.conquered.insert(summary.realm)
                    }
                }
            } else if session.isSkillTreePresented {
                SkillTreeView(session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if session.pauseReason == .menu {
                PauseMenu(
                    onResume: {
                        services.audio.play(.uiConfirm)
                        session.resume()
                    },
                    onSettings: { router.isSettingsPresented = true },
                    onAbandon: {
                        services.audio.play(.uiBack)
                        router.endRun()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.pauseReason)
        .animation(.easeInOut(duration: 0.8), value: session.summary)
        .onAppear { session.beginPresentation() }
        .task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 1.2)) { showRealmTitle = false }
        }
    }

    private func openDeveloperPanel() {
        session.pause(for: .developer)
        router.isDeveloperPanelPresented = true
    }
}

/// Minimal always-on information. Kept small and at the edges so the
/// battlefield stays readable.
private struct GameplayHUDOverlay: View {
    let session: GameSession
    let onPause: () -> Void
    let onSkills: () -> Void
    let onSummons: () -> Void
    let onDeveloper: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HealthBar(current: session.hud.health, maximum: session.hud.maxHealth,
                              barrier: session.hud.barrier)
                        .frame(width: 190, height: 14)
                    ExperienceBar(fraction: session.hud.experienceFraction)
                        .frame(width: 190, height: 6)
                    HStack(spacing: 10) {
                        Text("LV \(session.hud.level)")
                        Text("WAVE \(session.hud.wave)")
                        Text(formatTime(session.hud.elapsedSeconds))
                        Label("\(session.hud.kills)", systemImage: "flame")
                            .labelStyle(.titleAndIcon)
                            .accessibilityLabel("\(session.hud.kills) kills")
                    }
                    .font(FLTheme.Typeface.number(13))
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .shadow(color: .black, radius: 2)
                }
                Spacer()
                if session.hud.hasSummons {
                    SummonsButton(count: session.hud.allyCount,
                                  dismissed: session.hud.summonsDismissed,
                                  action: onSummons)
                }
                SkillPointsButton(points: session.hud.unspentPoints, action: onSkills)
                if DeveloperOptions.isAvailable {
                    hudButton(systemImage: "wrench.and.screwdriver", label: "Developer tools", action: onDeveloper)
                }
                hudButton(systemImage: "pause.fill", label: "Pause", action: onPause)
            }
            if let title = session.hud.bossTitle {
                BossBanner(title: title, fraction: session.hud.bossHealthFraction)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.easeOut(duration: 0.3), value: session.hud.bossTitle)
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
    var barrier: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let fraction = maximum > 0 ? min(1, max(0, current / maximum)) : 0
            let shield = maximum > 0 ? min(1, max(0, barrier / maximum)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.6))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.75, green: 0.16, blue: 0.14),
                                                  Color(red: 0.52, green: 0.08, blue: 0.08)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: proxy.size.width * fraction)
                if shield > 0 {
                    Capsule()
                        .fill(Color(red: 0.55, green: 0.8, blue: 1).opacity(0.55))
                        .frame(width: proxy.size.width * shield)
                }
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

/// Progress toward the next level: a thin line of fate-gold.
struct ExperienceBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.55))
                Capsule()
                    .fill(LinearGradient(colors: [FLTheme.Palette.emberBright, FLTheme.Palette.ember],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Experience")
        .accessibilityValue("\(Int(fraction * 100)) percent to next level")
    }
}

/// The champion holding the wave open: its name, and how much of it is left.
private struct BossBanner: View {
    let title: String
    let fraction: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(FLTheme.Typeface.heading(15))
                .tracking(3)
                .foregroundStyle(FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .shadow(color: .black, radius: 3)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.7))
                    Capsule()
                        .fill(LinearGradient(colors: [FLTheme.Palette.blood, Color(red: 0.42, green: 0.05, blue: 0.05)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: proxy.size.width * min(1, max(0, fraction)))
                        .animation(.easeOut(duration: 0.2), value: fraction)
                    Capsule().strokeBorder(FLTheme.Palette.ember.opacity(0.8), lineWidth: 1)
                }
            }
            .frame(height: 12)
        }
        .frame(maxWidth: 420)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(Int(fraction * 100)) percent health")
    }
}

/// Sends the player's summons away, or calls them back, and shows how many
/// are still standing.
private struct SummonsButton: View {
    let count: Int
    let dismissed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: dismissed ? "person.badge.plus" : "person.2.slash")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(dismissed ? FLTheme.Palette.parchmentDim : FLTheme.Palette.parchment)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .overlay(Circle().strokeBorder(FLTheme.Palette.rim, lineWidth: 1))
                if count > 0 {
                    Text("\(count)")
                        .font(FLTheme.Typeface.number(12))
                        .foregroundStyle(FLTheme.Palette.abyss)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(FLTheme.Palette.emberBright))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .accessibilityLabel(dismissed ? "Recall your summons" : "Dismiss your summons, \(count) standing")
    }
}

/// Opens the skill tree. Glows while points wait to be spent.
private struct SkillPointsButton: View {
    let points: Int
    let action: () -> Void

    @State private var glowing = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(points > 0 ? FLTheme.Palette.abyss : FLTheme.Palette.parchment)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(points > 0 ? AnyShapeStyle(FLTheme.Palette.emberBright)
                                                         : AnyShapeStyle(Color.black.opacity(0.45))))
                    .overlay(Circle().strokeBorder(FLTheme.Palette.rim, lineWidth: 1))
                    .shadow(color: FLTheme.Palette.ember.opacity(points > 0 && glowing ? 0.9 : 0), radius: 10)
                if points > 0 {
                    Text("\(points)")
                        .font(FLTheme.Typeface.number(12))
                        .foregroundStyle(FLTheme.Palette.parchment)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(FLTheme.Palette.blood))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .accessibilityLabel(points > 0 ? "Skill tree, \(points) points to spend" : "Skill tree")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}
