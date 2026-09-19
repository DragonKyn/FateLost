import SwiftUI

/// Developer tools. Present only in builds compiled with `FATELOST_DEVTOOLS`.
///
/// Covers rendering checks, combat cheats and stress spawning. Later phases
/// add level and XP grants, elite/boss spawning, wave jumps and item grants.
struct DeveloperPanelView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Developer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .tint(FLTheme.Palette.ember)
        .onDisappear { router.activeSession?.resume() }
    }

    @ViewBuilder
    private var content: some View {
        #if FATELOST_DEVTOOLS
        DeveloperOptionsForm(developer: services.developer)
        #else
        Text("Developer tools are not included in this build.")
            .foregroundStyle(FLTheme.Palette.parchmentDim)
        #endif
    }
}

#if FATELOST_DEVTOOLS
private struct DeveloperOptionsForm: View {
    @Bindable var developer: DeveloperOptions

    var body: some View {
        Form {
            Section("Overlays") {
                Toggle("Performance Overlay", isOn: $developer.showPerformanceOverlay)
                Toggle("Show Hitboxes", isOn: $developer.showHitboxes)
                Toggle("Show Wrap Seams", isOn: $developer.showWrapSeams)
            }
            Section {
                Toggle("God Mode", isOn: $developer.godMode)
                Toggle("Natural Spawning", isOn: $developer.spawningEnabled)
                Button("Restore Health") { developer.send(.restoreHealth) }
                Button("Kill All Enemies") { developer.send(.defeatAllEnemies) }
            } header: {
                Text("Combat")
            } footer: {
                Text("Commands run when you return to the game.")
            }
            Section {
                ForEach([10, 100, 250, 500], id: \.self) { count in
                    Button("Spawn \(count) Goblins") { developer.send(.spawnEnemies(count)) }
                }
            } header: {
                Text("Stress Test")
            } footer: {
                Text("Pair with the performance overlay to check frame rate under load.")
            }
            Section("Simulation") {
                Picker("Game Speed", selection: $developer.gameSpeed) {
                    ForEach(DeveloperOptions.gameSpeedPresets, id: \.self) { speed in
                        Text(speed == 1 ? "1× (normal)" : "\(speed.formatted())×").tag(speed)
                    }
                }
                Button("Test Camera Shake") {
                    developer.send(.shakeCamera)
                }
            }
            Section {
                Button("Gain 1 Level") { developer.send(.grantLevels(1)) }
                Button("Gain 5 Levels") { developer.send(.grantLevels(5)) }
                Button("Gain 20 Levels") { developer.send(.grantLevels(20)) }
                Button("Refund All Skill Points", role: .destructive) { developer.send(.resetSkills) }
            } header: {
                Text("Skills")
            } footer: {
                Text("Levels grant skill points and play the level-up burst. Open the skill tree from the HUD to spend them.")
            }
            Section("Progression") {
                Toggle("Unlock All Realms", isOn: $developer.unlockAllRealms)
            }
        }
        .scrollContentBackground(.hidden)
        .background(FLTheme.Palette.stone)
    }
}
#endif
