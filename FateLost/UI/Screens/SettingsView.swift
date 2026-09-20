import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var codeRejected = false
    @State private var confirmingSeal = false

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

                if DeveloperOptions.isAvailable {
                    developerSection
                }

                Section {
                    Button("Seal Your Fate", role: .destructive) {
                        confirmingSeal = true
                    }
                } header: {
                    Text("Start Over")
                } footer: {
                    Text("Erases every echo, unlock, record and choice, and the game begins again as if it had "
                         + "just been installed.")
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
            .alert("Seal your fate?", isPresented: $confirmingSeal) {
                Button("Seal Your Fate", role: .destructive) { sealFate() }
                Button("Keep My Fate", role: .cancel) {}
            } message: {
                Text("Every echo, weapon, look and record you have earned will be erased for good. This cannot be "
                     + "undone.")
            }
        }
        .tint(FLTheme.Palette.ember)
        .onDisappear { services.audio.refreshVolumes() }
    }

    // MARK: Developer

    @ViewBuilder
    private var developerSection: some View {
        if services.isDeveloperModeOn {
            Section {
                Label("Developer mode is on", systemImage: "wrench.and.screwdriver.fill")
                    .foregroundStyle(FLTheme.Palette.emberBright)
                Button("Lock Developer Mode") {
                    services.lockDeveloperMode()
                }
            } header: {
                Text("Developer")
            } footer: {
                Text("The developer tools button appears on the main menu and in a run. Locking switches every "
                     + "cheat back off.")
            }
        } else {
            Section {
                TextField("Developer code", text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(tryCode)
                    .onChange(of: code) { _, _ in codeRejected = false }
                Button("Unlock", action: tryCode)
                    .disabled(code.isEmpty)
            } header: {
                Text("Developer")
            } footer: {
                if codeRejected {
                    Text("That is not the code.")
                        .foregroundStyle(FLTheme.Palette.blood)
                } else {
                    Text("Enter the developer code to reveal the developer tools.")
                }
            }
        }
    }

    private func tryCode() {
        if services.unlockDeveloperMode(code: code) {
            code = ""
            codeRejected = false
        } else {
            codeRejected = true
        }
    }

    // MARK: Sealing fate

    private func sealFate() {
        services.sealFate()
        code = ""
        dismiss()
        // Leaves any run in progress without counting it, and lands on a
        // main menu that looks like a first launch.
        router.endRun()
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
