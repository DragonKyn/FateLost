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
    let onReroll: () -> Void

    @State private var selected: Int?

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
                }
                .frame(maxHeight: 250)
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
                if let selected { onChoose(selected) }
            } label: {
                Text(selected == nil ? "Choose a relic" : "Take it")
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

// MARK: - The strip

/// The relics a run carries, as a row of small sigils under the stats.
struct RelicStrip: View {
    let relics: RelicInventory

    private let limit = 10

    var body: some View {
        let held = relics.held
        if !held.isEmpty {
            HStack(spacing: 3) {
                ForEach(Array(held.prefix(limit)), id: \.relic.id) { entry in
                    RelicSigil(relic: entry.relic, rank: entry.rank)
                }
                if held.count > limit {
                    Text("+\(held.count - limit)")
                        .font(FLTheme.Typeface.number(11))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(held.count) relics carried")
        }
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
