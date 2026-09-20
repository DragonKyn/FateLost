import Foundation

/// How one hero fared in a party run, as the host counted it.
struct PartyHeroReport: Codable, Equatable, Identifiable {
    var slot: Int
    var name: String
    var level: Int
    var kills = 0
    var eliteKills = 0
    var bossKills = 0
    var criticalHits = 0
    var dodges = 0
    var revives = 0
    var falls = 0
    var damageDealt: Double = 0
    var damageTaken: Double = 0
    var healing: Double = 0
    var highestHit: Double = 0
    /// What this hero added to the party's pool of echoes.
    var contribution = 0

    var id: Int { slot }

    init(slot: Int, name: String, level: Int, stats: RunStats, contribution: Int) {
        self.slot = slot
        self.name = name
        self.level = level
        kills = stats.kills
        eliteKills = stats.eliteKills
        bossKills = stats.bossKills
        criticalHits = stats.criticalHits
        dodges = stats.dodges
        revives = stats.revives
        falls = stats.falls
        damageDealt = stats.damageDealt.rounded()
        damageTaken = stats.damageTaken.rounded()
        healing = stats.healingReceived.rounded()
        highestHit = stats.highestHit.rounded()
        self.contribution = contribution
    }

    /// The run statistics this report stands for, for the lifetime record.
    var stats: RunStats {
        var stats = RunStats()
        stats.kills = kills
        stats.eliteKills = eliteKills
        stats.bossKills = bossKills
        stats.criticalHits = criticalHits
        stats.dodges = dodges
        stats.revives = revives
        stats.falls = falls
        stats.damageDealt = damageDealt
        stats.damageTaken = damageTaken
        stats.healingReceived = healing
        stats.highestHit = highestHit
        return stats
    }
}

/// The whole party's run: each hero's numbers and the echoes they share.
///
/// Every hero adds what they earned to one pool, and the pool is split evenly,
/// so a friend who fell early still advances as far as the one who carried.
/// The host works it out once and sends it, so everyone sees the same figures.
struct PartyReport: Codable, Equatable {
    var wave: Int
    var seconds: Int
    var conquered: Bool
    var realm: String
    var pool: Int
    /// What each hero is paid: the pool divided by the number of heroes.
    var share: Int
    var heroes: [PartyHeroReport]

    /// The heroes in order of what they slew, most first.
    var ranked: [PartyHeroReport] {
        heroes.sorted { $0.kills != $1.kills ? $0.kills > $1.kills : $0.slot < $1.slot }
    }

    func hero(slot: Int) -> PartyHeroReport? {
        heroes.first { $0.slot == slot }
    }

    /// The party's totals, for a "together" tab.
    var totalKills: Int { heroes.reduce(0) { $0 + $1.kills } }
    var totalDamage: Double { heroes.reduce(0) { $0 + $1.damageDealt } }

    /// Builds the report from the finished run. Runs on the host.
    static func make(simulation: inout GameSimulation, outcome: RunSummary.Outcome, seconds: Int) -> PartyReport {
        let realm = RealmCatalog.realm(simulation.run.realmID)
        let wave = simulation.wave.index
        var heroes: [PartyHeroReport] = []
        for index in 0..<simulation.heroCount {
            let slot = simulation.members[index].slot
            let name = simulation.members[index].name
            let (level, stats) = simulation.perform(as: index) { ($0.progression.level, $0.combat.stats) }
            let earned = LegacyEchoes.earned(from: stats, wave: wave, level: level,
                                             realmMultiplier: realm.legacyMultiplier,
                                             conquered: outcome == .conquered)
            heroes.append(PartyHeroReport(slot: slot, name: name, level: level, stats: stats, contribution: earned))
        }
        let split = LegacyEchoes.pooled(heroes.map(\.contribution))
        return PartyReport(wave: wave, seconds: seconds, conquered: outcome == .conquered,
                           realm: simulation.run.realmID.rawValue, pool: split.pool, share: split.share,
                           heroes: heroes)
    }

    // MARK: Over the wire

    var json: JSONValue? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    init(wave: Int, seconds: Int, conquered: Bool, realm: String, pool: Int, share: Int, heroes: [PartyHeroReport]) {
        self.wave = wave
        self.seconds = seconds
        self.conquered = conquered
        self.realm = realm
        self.pool = pool
        self.share = share
        self.heroes = heroes
    }

    /// Reads a report out of a run-end message, if it carries a believable one.
    init?(json: JSONValue?) {
        guard let json, let data = try? JSONEncoder().encode(json),
              let report = try? JSONDecoder().decode(PartyReport.self, from: data),
              !report.heroes.isEmpty, report.heroes.count <= PartyTuning.maximumHeroes else { return nil }
        self = report
    }
}

extension LegacyEchoes {
    /// A party's pool and each hero's even share of it. Everyone gets at least one.
    static func pooled(_ contributions: [Int]) -> (pool: Int, share: Int) {
        let pool = contributions.reduce(0, +)
        let count = max(1, contributions.count)
        return (pool, max(1, Int((Double(pool) / Double(count)).rounded())))
    }
}
