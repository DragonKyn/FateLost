import SwiftUI

/// A find, opened: three relics and a choice of one.
///
/// Tapping a card selects it and a second tap on Take confirms, because a
/// stray thumb in the middle of a fight should never cost a build a relic.
/// Cards show what the relic will *be* once taken: a relic already carried
/// reads "II → III", and one that arrived at a higher rank says so.
struct RelicOfferView: View {
    let offer: RelicOffer
    let inventory: RelicInventory
    let onChoose: (Int) -> Void
    let onChooseWeapon: () -> Void
    let onReroll: () -> Void

    /// An index into the relics, or one past the end for the weapon card.
    @State private var selected: Int?

    private var weaponIndex: Int { offer.choices.count }

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 12) {
                header
                HStack(spacing: 12) {
                    ForEach(Array(offer.choices.enumerated()), id: \.element.id) { index, choice in
                        if let relic = RelicCatalog.relic(choice.relic) {
                            RelicCard(relic: relic, choice: choice, owned: inventory.rank(of: relic.id),
                                      isSelected: selected == index)
                                .onTapGesture {
                                    selected = index
                                }
                        }
                    }
                    if let find = offer.weapon {
                        WeaponFindCard(find: find, replacing: offer.wielding.flatMap {
                            StarterWeapons.definition(for: $0)?.name
                        }, isSelected: selected == weaponIndex)
                            .onTapGesture {
                                selected = weaponIndex
                            }
                    }
                }
                .frame(maxHeight: 262)
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        // A reroll deals new cards, so a choice made on the old ones is void.
        .onChange(of: offer.choices) { _, _ in selected = nil }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(FLTheme.Typeface.title(24))
                .tracking(3)
                .foregroundStyle(tint)
            Text("Choose one. It stays with you for the rest of the run.")
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                onReroll()
            } label: {
                Label("Reroll · \(offer.rerollsLeft)", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.flSecondaryCompact)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(offer.rerollsLeft == 0)

            Button {
                guard let selected else { return }
                if selected == weaponIndex, offer.weapon != nil {
                    onChooseWeapon()
                } else {
                    onChoose(selected)
                }
            } label: {
                Text(selected == nil ? "Choose one" : "Take it")
            }
            .buttonStyle(.flPrimaryCompact)
            .frame(width: 200)
            .disabled(selected == nil)
        }
    }

    private var title: String {
        switch offer.tier {
        case .cache: return "A CACHE"
        case .chest: return "A CHEST"
        case .hoard: return "A HOARD"
        }
    }

    private var tint: Color {
        switch offer.tier {
        case .cache: return ItemRarity.common.color.color
        case .chest: return ItemRarity.rare.color.color
        case .hoard: return ItemRarity.legendary.color.color
        }
    }
}

// MARK: - Card

private struct RelicCard: View {
    let relic: RelicDefinition
    let choice: RelicChoice
    let owned: Int
    let isSelected: Bool

    /// The rank this relic will stand at once taken.
    private var resulting: Int { min(relic.maxRank, owned + choice.rank) }
    private var tint: Color { relic.rarity.color.color }

