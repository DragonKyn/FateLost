import SwiftUI

/// Fate's Echo stopping after every tenth wave: bank what this run has
/// earned and leave, or leave it at risk and go on. The risk is stated in
/// plain words — falling before the next chance to bank loses all of it.
struct EchoOfferView: View {
    let offer: EchoOffer
    let echoesAtRisk: Int
    let onCollect: () -> Void
    let onContinue: () -> Void

    private var nextChance: Int { offer.completedWave + FateTuning.echoOfferEvery }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("WAVE \(offer.completedWave) SURVIVED")
                    .font(FLTheme.Typeface.title(30))
                    .tracking(5)
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                VStack(spacing: 2) {
                    Text("\(echoesAtRisk)")
                        .font(FLTheme.Typeface.number(40))
                        .foregroundStyle(FLTheme.Palette.emberBright)
                    Text("ECHOES UNBANKED")
                        .font(FLTheme.Typeface.label(11))
                        .tracking(2)
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
                .accessibilityElement(children: .combine)

                VStack(spacing: 4) {
                    Text("Go on, and all \(echoesAtRisk) stay at risk: fall before wave \(nextChance) and every one of them is lost.")
                    if offer.nextWaveIsHarder {
                        Text("From wave \(offer.nextWave) the horde is stronger: +\(Int(FateTuning.echoHealthPerTier * 100))% health, +\(Int(FateTuning.echoDamagePerTier * 100))% damage.")
                    }
                }
                .font(FLTheme.Typeface.body(13))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("Collect and Leave", action: onCollect)
                        .buttonStyle(.flPrimary)
                    Button("Continue to Wave \(offer.nextWave)", action: onContinue)
                        .buttonStyle(.flSecondary)
                }
            }
            .frame(maxWidth: 520)
            .padding(24)
            .flPanel(highlighted: true)
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
        }
    }
}

/// The moment after Fate falls: what the player refused, what they won,
/// and a quieter word from the one who made the game. Every choice here is
/// the game's own; the studio link is a small, optional extra, never a step.
///
/// The first time it is read line by line. After that it arrives whole, so a
/// player who has seen it can go straight on.
struct FateEndingView: View {
    let isRepeat: Bool
    let onEnterEcho: () -> Void
    let onContinue: () -> Void

    @State private var stage = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.04, blue: 0.09), Color.black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Color(red: 0.72, green: 0.66, blue: 1).opacity(0.18), .clear],
                           center: .top, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Text("FATE HAS FALLEN")
                            .font(FLTheme.Typeface.title(isRepeat ? 32 : 40))
                            .tracking(8)
                            .foregroundStyle(FLTheme.Palette.parchment)
                            .shadow(color: Color(red: 0.72, green: 0.66, blue: 1).opacity(0.8), radius: 18)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .opacity(stage >= 1 ? 1 : 0)
                        Text("Your end was written. You chose to fight for another.")
                            .font(FLTheme.Typeface.heading(17))
                            .italic()
                            .foregroundStyle(FLTheme.Palette.parchment)
                            .opacity(stage >= 2 ? 1 : 0)
                        Text("The path home is yours. What you do with it is no longer Fate's to decide.")
                            .font(FLTheme.Typeface.heading(15))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                            .opacity(stage >= 3 ? 1 : 0)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                    if !isRepeat {
                        developerNote
                            .opacity(stage >= 4 ? 1 : 0)
                    }

                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Button(action: onEnterEcho) {
                                Label("Enter Fate's Echo", systemImage: "circle.dotted.circle")
                            }
                            .buttonStyle(.flPrimary)
                            Button("Continue", action: onContinue)
                                .buttonStyle(.flSecondary)
                        }
                        .frame(maxWidth: 520)
                        Text("Fate's Echo is open now, and stays open on every run to come.")
                            .font(FLTheme.Typeface.body(12))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                    }
                    .opacity(stage >= 5 ? 1 : 0)
                    .allowsHitTesting(stage >= 5)
                }
                .padding(.horizontal, FLTheme.Metrics.screenPadding * 1.5)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // Keyed on `isRepeat` so it restarts, and shows everything at once,
        // if the caller learns it is a repeat just after this first appears.
        .task(id: isRepeat) { await reveal() }
        // A tap anywhere hurries the reading along; it never skips past the
        // choices themselves.
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.3)) { stage = 5 }
        }
    }

    private var developerNote: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(FLTheme.Palette.rim.opacity(0.5))
                .frame(width: 120, height: 1)
            Text("Thank you for playing Fate Lost, and for making it this far. I made this game because I wanted to build a world worth fighting through. It means a lot that you saw it to the end.")
                .font(FLTheme.Typeface.body(14))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("— Wicked Studios")
                .font(FLTheme.Typeface.heading(14))
                .italic()
                .foregroundStyle(FLTheme.Palette.parchment)
            Link(destination: FateTuning.studioURL) {
                Label("Visit Wicked Studios", systemImage: "arrow.up.right.square")
                    .font(FLTheme.Typeface.label(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .underline()
            }
            .accessibilityHint("Opens WickedStudios.ca in your browser")
        }
        .frame(maxWidth: 480)
    }

    /// Reads the ending line by line the first time; all at once after.
    private func reveal() async {
        guard !isRepeat else {
            stage = 5
            return
        }
        for next in 1...5 {
            try? await Task.sleep(for: .seconds(next == 1 ? 0.4 : 1.3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.9)) { stage = max(stage, next) }
        }
    }
}

/// Fate's arrival: its name across the screen as it takes the field.
struct FateTitleCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("FATE")
                .font(FLTheme.Typeface.title(64))
                .tracking(18)
                .foregroundStyle(FLTheme.Palette.parchment)
                .shadow(color: Color(red: 0.72, green: 0.66, blue: 1), radius: 22)
            Text("What Was Written")
                .font(FLTheme.Typeface.heading(18))
                .italic()
                .foregroundStyle(Color(red: 0.84, green: 0.8, blue: 1))
            Text("Break its barrier. Then break it.")
                .font(FLTheme.Typeface.body(13))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .padding(.top, 4)
        }
        .shadow(color: .black, radius: 10)
        .offset(y: -40)
    }
}
