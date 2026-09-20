import SwiftUI

/// A run played with the party. Placeholder until the run netcode lands.
struct PartyRunScreen: View {
    let run: PartyRunController

    var body: some View {
        ZStack {
            FLTheme.Palette.abyss.ignoresSafeArea()
            Text("Run \(run.runID)")
                .foregroundStyle(FLTheme.Palette.parchment)
        }
    }
}
