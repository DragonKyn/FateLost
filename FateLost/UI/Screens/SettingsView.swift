import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    volumeSlider("Master", \.masterVolume)
                    volumeSlider("Music", \.musicVolume)
                    volumeSlider("Effects", \.effectsVolume)
                }
                Section {
                    Toggle("Haptics", isOn: binding(\.hapticsEnabled))
                    Toggle("Camera Shake", isOn: binding(\.cameraShakeEnabled))
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Camera shake adds weight to critical hits, explosions and boss attacks.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(FLTheme.Palette.stone)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(FLTheme.Palette.ember)
        .onDisappear { services.audio.refreshVolumes() }
    }

    /// Two-way binding that routes writes through the store, which persists them.
    private func binding<Value>(_ keyPath: WritableKeyPath<GameSettings, Value>) -> Binding<Value> {
        Binding(
            get: { services.settings.settings[keyPath: keyPath] },
            set: { newValue in services.settings.update { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func volumeSlider(_ title: String, _ keyPath: WritableKeyPath<GameSettings, Double>) -> some View {
        HStack {
            Text(title)
                .frame(width: 70, alignment: .leading)
            Slider(value: binding(keyPath), in: 0...1)
            Text("\(Int((services.settings.settings[keyPath: keyPath] * 100).rounded()))%")
                .font(FLTheme.Typeface.number(14))
                .frame(width: 48, alignment: .trailing)
                .foregroundStyle(FLTheme.Palette.parchmentDim)
        }
    }
}
