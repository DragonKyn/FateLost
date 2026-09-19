import SwiftUI

/// Developer tools. Present only in builds compiled with `FATELOST_DEVTOOLS`.
///
/// Phase 1 covers world and rendering checks. Later phases add the rest of
/// the planned toolkit here: god mode, level and XP grants, enemy/elite/boss
/// spawning, wave jumps, item grants and collision display.
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
                Toggle("Show Wrap Seams", isOn: $developer.showWrapSeams)
            }
            Section("Simulation") {
                Picker("Game Speed", selection: $developer.gameSpeed) {
                    ForEach(DeveloperOptions.gameSpeedPresets, id: \.self) { speed in
                        Text(speed == 1 ? "1× (normal)" : "\(speed.formatted())×").tag(speed)
                    }
                }
                Button("Test Camera Shake") {
                    developer.shakeTestCounter += 1
                }
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
