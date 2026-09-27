import SwiftUI

/// Title card shown at launch. Advances on its own, or on a tap.
struct LaunchView: View {
    @Environment(AppRouter.self) private var router
    @State private var titleVisible = false
    @State private var taglineVisible = false
    @State private var tagline = LaunchTaglines.random()

    private let holdDuration: Duration = .seconds(2.4)

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 24)
            VStack(spacing: 14) {
                Text("FATE LOST")
                    .font(FLTheme.Typeface.title(64))
                    .tracking(10)
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .shadow(color: FLTheme.Palette.ember.opacity(0.45), radius: 18)
                    .opacity(titleVisible ? 1 : 0)
                    .scaleEffect(titleVisible ? 1 : 1.06)
                Text(tagline)
                    .font(FLTheme.Typeface.heading(18))
                    .italic()
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .opacity(taglineVisible ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { router.show(.mainMenu) }
        .task {
            withAnimation(.easeOut(duration: 1.2)) { titleVisible = true }
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation(.easeOut(duration: 1.0)) { taglineVisible = true }
            try? await Task.sleep(for: holdDuration)
            if router.screen == .launch {
                router.show(.mainMenu)
            }
        }
    }
}

/// Taglines shown under the title at launch: a different one each time the
/// app opens, so it becomes a little easter egg to notice which one you got.
enum LaunchTaglines {
    static let all: [String] = [
        "You begin as nobody.",
        "Legends often start at zero.",
        "Your prophecy is not written.",
        "Rise beyond your fate.",
        "Defy what's written.",
        "Your story begins where fate ends.",
        "A nobody can change everything.",
    ]

    static func random() -> String { all.randomElement() ?? all[0] }
}
