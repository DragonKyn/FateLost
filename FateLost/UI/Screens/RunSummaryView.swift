import SwiftUI

/// Shown when a run ends: what it achieved, and the way back in.
///
/// Two endings, one screen. Falling seals your fate; putting the realm's
/// last champion down conquers it, and the wording, colour and button all
/// change to say so.
struct RunSummaryView: View {
    let summary: RunSummary
    let realm: RealmDefinition
    let weapon: WeaponDefinition
    /// Echoes this run left behind, for the Legacy board.
    let echoes: Int
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.35), Color.black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // A landscape phone is barely 390 points tall, so the summary is
            // built to fit in that with room to spare: the numbers sit in a
            // grid of small cells rather than a column of rows. The scroll
            // view is only a net for the smallest screens and the largest
            // text sizes.
            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 28) {
                        record
                            .frame(maxWidth: .infinity, alignment: .leading)
                        verdict
                            .frame(width: 214)
                    }
                    .padding(.horizontal, FLTheme.Metrics.screenPadding * 1.5)
                    .padding(.vertical, 12)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: The record

    private var record: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isConquest ? "REALM CONQUERED" : "FATE SEALED")
                .font(FLTheme.Typeface.title(40))
                .tracking(6)
                .foregroundStyle(FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: (isConquest ? FLTheme.Palette.ember : FLTheme.Palette.blood).opacity(0.8),
                        radius: 16)
            Text("\(title.name), level \(summary.level)")
                .font(FLTheme.Typeface.heading(16))
                .italic()
                .foregroundStyle(FLTheme.Palette.emberBright)
                .lineLimit(1)
            Text("\(realm.name) · \(weapon.name)")
                .font(FLTheme.Typeface.body(13))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                      alignment: .leading, spacing: 8) {
                ForEach(cells, id: \.0) { cell in
                    statCell(cell.0, cell.1)
                }
            }
            .padding(.top, 8)

            if !distribution.isEmpty || !summary.relics.isEmpty {
                HStack(alignment: .center, spacing: 12) {
                    if !distribution.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(distribution.prefix(3), id: \.0.id) { entry in
                                Label("\(entry.0.name) \(entry.1)", systemImage: entry.0.symbol)
                                    .font(FLTheme.Typeface.label(11))
                                    .foregroundStyle(entry.0.color.color)
                                    .lineLimit(1)
                            }
                        }
                    }
                    if !summary.relics.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RELICS CARRIED")
                                .font(FLTheme.Typeface.label(9))
                                .tracking(2)
                                .foregroundStyle(FLTheme.Palette.parchmentDim)
                            RelicStrip(relics: summary.relics)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    /// The figures worth reading, in the order a player asks about them. The
    /// two that only some runs earn appear only when they were.
    private var cells: [(String, String)] {
        var list: [(String, String)] = [
            ("Survived", formatTime(summary.secondsSurvived)),
            ("Wave reached", "\(summary.wave)"),
            ("Enemies slain", "\(summary.stats.kills)"),
            ("Largest horde", "\(summary.stats.mostEnemiesAlive)"),
        ]
        if summary.stats.eliteKills > 0 {
            list.append(("Elites felled", "\(summary.stats.eliteKills)"))
        }
        if summary.stats.bossKills > 0 {
            list.append(("Champions felled", "\(summary.stats.bossKills)"))
        }
        list.append(("Damage dealt", "\(Int(summary.stats.damageDealt.rounded()))"))
        list.append(("Highest hit", "\(Int(summary.stats.highestHit.rounded()))"))
        list.append(("Healing received", "\(Int(summary.stats.healingReceived.rounded()))"))
        if let ability = summary.stats.mostUsedAbility.flatMap({ SkillCatalog.ability($0) }) {
            list.append(("Favourite ability", ability.name))
        }
        return list
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(FLTheme.Typeface.number(19))
                .foregroundStyle(FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label.uppercased())
                .font(FLTheme.Typeface.label(9))
                .tracking(1.2)
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: The verdict

    private var verdict: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(echoes)")
                    .font(FLTheme.Typeface.number(30))
                    .foregroundStyle(FLTheme.Palette.emberBright)
                Text(echoes == 1 ? "echo earned" : "echoes earned")
                    .font(FLTheme.Typeface.label(11))
                    .tracking(2)
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
            .accessibilityElement(children: .combine)

            Button(isConquest ? "Run It Again" : "Rise Again", action: onRetry)
                .buttonStyle(.flPrimary)
            Button("Return to Menu", action: onMenu)
                .buttonStyle(.flSecondary)
        }
    }

    private var isConquest: Bool { summary.outcome == .conquered }

    private var title: BuildTitle.Title { BuildTitle.title(for: summary.allocation) }

    /// Points per archetype, largest first.
    private var distribution: [(ArchetypeDefinition, Int)] {
        SkillCatalog.archetypes
            .map { ($0, summary.allocation.points(in: $0.id)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
