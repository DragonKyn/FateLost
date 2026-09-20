import SwiftUI

/// The party's results: how the run ended, how each hero did, what the pool of
/// echoes came to, and the way back to the lobby. Every player sees the same
/// screen, built from the numbers the host counted.
struct PartyResultsView: View {
    let results: PartyResults

    @Environment(AppServices.self) private var services
    @State private var tab = Tab.overview
    @State private var measure = Measure.slain

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "You"
        case compare = "Compare"
        case echoes = "Echoes"
        var id: String { rawValue }
    }

    /// One thing the party can be ranked by.
    enum Measure: String, CaseIterable, Identifiable {
        case slain = "Slain"
        case damage = "Damage"
        case taken = "Taken"
        case healing = "Healed"
        case highest = "Best hit"
        case revives = "Revives"
        var id: String { rawValue }

        func value(of hero: PartyHeroReport) -> Double {
            switch self {
            case .slain: return Double(hero.kills)
            case .damage: return hero.damageDealt
            case .taken: return hero.damageTaken
            case .healing: return hero.healing
            case .highest: return hero.highestHit
            case .revives: return Double(hero.revives)
            }
        }
    }

    private var report: PartyReport? { results.report }
    private var tabs: [Tab] { report == nil ? [.overview] : Tab.allCases }

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 8) {
                header
                if tabs.count > 1 {
                    Picker("", selection: $tab) {
                        ForEach(tabs) { option in Text(option.rawValue).tag(option) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                    .onChange(of: tab) { _, _ in services.haptics.play(.uiTap) }
                }
                Group {
                    switch tab {
                    case .overview: overview
                    case .compare: compare
                    case .echoes: echoes
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding * 1.5)
            .padding(.vertical, 12)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Header and footer

    private var header: some View {
        VStack(spacing: 2) {
            Text(results.headline.uppercased())
                .font(FLTheme.Typeface.title(28))
                .tracking(5)
                .foregroundStyle(FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail = results.detail {
                Text(detail)
                    .font(FLTheme.Typeface.heading(14))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("The party stays together. Ready up in the lobby for another run.")
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Return to the Lobby") {
                services.audio.play(.uiConfirm)
                services.multiplayer.returnToLobby()
            }
            .buttonStyle(.flPrimary)
            .frame(width: 250)
        }
    }

    // MARK: You

    private var mine: PartyHeroReport? { report?.hero(slot: results.mySlot) }

    private var overview: some View {
        let stats = results.summary?.stats
        let level = mine?.level ?? results.summary?.level ?? 1
        let cells: [(String, String)] = [
            ("Level", "\(level)"),
            ("Enemies slain", "\(stats?.kills ?? 0)"),
            ("Damage dealt", Self.shortNumber(stats?.damageDealt ?? 0)),
            ("Highest hit", Self.shortNumber(stats?.highestHit ?? 0)),
            ("Damage taken", Self.shortNumber(stats?.damageTaken ?? 0)),
            ("Healing received", Self.shortNumber(stats?.healingReceived ?? 0)),
            ("Friends revived", "\(stats?.revives ?? 0)"),
            ("Times fallen", "\(stats?.falls ?? 0)"),
            ("Elites felled", "\(stats?.eliteKills ?? 0)"),
            ("Champions felled", "\(stats?.bossKills ?? 0)"),
            ("Echoes earned", "+\(results.echoes)"),
            ("Wave reached", "\(results.summary?.wave ?? report?.wave ?? 1)"),
        ]
        return VStack {
            Spacer(minLength: 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                ForEach(cells, id: \.0) { cell in
                    VStack(spacing: 2) {
                        Text(cell.1)
                            .font(FLTheme.Typeface.number(22))
                            .foregroundStyle(cell.0 == "Echoes earned" ? FLTheme.Palette.emberBright
                                                                         : FLTheme.Palette.parchment)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        FLSectionLabel(text: cell.0)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(16)
            .flPanel()
            Spacer(minLength: 0)
        }
    }

    // MARK: Compare

    private var compare: some View {
        let heroes = report?.heroes.sorted { measure.value(of: $0) > measure.value(of: $1) } ?? []
        let top = max(1, heroes.map { measure.value(of: $0) }.max() ?? 1)
        return VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Measure.allCases) { option in
                        Button(option.rawValue) {
                            services.haptics.play(.uiTap)
                            measure = option
                        }
                        .buttonStyle(.flSecondary)
                        .opacity(option == measure ? 1 : 0.55)
                        .fixedSize()
                    }
                }
            }
            .frame(height: 38)

            VStack(spacing: 8) {
                ForEach(Array(heroes.enumerated()), id: \.element.slot) { rank, hero in
                    heroBar(hero, rank: rank, top: top)
                }
            }
            .padding(14)
            .flPanel()
            Spacer(minLength: 0)
        }
    }

    private func heroBar(_ hero: PartyHeroReport, rank: Int, top: Double) -> some View {
        let value = measure.value(of: hero)
        let isMe = hero.slot == results.mySlot
        return HStack(spacing: 10) {
            Image(systemName: rank == 0 && value > 0 ? "crown.fill" : "person.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(rank == 0 && value > 0 ? FLTheme.Palette.emberBright : FLTheme.Palette.parchmentDim)
                .frame(width: 16)
            Text(isMe ? "\(hero.name) (you)" : hero.name)
                .font(FLTheme.Typeface.heading(14))
                .foregroundStyle(isMe ? FLTheme.Palette.emberBright : FLTheme.Palette.parchment)
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.55))
                    Capsule()
                        .fill(isMe ? FLTheme.Palette.ember : FLTheme.Palette.parchmentDim.opacity(0.7))
                        .frame(width: max(4, proxy.size.width * CGFloat(value / top)))
                }
            }
            .frame(height: 12)
            Text(Self.shortNumber(value))
                .font(FLTheme.Typeface.number(15))
                .foregroundStyle(FLTheme.Palette.parchment)
                .frame(width: 60, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hero.name), \(Self.shortNumber(value)) \(measure.rawValue)")
    }

    // MARK: Echoes

    private var echoes: some View {
        let heroes = report?.heroes.sorted { $0.contribution > $1.contribution } ?? []
        let top = max(1, heroes.map(\.contribution).max() ?? 1)
        let realm = report.map { RealmCatalog.realm(RealmID(rawValue: $0.realm) ?? .ashenWilds) }
        return VStack(spacing: 10) {
            VStack(spacing: 8) {
                ForEach(heroes, id: \.slot) { hero in
                    HStack(spacing: 10) {
                        Text(hero.slot == results.mySlot ? "\(hero.name) (you)" : hero.name)
                            .font(FLTheme.Typeface.heading(14))
                            .foregroundStyle(hero.slot == results.mySlot ? FLTheme.Palette.emberBright
                                                                          : FLTheme.Palette.parchment)
                            .lineLimit(1)
                            .frame(width: 150, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.black.opacity(0.55))
                                Capsule()
                                    .fill(FLTheme.Palette.ember.opacity(0.85))
                                    .frame(width: max(4, proxy.size.width * CGFloat(hero.contribution) / CGFloat(top)))
                            }
                        }
                        .frame(height: 12)
                        Text("+\(hero.contribution)")
                            .font(FLTheme.Typeface.number(15))
                            .foregroundStyle(FLTheme.Palette.parchment)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
            .flPanel()

            HStack(spacing: 18) {
                figure("Shared pool", "\(report?.pool ?? 0)")
                Text("÷ \(report?.heroes.count ?? 1)")
                    .font(FLTheme.Typeface.number(20))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                figure("Your share", "+\(results.echoes)", highlighted: true)
            }
            if let realm {
                Text(String(format: "%@ pays ×%.2f. Everyone in the party is paid the same share, however the fight went.",
                            realm.name, realm.legacyMultiplier))
                    .font(FLTheme.Typeface.body(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
    }

    private func figure(_ label: String, _ value: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(FLTheme.Typeface.number(26))
                .foregroundStyle(highlighted ? FLTheme.Palette.emberBright : FLTheme.Palette.parchment)
            FLSectionLabel(text: label)
        }
        .accessibilityElement(children: .combine)
    }

    static func shortNumber(_ value: Double) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.1fM", value / 1_000_000)
        case 10_000...: return String(format: "%.0fk", value / 1_000)
        case 1_000...: return String(format: "%.1fk", value / 1_000)
        default: return String(Int(value))
        }
    }
}
