import SwiftUI

/// A conquered realm's difficulty toggles, on a screen of their own: each
/// one gets room for its full explanation and a proper switch, rather than
/// a chip crammed next to the weapon rack.
struct DifficultyModifiersView: View {
    let realm: RealmDefinition
    let weapon: WeaponID

    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var selections: [RunModifierSelection] = []

    private var payoutBonus: Double { DifficultyModifierCatalog.effects(for: selections).payoutBonus }

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 20)

            VStack(alignment: .leading, spacing: 10) {
                FLScreenHeader(title: "Difficulty Modifiers",
                               subtitle: "\(realm.name) — optional, and each one pays more echoes for taking it on.") {
                    services.audio.play(.uiBack)
                    router.show(.weaponSelect(realm.id))
                }

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(DifficultyModifierCatalog.all) { definition in
                            ModifierRow(definition: definition, selection: binding(for: definition.id))
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack {
                    if payoutBonus > 0 {
                        Text("+\(Int((payoutBonus * 100).rounded()))% echoes this run")
                            .font(FLTheme.Typeface.number(13))
                            .foregroundStyle(FLTheme.Palette.emberBright)
                    } else {
                        Text("Switch any of these on for more echoes at the end of the run.")
                            .font(FLTheme.Typeface.body(13))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                    }
                    Spacer()
                    Button("Enter the Realm") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.startRun(.new(realm: realm.id, weapon: weapon, modifiers: selections),
                                        services: services)
                    }
                    .buttonStyle(.flPrimary)
                    .frame(width: 260)
                }
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
            .padding(.vertical, FLTheme.Metrics.screenPaddingVertical)
        }
        .onAppear {
            selections = services.activeModifiers(for: realm.id)
        }
        .onChange(of: selections) { _, newValue in
            services.setActiveModifiers(newValue, for: realm.id)
        }
    }

    /// A single modifier's selection, synthesised from and folded back into
    /// the flat `selections` array a run configuration actually stores.
    private func binding(for id: DifficultyModifierID) -> Binding<RunModifierSelection?> {
        Binding(
            get: { selections.first { $0.id == id } },
            set: { newValue in
                if let index = selections.firstIndex(where: { $0.id == id }) {
                    if let newValue {
                        selections[index] = newValue
                    } else {
                        selections.remove(at: index)
                    }
                } else if let newValue {
                    selections.append(newValue)
                }
            }
        )
    }
}

private struct ModifierRow: View {
    let definition: DifficultyModifierDefinition
    @Binding var selection: RunModifierSelection?

    private var isOn: Bool { selection != nil }

    private var bonus: Double {
        guard let selection else { return definition.echoBonusAtMinimum }
        return DifficultyModifierCatalog.payoutBonus(for: selection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(definition.name)
                        .font(FLTheme.Typeface.heading(16))
                        .foregroundStyle(isOn ? FLTheme.Palette.ember : FLTheme.Palette.parchment)
                    Text(definition.tagline)
                        .font(FLTheme.Typeface.body(13))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("+\(Int((bonus * 100).rounded()))%")
                        .font(FLTheme.Typeface.number(14))
                        .foregroundStyle(FLTheme.Palette.emberBright)
                    Toggle("", isOn: Binding(
                        get: { isOn },
                        set: { newValue in
                            selection = newValue ? RunModifierSelection(id: definition.id, intensity: 0.2) : nil
                        }
                    ))
                    .labelsHidden()
                    .tint(FLTheme.Palette.ember)
                }
            }

            if definition.hasIntensity, let current = selection {
                HStack(spacing: 10) {
                    Text(intensityCaption(current))
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .frame(width: 150, alignment: .leading)
                    Slider(value: Binding(
                        get: { selection?.intensity ?? 0 },
                        set: { newValue in
                            guard var updated = selection else { return }
                            updated.intensity = newValue
                            selection = updated
                        }
                    ), in: 0...1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flPanel(highlighted: isOn)
    }

    /// Every intensity-bearing modifier today is Reinforced Enemies; this
    /// reads its own numbers rather than assuming which one it is, so a
    /// future modifier with a range falls back to something plain instead
    /// of silently showing the wrong caption.
    private func intensityCaption(_ selection: RunModifierSelection) -> String {
        guard definition.id == .reinforcedEnemies else { return "Intensity" }
        let healthBonus = 50 + Int((selection.intensity * 200).rounded())
        return "+\(healthBonus)% enemy health"
    }
}
