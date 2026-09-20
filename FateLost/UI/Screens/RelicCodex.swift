import SwiftUI

/// Every relic in the game, found or not.
///
/// A relic is found the first time one is carried, and stays found. Unfound
/// ones are shown as a lock in their rarity's colour rather than hidden, so a
/// player can see how much is left and what kind of thing they are missing.
struct RelicCodex: View {
    let stats: LifetimeStats

    private var discovered: Int { stats.relicsDiscovered }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                rewards
                ForEach(ItemRarity.allCases, id: \.self) { rarity in
                    let relics = RelicCatalog.relics(of: rarity)
                    if !relics.isEmpty {
                        section(rarity, relics)
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: Rewards

    private var rewards: some View {
        VStack(alignment: .leading, spacing: 8) {
            FLSectionLabel(text: "Rewards")
            HStack(spacing: 10) {
                ForEach(CodexRewards.thresholds, id: \.self) { threshold in
                    let met = discovered >= threshold
                    HStack(spacing: 6) {
                        Image(systemName: met ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundStyle(met ? FLTheme.Palette.emberBright : FLTheme.Palette.locked)
                        Text("\(threshold) relics found: +1 reroll on every find")
                            .font(FLTheme.Typeface.body(12))
                            .foregroundStyle(met ? FLTheme.Palette.parchment : FLTheme.Palette.parchmentDim)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .flPanel(highlighted: met)
                    .accessibilityElement(children: .combine)
                }
            }
            if let next = CodexRewards.nextThreshold(discovered: discovered) {
                Text("\(next - discovered) more to the next.")
                    .font(FLTheme.Typeface.body(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
        }
    }

    // MARK: Sections

    private func section(_ rarity: ItemRarity, _ relics: [RelicDefinition]) -> some View {
        let found = relics.filter { stats.relicsSeen[$0.id] != nil }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rarity.displayName.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(rarity.color.color)
                Text("\(found) of \(relics.count)")
                    .font(FLTheme.Typeface.number(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 178), spacing: 8)], spacing: 8) {
                ForEach(relics) { relic in
                    tile(relic, best: stats.relicsSeen[relic.id])
                }
            }
        }
    }

    private func tile(_ relic: RelicDefinition, best: Int?) -> some View {
        let tint = relic.rarity.color.color
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(best == nil ? 0.08 : 0.24))
                    .frame(width: 38, height: 38)
                    .overlay(Circle().strokeBorder(tint.opacity(best == nil ? 0.3 : 0.9), lineWidth: 1))
                Image(systemName: best == nil ? "lock.fill" : relic.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(best == nil ? FLTheme.Palette.locked : tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(best == nil ? "Not yet found" : relic.name)
                    .font(FLTheme.Typeface.heading(13))
                    .foregroundStyle(best == nil ? FLTheme.Palette.parchmentDim : FLTheme.Palette.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let best {
                    Text(relic.description(atRank: 1))
                        .font(FLTheme.Typeface.body(10))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .lineLimit(2)
                    if best > 1 {
                        Text("Best: rank \(best == 2 ? "II" : "III")")
                            .font(FLTheme.Typeface.label(10))
                            .foregroundStyle(FLTheme.Palette.emberBright)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .flPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(best == nil
                            ? "\(relic.rarity.displayName) relic, not yet found"
                            : "\(relic.name), \(relic.rarity.displayName), \(relic.description(atRank: 1))")
    }
}
