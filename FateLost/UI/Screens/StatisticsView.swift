import SwiftUI

/// The lifetime record: everything this player has ever done.
///
/// Three columns of plain numbers rather than a dashboard. A statistics
/// screen earns its place by being scannable — the point is to recognise
/// your own history in it, not to study it.
struct StatisticsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services

    private var stats: LifetimeStats { services.profile.lifetime }

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 16)

            VStack(alignment: .leading, spacing: 14) {
                FLScreenHeader(title: "Statistics", subtitle: subtitle) {
                    services.audio.play(.uiBack)
                    router.show(.mainMenu)
                }

                if stats.runs == 0 {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            column("Runs", runRows)
                            column("Battle", battleRows)
                            column("Bests", bestRows)
                        }
                        .padding(.bottom, 8)

                        if !realmRows.isEmpty {
                            realmSection
                        }
                    }
                }
            }
            .padding(FLTheme.Metrics.screenPadding)
        }
    }

    private var subtitle: String {
        stats.runs == 0
            ? "Nothing written down yet."
            : "\(stats.runs) runs, and what they cost."
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.system(size: 34))
                .foregroundStyle(FLTheme.Palette.locked)
            Text("Finish a run and it will be written here.")
                .font(FLTheme.Typeface.body(15))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Rows

    private var runRows: [(String, String)] {
        [
            ("Runs", "\(stats.runs)"),
            ("Realms conquered", "\(stats.conquests)"),
            ("Falls", "\(stats.deaths)"),
            ("Time in the field", longFormat(stats.secondsPlayed)),
            ("Echoes earned", "\(stats.echoesEarned)"),
            ("Legacy taken", "\(services.profile.unlocked.count) of \(LegacyTree.all.count)"),
        ]
    }

    private var battleRows: [(String, String)] {
        [
            ("Enemies slain", compact(Double(stats.kills))),
            ("Elites felled", "\(stats.eliteKills)"),
            ("Champions felled", "\(stats.bossKills)"),
            ("Damage dealt", compact(stats.damageDealt)),
            ("Damage taken", compact(stats.damageTaken)),
            ("Summons lost", "\(stats.summonsLost)"),
        ]
    }

    private var bestRows: [(String, String)] {
        var rows: [(String, String)] = [
            ("Highest wave", "\(stats.highestWave)"),
            ("Highest level", "\(stats.highestLevel)"),
            ("Biggest hit", compact(stats.highestHit)),
            ("Longest run", longFormat(stats.longestRunSeconds)),
            ("Largest horde", "\(stats.largestHorde)"),
        ]
        if let favourite = stats.favouriteArchetype,
           let definition = SkillCatalog.archetypes.first(where: { $0.id == favourite }) {
            rows.append(("Most played", definition.name))
        }
        return rows
    }

    private var realmRows: [(RealmDefinition, Int)] {
        RealmCatalog.all.compactMap { realm in
            guard let wave = stats.bestWaveByRealm[realm.id.rawValue], wave > 0 else { return nil }
            return (realm, wave)
        }
    }

    // MARK: Pieces

    private func column(_ title: String, _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FLSectionLabel(text: title)
            ForEach(rows, id: \.0) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.0)
                        .font(FLTheme.Typeface.body(13))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(row.1)
                        .font(FLTheme.Typeface.number(15))
                        .foregroundStyle(FLTheme.Palette.parchment)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flPanel()
    }

    private var realmSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FLSectionLabel(text: "Furthest in each realm")
            ForEach(realmRows, id: \.0.id) { realm, wave in
                HStack {
                    Text(realm.name)
                        .font(FLTheme.Typeface.body(13))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                    Spacer(minLength: 8)
                    if services.profile.realms.conquered.contains(realm.id) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(FLTheme.Palette.ember)
                    }
                    Text("Wave \(wave)")
                        .font(FLTheme.Typeface.number(14))
                        .foregroundStyle(FLTheme.Palette.parchment)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flPanel()
    }

    // MARK: Formatting

    /// Big totals read better shortened: 1.2M rather than 1,243,905.
    private func compact(_ value: Double) -> String {
        let rounded = value.rounded()
        switch rounded {
        case 1_000_000...:
            return String(format: "%.1fM", rounded / 1_000_000)
        case 10_000...:
            return String(format: "%.0fk", rounded / 1_000)
        case 1_000...:
            return String(format: "%.1fk", rounded / 1_000)
        default:
            return "\(Int(rounded))"
        }
    }

    private func longFormat(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m \(seconds % 60)s"
    }
}
