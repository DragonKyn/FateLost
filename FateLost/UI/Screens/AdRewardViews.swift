import SwiftUI

// MARK: - Boons panel

/// The two advert-funded boons, each with exactly what it gives, what is
/// left of it, and a button to watch an advert for it. Adverts are never
/// shown except from a tap here (or on the second-chance choice).
struct BoonsPanel: View {
    @Environment(AppServices.self) private var services
    let onClose: () -> Void

    /// The boon whose advert is being watched, so only its button says so.
    @State private var watching: Boon?
    /// What came of the last advert, shown under its boon.
    @State private var notes: [Boon: String] = [:]

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { if watching == nil { onClose() } }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("BOONS")
                        .font(FLTheme.Typeface.title(26))
                        .tracking(5)
                        .foregroundStyle(FLTheme.Palette.parchment)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(FLTheme.Palette.parchment)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(watching != nil)
                    .accessibilityLabel("Close boons")
                }
                Text("Optional. Watch a short ad for a boon. Each ad adds 10 minutes; time only runs "
                     + "down while you're playing a solo run.")
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Boon.allCases) { boon in
                            card(for: boon)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                Text(services.ads.statusLine)
                    .font(FLTheme.Typeface.label(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .lineLimit(2)
            }
            .padding(20)
            .frame(maxWidth: 620)
            .flPanel()
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
            .padding(.vertical, FLTheme.Metrics.screenPaddingVertical)
        }
        .task {
            await services.ads.requestTrackingPermissionIfNeeded()
            await services.ads.load()
        }
    }

    private func card(for boon: Boon) -> some View {
        let remaining = services.boons.wholeSeconds(boon)
        let active = remaining > 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: boon.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FLTheme.Palette.emberBright)
                Text(boon.name)
                    .font(FLTheme.Typeface.heading(17))
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(boon.rewardText)
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .fixedSize(horizontal: false, vertical: true)
            if active {
                Label("Active: \(BoonClock.format(remaining)) of play left", systemImage: "hourglass")
                    .font(FLTheme.Typeface.number(13))
                    .foregroundStyle(FLTheme.Palette.emberBright)
                    .accessibilityLabel("\(boon.name) active, \(BoonClock.spoken(remaining)) of play left")
            }
            Spacer(minLength: 0)
            Button {
                watch(boon)
            } label: {
                Text(buttonTitle(for: boon, active: active))
            }
            .buttonStyle(FLButtonStyle(kind: active ? .secondary : .primary, compact: true))
            .disabled(!services.ads.canOffer || watching != nil)
            .accessibilityHint(boon.rewardText)
            if let note = notes[boon] {
                Text(note)
                    .font(FLTheme.Typeface.body(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .flPanel(highlighted: active)
    }

    private func buttonTitle(for boon: Boon, active: Bool) -> String {
        if watching == boon { return "Ad playing…" }
        if !services.ads.isSupported { return "Ads unavailable" }
        if case .unavailable = services.ads.phase { return "Ads unavailable" }
        // Already running: another ad adds to what is left rather than
        // being offered as if it were new.
        return active ? "Watch ad: add 10 more minutes" : boon.watchLabel
    }

    private func watch(_ boon: Boon) {
        guard watching == nil else { return }
        watching = boon
        notes[boon] = nil
        services.audio.play(.uiConfirm)
        Task {
            let outcome = await services.ads.show()
            watching = nil
            switch outcome {
            case .earned:
                // Granted here and only here, once per earned-reward callback.
                services.grant(boon)
                services.audio.play(.skillLearn)
                notes[boon] = "+10 minutes added."
            case .closedEarly:
                notes[boon] = "The ad was closed before it finished, so nothing was added."
            case .failed(let reason):
                notes[boon] = reason
            case .busy:
                break
            }
        }
    }
}

/// Opens the boons panel, and says at a glance what is running.
struct BoonsButton: View {
    @Environment(AppServices.self) private var services
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Boons")
                        .font(FLTheme.Typeface.heading(15))
                    if let line = activeLine {
                        Text(line)
                            .font(FLTheme.Typeface.number(11))
                            .foregroundStyle(FLTheme.Palette.emberBright)
                    }
                }
            }
            .foregroundStyle(FLTheme.Palette.parchment)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .flPanel(highlighted: activeLine != nil)
        }
        .accessibilityLabel(activeLine.map { "Boons, \($0)" } ?? "Boons")
    }

    private var activeLine: String? {
        let running = Boon.allCases.filter { services.boons.isActive($0) }
        guard !running.isEmpty else { return nil }
        return running.map { "\($0 == .doubleEchoes ? "2× Echoes" : "Rift +10%") \(BoonClock.format(services.boons.wholeSeconds($0)))" }
            .joined(separator: " · ")
    }
}

/// The boons still running, shown small on the HUD during a solo run.
struct BoonHUDStrip: View {
    let seconds: [Boon: Int]

    var body: some View {
        if !seconds.isEmpty {
            HStack(spacing: 10) {
                ForEach(Boon.allCases.filter { seconds[$0] != nil }) { boon in
                    let left = seconds[boon] ?? 0
                    Label("\(boon == .doubleEchoes ? "2× Echoes" : "Rift +10%") \(BoonClock.format(left))",
                          systemImage: boon.symbol)
                        .accessibilityLabel("\(boon.name), \(BoonClock.spoken(left)) left")
                }
            }
            .font(FLTheme.Typeface.number(12))
            .foregroundStyle(FLTheme.Palette.emberBright)
            .shadow(color: .black, radius: 2)
        }
    }
}

enum BoonClock {
    static func format(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs)
                         : String(format: "%d:%02d", minutes, secs)
    }

    static func spoken(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return minutes > 0 ? "\(minutes) minutes \(secs) seconds" : "\(secs) seconds"
    }
}

// MARK: - Second chance

/// Shown the moment a lone hero falls, with the run held exactly as it was.
/// Two clear choices; the advert is only shown if the player picks it.
struct SecondChanceView: View {
    @Environment(AppServices.self) private var services
    let state: GameSession.SecondChanceState
    let onWatch: () -> Void
    let onAccept: () -> Void

    private var isWatching: Bool { state == .watching }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("YOU HAVE FALLEN")
                    .font(FLTheme.Typeface.title(32))
                    .tracking(6)
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .shadow(color: FLTheme.Palette.blood.opacity(0.9), radius: 14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Watch a short ad to rise again right where you fell, at half health, with two "
                     + "seconds of protection. The fight carries on exactly as it was. Once per run.")
                    .font(FLTheme.Typeface.body(13))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onWatch) {
                    Label(watchTitle, systemImage: "play.rectangle.fill")
                }
                .buttonStyle(.flPrimary)
                .disabled(!services.ads.canOffer || isWatching)

                Button("Accept fate", action: onAccept)
                    .buttonStyle(.flSecondary)
                    .disabled(isWatching)

                Text(footnote)
                    .font(FLTheme.Typeface.body(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 380)
            .padding(24)
            .flPanel(highlighted: true)
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
        }
        .accessibilityElement(children: .contain)
    }

    private var watchTitle: String {
        if isWatching { return "Ad playing…" }
        if !services.ads.canOffer { return "Ad unavailable" }
        if case .failed = state { return "Try the ad again" }
        return "Watch ad to revive"
    }

    private var footnote: String {
        if case .failed(let reason) = state { return reason }
        if !services.ads.canOffer { return services.ads.statusLine }
        switch services.ads.phase {
        case .loading, .starting, .idle: return "Fetching an ad…"
        case .loadFailed(let reason): return reason
        default: return "Accepting fate ends the run as usual."
        }
    }
}
