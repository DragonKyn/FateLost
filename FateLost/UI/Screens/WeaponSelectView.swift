import SwiftUI

/// Pick the weapon to start with. It shapes the opening minutes of a run —
/// never the class.
struct WeaponSelectView: View {
    let realm: RealmDefinition

    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var selectedID: WeaponID = StarterWeapons.sword.id
    @State private var modifierSelections: [RunModifierSelection] = []
    @State private var modifiersExpanded = false

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 20)

            VStack(alignment: .leading, spacing: 10) {
                FLScreenHeader(title: "Take Up a Weapon",
                               subtitle: "\(realm.name) — your weapon does not decide what you become.") {
                    services.audio.play(.uiBack)
                    router.show(.realmSelect)
                }

                if services.isDifficultyEligible(realm) {
                    DifficultyModifiersSection(realm: realm.id, selections: $modifierSelections,
                                                isExpanded: $modifiersExpanded)
                        .onChange(of: modifierSelections) { _, newValue in
                            services.setActiveModifiers(newValue, for: realm.id)
                        }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(StarterWeapons.all) { weapon in
                            let unlocked = services.isUnlocked(weapon)
                            WeaponCard(weapon: weapon, isSelected: weapon.id == selectedID,
                                       isUnlocked: unlocked, mastery: services.profile.rank(of: weapon))
                                .frame(width: 236)
                                .onTapGesture {
                                    guard unlocked else { return }
                                    services.haptics.play(.uiTap)
                                    services.audio.play(.uiConfirm)
                                    selectedID = weapon.id
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
                .frame(maxHeight: .infinity)

                HStack {
                    Text("More weapons, and mastery of the ones you have, come from the Legacy armoury.")
                        .font(FLTheme.Typeface.body(13))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                    Spacer()
                    Button("Enter the Realm") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        router.startRun(.new(realm: realm.id, weapon: selectedID, modifiers: modifierSelections),
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
            modifierSelections = services.activeModifiers(for: realm.id)
            modifiersExpanded = !modifierSelections.isEmpty
        }
    }
}

/// Toggles for the difficulty modifiers a conquered realm has opened up: a
/// row of chips, each worth more echoes when switched on, with a slider for
/// the one modifier that has a range.
private struct DifficultyModifiersSection: View {
    let realm: RealmID
    @Binding var selections: [RunModifierSelection]
    @Binding var isExpanded: Bool

    private var payoutBonus: Double { DifficultyModifierCatalog.effects(for: selections).payoutBonus }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack {
                    FLSectionLabel(text: "Difficulty Modifiers")
                    if !selections.isEmpty {
                        Text("\(selections.count) active")
                            .font(FLTheme.Typeface.number(11))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                    }
                    Spacer()
                    if payoutBonus > 0 {
                        Text("+\(Int((payoutBonus * 100).rounded()))% echoes")
                            .font(FLTheme.Typeface.number(12))
                            .foregroundStyle(FLTheme.Palette.emberBright)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DifficultyModifierCatalog.all) { definition in
                            ModifierChip(definition: definition, isOn: isOn(definition.id)) {
                                toggle(definition.id)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()

                if let index = selections.firstIndex(where: { $0.id == .reinforcedEnemies }) {
                    let bonus = 50 + Int((selections[index].intensity * 200).rounded())
                    HStack(spacing: 10) {
                        Text("+\(bonus)% enemy health")
                            .font(FLTheme.Typeface.body(12))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                            .frame(width: 140, alignment: .leading)
                        Slider(value: Binding(
                            get: { selections[index].intensity },
                            set: { selections[index].intensity = $0 }
                        ), in: 0...1)
                    }
                }
            }
        }
        .transition(.opacity)
    }

    private func isOn(_ id: DifficultyModifierID) -> Bool {
        selections.contains { $0.id == id }
    }

    private func toggle(_ id: DifficultyModifierID) {
        if let index = selections.firstIndex(where: { $0.id == id }) {
            selections.remove(at: index)
        } else {
            selections.append(RunModifierSelection(id: id, intensity: 0.2))
        }
    }
}

private struct ModifierChip: View {
    let definition: DifficultyModifierDefinition
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(FLTheme.Typeface.label(12))
                    .foregroundStyle(isOn ? FLTheme.Palette.ember : FLTheme.Palette.parchment)
                Text("+\(Int((definition.echoBonusAtMinimum * 100).rounded()))% echoes")
                    .font(FLTheme.Typeface.number(10))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .flPanel(highlighted: isOn)
        .help(definition.tagline)
    }
}

private struct WeaponCard: View {
    let weapon: WeaponDefinition
    let isSelected: Bool
    let isUnlocked: Bool
    var mastery = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: isUnlocked ? symbol : "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? FLTheme.Palette.ember : FLTheme.Palette.parchmentDim)
                Spacer()
                Text(weapon.damageType.displayName)
                    .font(FLTheme.Typeface.label(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }

            Text(weapon.name)
                .font(FLTheme.Typeface.heading(20))
                .foregroundStyle(FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(weapon.summary)
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 2)

            if isUnlocked, mastery > 0 {
                Text("Mastery \(mastery) of \(WeaponMastery.maxRank)")
                    .font(FLTheme.Typeface.number(12))
                    .foregroundStyle(FLTheme.Palette.emberBright)
            } else if !isUnlocked {
                Text("Locked · \(WeaponMastery.unlockCost(weapon)) echoes")
                    .font(FLTheme.Typeface.number(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }

            VStack(spacing: 5) {
                statRow("Damage", value: String(format: "%.0f", weapon.baseDamage),
                        fraction: weapon.baseDamage / 24)
                statRow("Speed", value: String(format: "%.2f/s", weapon.attackSpeed),
                        fraction: weapon.attackSpeed / 2.4)
                statRow("Range", value: String(format: "%.1f", weapon.range), fraction: weapon.range / 8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .flPanel(highlighted: isSelected)
        .opacity(isUnlocked ? 1 : 0.5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var symbol: String { WeaponGlyph.symbol(for: weapon) }

    private func statRow(_ label: String, value: String, fraction: Double) -> some View {
        HStack(spacing: 8) {
            FLSectionLabel(text: label)
                .frame(width: 68, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(FLTheme.Palette.abyss)
                    Capsule()
                        .fill(isSelected ? FLTheme.Palette.ember : FLTheme.Palette.rim)
                        .frame(width: proxy.size.width * min(1, max(0.05, fraction)))
                }
            }
            .frame(height: 6)
            Text(value)
                .font(FLTheme.Typeface.number(13))
                .foregroundStyle(FLTheme.Palette.parchment)
                .frame(width: 52, alignment: .trailing)
        }
    }
}