    var body: some View {
        VStack(spacing: 8) {
            Text(relic.rarity.displayName.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(tint)

            ZStack {
                Circle()
                    .fill(tint.opacity(0.22))
                    .frame(width: 58, height: 58)
                    .overlay(Circle().strokeBorder(tint, lineWidth: 1.5))
                Image(systemName: relic.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(relic.title(atRank: resulting))
                .font(FLTheme.Typeface.heading(16))
                .foregroundStyle(FLTheme.Palette.parchment)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            rankLine

            Text(relic.description(atRank: resulting))
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .flPanel(highlighted: isSelected)
        .overlay(
            RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous)
                .strokeBorder(isSelected ? FLTheme.Palette.emberBright : tint.opacity(0.45),
                              lineWidth: isSelected ? 2.5 : 1)
        )
        .scaleEffect(isSelected ? 1.03 : 1)
        .animation(.easeOut(duration: 0.14), value: isSelected)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var rankLine: some View {
        if owned > 0 {
            Text("Rank \(Self.numeral(owned)) → \(Self.numeral(resulting))")
                .font(FLTheme.Typeface.label(11))
                .foregroundStyle(Color(red: 0.55, green: 0.88, blue: 0.5))
        } else if resulting > 1 {
            Text("Arrives at rank \(Self.numeral(resulting))")
                .font(FLTheme.Typeface.label(11))
                .foregroundStyle(FLTheme.Palette.emberBright)
        } else {
            Color.clear.frame(height: 13)
        }
    }

    private var accessibilityText: String {
        "\(relic.rarity.displayName) \(relic.title(atRank: resulting)). \(relic.description(atRank: resulting))"
    }

    static func numeral(_ rank: Int) -> String {
        switch rank {
        case ...1: return "I"
        case 2: return "II"
        default: return "III"
        }
    }
}

// MARK: - A weapon on offer

/// A weapon found in the chest, with what it was rolled to be.
private struct WeaponFindCard: View {
    let find: WeaponFind
    /// The weapon it would replace, for the card to say so plainly.
    let replacing: String?
    let isSelected: Bool

    private var tint: Color { find.rarity.color.color }
    private var base: WeaponDefinition? { StarterWeapons.definition(for: find.weapon) }

    var body: some View {
        VStack(spacing: 7) {
            Text("WEAPON · \(find.rarity.displayName.uppercased())")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(tint)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.22))
                    .frame(width: 58, height: 58)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(tint, lineWidth: 1.5))
                Image(systemName: base.map(WeaponGlyph.symbol(for:)) ?? "questionmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(find.title)
                .font(FLTheme.Typeface.heading(15))
                .foregroundStyle(FLTheme.Palette.parchment)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if let definition = find.definition {
                Text(String(format: "%.0f damage · %.2f/s", definition.baseDamage, definition.attackSpeed))
                    .font(FLTheme.Typeface.number(12))
                    .foregroundStyle(FLTheme.Palette.parchment)
            }

            VStack(spacing: 2) {
                ForEach(find.affixes) { affix in
                    Text(affix.text)
                        .font(FLTheme.Typeface.body(11))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Text(replacing.map { "Replaces your \($0)" } ?? "Replaces your weapon")
                .font(FLTheme.Typeface.label(10))
                .foregroundStyle(Color(red: 1, green: 0.62, blue: 0.4))
                .multilineTextAlignment(.center)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .flPanel(highlighted: isSelected)
        .overlay(
            RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous)
                .strokeBorder(isSelected ? FLTheme.Palette.emberBright : tint.opacity(0.45),
                              lineWidth: isSelected ? 2.5 : 1)
        )
        .scaleEffect(isSelected ? 1.03 : 1)
        .animation(.easeOut(duration: 0.14), value: isSelected)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weapon: \(find.title). \(find.affixes.map(\.text).joined(separator: ". "))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - The strip

/// The relics a run carries, as a row of small sigils under the stats.
///
/// Tapping one shows what it does, in a small card under the row; tapping it
/// again (or waiting a few seconds) puts the card away.
struct RelicStrip: View {
    let relics: RelicInventory

    private let limit = 10
    @State private var selected: RelicID?

    var body: some View {
        let held = relics.held
        if !held.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 3) {
                    ForEach(Array(held.prefix(limit)), id: \.relic.id) { entry in
                        Button {
                            selected = selected == entry.relic.id ? nil : entry.relic.id
                        } label: {
                            RelicSigil(relic: entry.relic, rank: entry.rank)
                                .padding(2)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(entry.relic.title(atRank: entry.rank))
                        .accessibilityHint("Shows what it does")
                    }
                    if held.count > limit {
                        Text("+\(held.count - limit)")
                            .font(FLTheme.Typeface.number(11))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                    }
                }
                if let id = selected, let entry = held.first(where: { $0.relic.id == id }) {
                    RelicInfoCard(relic: entry.relic, rank: entry.rank)
                        .onTapGesture { selected = nil }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: selected)
            .task(id: selected) {
                guard selected != nil else { return }
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                if !Task.isCancelled { selected = nil }
            }
        }
    }
}

/// What is wrong with the hero right now, as small red chips with the time
/// left. Tap one to read what it does.
struct AfflictionStrip: View {
    let afflictions: [HUDAffliction]
    @State private var selected: String?

    var body: some View {
        if !afflictions.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(afflictions, id: \.effect.buffID) { item in
                        Button {
                            selected = selected == item.effect.buffID ? nil : item.effect.buffID
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: item.effect.symbol).font(.system(size: 10, weight: .bold))
                                Text("\(item.seconds)")
                                    .font(FLTheme.Typeface.number(11))
                            }
                            .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(red: 0.4, green: 0.05, blue: 0.05).opacity(0.75)))
                            .overlay(Capsule().strokeBorder(Color(red: 1, green: 0.4, blue: 0.35).opacity(0.7), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.effect.name), \(item.seconds) seconds left")
                    }
                }
                if let id = selected, let item = afflictions.first(where: { $0.effect.buffID == id }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.effect.name).font(FLTheme.Typeface.label(13))
                            .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.5))
                        Text(item.effect.blurb).font(FLTheme.Typeface.body(12))
                            .foregroundStyle(FLTheme.Palette.parchment)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(width: 230, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.78)))
                    .onTapGesture { selected = nil }
                }
            }
            .animation(.easeOut(duration: 0.15), value: selected)
        }
    }
}

/// What a carried relic does, in a card small enough to sit over the fight.
struct RelicInfoCard: View {
    let relic: RelicDefinition
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(relic.title(atRank: rank))
                    .font(FLTheme.Typeface.label(13))
                    .foregroundStyle(relic.rarity.color.color)
                Text(relic.rarity.displayName.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
            Text(relic.description(atRank: rank))
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: 230, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.78)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(relic.rarity.color.color.opacity(0.7), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct RelicSigil: View {
    let relic: RelicDefinition
    let rank: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(relic.rarity.color.color.opacity(0.28))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(relic.rarity.color.color.opacity(0.85), lineWidth: 1))
                .frame(width: 22, height: 22)
                .overlay(Image(systemName: relic.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(relic.rarity.color.color))
            if rank > 1 {
                Text(rank == 2 ? "II" : "III")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(FLTheme.Palette.abyss)
                    .padding(.horizontal, 2)
                    .background(Capsule().fill(FLTheme.Palette.emberBright))
                    .offset(x: 2, y: 2)
            }
        }
    }
}
