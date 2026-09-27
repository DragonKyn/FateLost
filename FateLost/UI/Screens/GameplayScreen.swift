import SwiftUI

/// The in-run screen: the SpriteKit view plus SwiftUI chrome around it.
struct GameplayScreen: View {
    let session: GameSession

    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var showRealmTitle = true
    /// Echoes this run paid out, worked out once when it ends.
    @State private var echoesEarned: Int?
    /// Fate's name across the screen as it arrives, shown once per run.
    @State private var showFateTitle = false
    @State private var fateTitleShown = false
    /// Whether the player has gone on past Fate's ending to the summary, and
    /// whether this was not the first time they had seen it (read once, as
    /// it first appears, so it cannot change under them mid-reading).
    @State private var endingDismissed = false
    @State private var endingIsRepeat: Bool?

    var body: some View {
        ZStack {
            GameViewContainer(scene: session.scene, showsDebugStatistics: false)
                .ignoresSafeArea()

            GameplayHUDOverlay(session: session,
                               onPause: { session.pause() },
                               onSkills: { session.openSkillTree() },
                               onSummons: { session.toggleSummons() },
                               onDeveloper: { openDeveloperPanel() })

            if session.isParty {
                PartyRunOverlay(session: session)
            }

            if showRealmTitle {
                RealmTitleCard(realm: session.realm)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if showFateTitle {
                FateTitleCard()
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
                    .allowsHitTesting(false)
            }

            if let results = session.partyResults {
                PartyResultsView(results: results)
                    .transition(.opacity)
            } else if let summary = session.summary {
                Group {
                    if showsFateEnding(summary) {
                        FateEndingView(
                            isRepeat: endingIsRepeat ?? false,
                            onEnterEcho: {
                                services.audio.play(.uiConfirm)
                                router.endRun()
                                router.show(.weaponSelect(.fatesEcho))
                            },
                            onContinue: {
                                services.audio.play(.uiConfirm)
                                withAnimation(.easeInOut(duration: 0.5)) { endingDismissed = true }
                            }
                        )
                    } else {
                        RunSummaryView(
                            summary: summary,
                            realm: session.realm,
                            weapon: session.weapon,
                            echoes: echoesEarned ?? 0,
                            onRetry: {
                                services.audio.play(.uiConfirm)
                                router.restartRun(services: services)
                            },
                            onMenu: {
                                services.audio.play(.uiBack)
                                router.endRun()
                            }
                        )
                    }
                }
                .transition(.opacity)
                .onAppear { recordOnce(summary) }
            } else if session.isEchoOfferPresented, let offer = session.echoOffer {
                EchoOfferView(offer: offer, echoesAtRisk: session.echoesAtRisk,
                              onCollect: {
                                  services.audio.play(.uiConfirm)
                                  services.haptics.play(.uiTap)
                                  session.collectEchoes()
                              },
                              onContinue: {
                                  services.audio.play(.uiConfirm)
                                  services.haptics.play(.uiTap)
                                  session.continueEchoes()
                              })
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if session.isOfferPresented, let offer = session.offer {
                RelicOfferView(offer: offer, inventory: session.progression.relics,
                               onChoose: { index in
                                   services.audio.play(.skillLearn)
                                   services.haptics.play(.uiTap)
                                   session.chooseRelic(at: index)
                               },
                               onChooseWeapon: {
                                   services.audio.play(.skillLearn)
                                   services.haptics.play(.uiTap)
                                   session.chooseWeapon()
                               },
                               onReroll: {
                                   services.audio.play(.uiConfirm)
                                   session.rerollOffer()
                               })
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if session.isSkillTreePresented {
                SkillTreeView(session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if session.pauseReason == .menu {
                PauseMenu(
                    isParty: session.isParty,
                    onResume: {
                        services.audio.play(.uiConfirm)
                        session.resume()
                    },
                    onSettings: { router.isSettingsPresented = true },
                    onAbandon: {
                        services.audio.play(.uiBack)
                        if session.isParty {
                            services.multiplayer.leaveParty()
                        } else {
                            router.endRun()
                        }
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
        .onChange(of: session.hud.bossBarrierFraction != nil) { _, fateArrived in
            guard fateArrived, !fateTitleShown else { return }
            fateTitleShown = true
            withAnimation(.easeOut(duration: 0.9)) { showFateTitle = true }
            Task {
                try? await Task.sleep(for: .seconds(3.2))
                withAnimation(.easeIn(duration: 1.1)) { showFateTitle = false }
            }
        }
    }

    /// Fate's ending comes before the ordinary summary, the first time it is
    /// reached and every time after, until the player goes on past it.
    private func showsFateEnding(_ summary: RunSummary) -> Bool {
        summary.outcome == .conquered && summary.realm == .abyss && !endingDismissed
    }

    /// Pays the run out once, however many times the end screens redraw. It
    /// runs the moment the first end screen appears — so Fate's defeat and
    /// Fate's Echo are saved before the ending is even read, and a player who
    /// closes the game mid-ending loses neither.
    private func recordOnce(_ summary: RunSummary) {
        guard echoesEarned == nil else { return }
        if showsFateEnding(summary) {
            endingIsRepeat = services.realmProgress.endingsSeen > 0
            services.realmProgress.endingsSeen += 1
        }
        echoesEarned = services.record(summary)
    }

    private func openDeveloperPanel() {
        session.pause(for: .developer)
        router.isDeveloperPanelPresented = true
    }
}

/// Minimal always-on information. Kept small and at the edges so the
/// battlefield stays readable.
private struct GameplayHUDOverlay: View {
    @Environment(AppServices.self) private var services
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
                    RelicStrip(relics: session.progression.relics)
                    AfflictionStrip(afflictions: session.hud.afflictions)
                    if session.hud.curseSeconds > 0 {
                        Label("Cursed \(formatTime(session.hud.curseSeconds))", systemImage: "moon.stars.fill")
                            .font(FLTheme.Typeface.number(12))
                            .foregroundStyle(Color(red: 0.72, green: 0.52, blue: 1))
                            .shadow(color: .black, radius: 2)
                            .accessibilityLabel("Cursed, \(session.hud.curseSeconds) seconds left")
                    }
                }
                Spacer()
                if session.hud.hasSummons {
                    SummonsButton(count: session.hud.allyCount,
                                  dismissed: session.hud.summonsDismissed,
                                  action: onSummons)
                }
                SkillPointsButton(points: session.hud.unspentPoints, action: onSkills)
                if services.isDeveloperModeOn, !session.isParty {
                    hudButton(systemImage: "wrench.and.screwdriver", label: "Developer tools", action: onDeveloper)
                }
                hudButton(systemImage: "pause.fill", label: "Pause", action: onPause)
            }
            if let title = session.hud.bossTitle {
                BossBanner(title: title, fraction: session.hud.bossHealthFraction,
                           barrierFraction: session.hud.bossBarrierFraction)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if session.hud.darknessWarningSeconds != nil || session.hud.darknessActiveSeconds != nil {
                DarknessWarning(warningSeconds: session.hud.darknessWarningSeconds,
                                activeSeconds: session.hud.darknessActiveSeconds,
                                inSafeCircle: session.hud.inSafeCircle)
                    .padding(.top, 8)
                    .transition(.opacity)
                    .allowsHitTesting(false)
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
    var isParty = false
    let onResume: () -> Void
    let onSettings: () -> Void
    let onAbandon: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(isParty ? "MENU" : "PAUSED")
                    .font(FLTheme.Typeface.title(34))
                    .tracking(6)
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .padding(.bottom, 6)
                Button("Resume", action: onResume)
                    .buttonStyle(.flPrimary)
                Button("Settings", action: onSettings)
                    .buttonStyle(.flSecondary)
                Button(isParty ? "Leave Party" : "Abandon Run", action: onAbandon)
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
/// A champion with a barrier (Fate) shows it as its own grey bar directly
/// above its health: the grey empties first, then the red.
private struct BossBanner: View {
    let title: String
    let fraction: Double
    var barrierFraction: Double?

    private var isFinal: Bool { barrierFraction != nil }

    var body: some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(FLTheme.Typeface.heading(isFinal ? 18 : 15))
                .tracking(isFinal ? 5 : 3)
                .foregroundStyle(FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .shadow(color: .black, radius: 3)
            if let barrierFraction {
                HStack(spacing: 6) {
                    Image(systemName: barrierFraction > 0 ? "shield.fill" : "shield.slash.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(white: barrierFraction > 0 ? 0.85 : 0.45))
                    bar(fraction: barrierFraction,
                        fill: LinearGradient(colors: [Color(white: 0.82), Color(white: 0.52)],
                                             startPoint: .top, endPoint: .bottom),
                        border: Color(white: 0.9).opacity(0.7))
                        .frame(height: 8)
                        .opacity(barrierFraction > 0 ? 1 : 0.35)
                }
            }
            bar(fraction: fraction,
                fill: LinearGradient(colors: [FLTheme.Palette.blood, Color(red: 0.42, green: 0.05, blue: 0.05)],
                                     startPoint: .top, endPoint: .bottom),
                border: FLTheme.Palette.ember.opacity(0.8))
                .frame(height: isFinal ? 14 : 12)
        }
        .frame(maxWidth: isFinal ? 520 : 420)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let barrierFraction, barrierFraction > 0 else {
            return "\(title), \(Int(fraction * 100)) percent health"
        }
        return "\(title), barrier \(Int(barrierFraction * 100)) percent, health \(Int(fraction * 100)) percent"
    }

    private func bar(fraction: Double, fill: LinearGradient, border: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.7))
                Capsule()
                    .fill(fill)
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
                    .animation(.easeOut(duration: 0.2), value: fraction)
                Capsule().strokeBorder(border, lineWidth: 1)
            }
        }
    }
}

/// The Encroaching Abyss's warning: what is coming, how long until it
/// hurts, and — once it does — whether the hero is where it is safe.
private struct DarknessWarning: View {
    let warningSeconds: Int?
    let activeSeconds: Int?
    let inSafeCircle: Bool

    var body: some View {
        VStack(spacing: 2) {
            if let warningSeconds {
                Text("THE ABYSS ENCROACHES")
                    .font(FLTheme.Typeface.heading(16))
                    .tracking(4)
                Text("Reach the light — \(warningSeconds)")
                    .font(FLTheme.Typeface.number(14))
            } else if let activeSeconds {
                Text(inSafeCircle ? "IN THE LIGHT" : "THE DARK IS TAKING YOU")
                    .font(FLTheme.Typeface.heading(16))
                    .tracking(4)
                Text(inSafeCircle ? "Hold here — \(activeSeconds)" : "5% of your life each second — reach the light")
                    .font(FLTheme.Typeface.number(13))
            }
        }
        .foregroundStyle(inSafeCircle || warningSeconds != nil
                         ? Color(red: 0.88, green: 0.84, blue: 1) : Color(red: 1, green: 0.45, blue: 0.45))
        .shadow(color: .black, radius: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .accessibilityElement(children: .combine)
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
