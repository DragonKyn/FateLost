import Foundation

/// Everything the game remembers between runs.
///
/// One value type, one file. Keeping the whole profile in a single `Codable`
/// struct means saving is one write, migration is one function, and a test
/// can build a profile in a line without touching the disk.
struct LegacyProfile: Codable, Equatable {
    /// Echoes not yet spent.
    var echoes = 0
    /// Echoes spent on the board, kept so the total earned can be shown.
    var spent = 0
    /// Nodes bought, by id.
    var unlocked: Set<String> = []
    var realms = RealmProgress()
    var lifetime = LifetimeStats()

    var totalEarned: Int { echoes + spent }

    // MARK: Buying

    /// Whether a node's tier has been opened by what is already bought.
    func isReachable(_ node: LegacyNode) -> Bool {
        guard node.tier > 1 else { return true }
        let above = LegacyTree.nodes(in: node.branch, tier: node.tier - 1)
        let bought = above.filter { unlocked.contains($0.id) }.count
        return bought >= LegacyTree.nodesToAdvance
    }

    func isUnlocked(_ node: LegacyNode) -> Bool { unlocked.contains(node.id) }

    func canAfford(_ node: LegacyNode) -> Bool { echoes >= node.cost }

    /// Why a node cannot be bought right now, or nil if it can.
    func denial(for node: LegacyNode) -> String? {
        if isUnlocked(node) { return "Already yours" }
        if !isReachable(node) {
            return "Take \(LegacyTree.nodesToAdvance) of tier \(node.tier - 1) first"
        }
        if !canAfford(node) { return "Costs \(node.cost) echoes" }
        return nil
    }

    /// Buys a node. Returns false and changes nothing if it isn't allowed.
    @discardableResult
    mutating func buy(_ node: LegacyNode) -> Bool {
        guard denial(for: node) == nil else { return false }
        echoes -= node.cost
        spent += node.cost
        unlocked.insert(node.id)
        return true
    }

    /// Nodes bought in one strand.
    func count(in branch: LegacyBranch) -> Int {
        LegacyTree.nodes(in: branch).filter { unlocked.contains($0.id) }.count
    }

    /// Every bonus the board currently grants, ready for a run's stat sheet.
    var modifiers: [StatModifier] {
        unlocked.compactMap { LegacyTree.node($0)?.modifier }
    }

    // MARK: Runs

    /// Folds a finished run into the lifetime record and pays out its echoes.
    mutating func record(_ summary: RunSummary, realm: RealmDefinition) {
        let earned = LegacyEchoes.earned(from: summary.stats, wave: summary.wave, level: summary.level,
                                         realmMultiplier: realm.legacyMultiplier,
                                         conquered: summary.outcome == .conquered)
        echoes += earned
        lifetime.add(summary, realm: realm, echoes: earned)
        if summary.outcome == .conquered {
            realms.conquered.insert(summary.realm)
        }
    }
}

/// The running total of everything a player has ever done.
///
/// Kept apart from `RunStats` on purpose: one describes a run, the other a
/// player. Totals only ever grow, and bests only ever improve, so a corrupt
/// or missing file costs history rather than progress.
struct LifetimeStats: Codable, Equatable {
    var runs = 0
    var conquests = 0
    var kills = 0
    var eliteKills = 0
    var bossKills = 0
    var deaths = 0
    var secondsPlayed = 0
    var damageDealt: Double = 0
    var damageTaken: Double = 0
    var healingReceived: Double = 0
    var summonsLost = 0
    var echoesEarned = 0

    var highestWave = 0
    var highestLevel = 0
    var highestHit: Double = 0
    var longestRunSeconds = 0
    var largestHorde = 0

    /// Best wave reached in each realm.
    var bestWaveByRealm: [String: Int] = [:]
    /// Runs started with each starting weapon.
    var runsByWeapon: [String: Int] = [:]
    /// Points ever spent in each archetype, as a picture of how they play.
    var pointsByArchetype: [String: Int] = [:]

    mutating func add(_ summary: RunSummary, realm: RealmDefinition, echoes: Int) {
        runs += 1
        if summary.outcome == .conquered {
            conquests += 1
        } else {
            deaths += 1
        }
        kills += summary.stats.kills
        eliteKills += summary.stats.eliteKills
        bossKills += summary.stats.bossKills
        secondsPlayed += summary.secondsSurvived
        damageDealt += summary.stats.damageDealt
        damageTaken += summary.stats.damageTaken
        healingReceived += summary.stats.healingReceived
        summonsLost += summary.stats.summonsLost
        echoesEarned += echoes

        highestWave = max(highestWave, summary.wave)
        highestLevel = max(highestLevel, summary.level)
        highestHit = max(highestHit, summary.stats.highestHit)
        longestRunSeconds = max(longestRunSeconds, summary.secondsSurvived)
        largestHorde = max(largestHorde, summary.stats.mostEnemiesAlive)

        let realmKey = summary.realm.rawValue
        bestWaveByRealm[realmKey] = max(bestWaveByRealm[realmKey] ?? 0, summary.wave)
        runsByWeapon[summary.weapon, default: 0] += 1
        for archetype in ArchetypeID.allCases {
            let points = summary.allocation.points(in: archetype)
            guard points > 0 else { continue }
            pointsByArchetype[archetype.rawValue, default: 0] += points
        }
    }

    /// The archetype this player keeps coming back to.
    var favouriteArchetype: ArchetypeID? {
        pointsByArchetype
            .max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }
            .flatMap { ArchetypeID(rawValue: $0.key) }
    }
}

/// Reads and writes the profile, and keeps working when the file does not.
///
/// A missing profile is a new player, not an error. A corrupt one is moved
/// aside by `VersionedFileStore` and the player starts fresh rather than
/// facing a crash loop, which matters more here than any single save does.
final class LegacyStore {
    static let schemaVersion = 1
    private let store: VersionedFileStore<LegacyProfile>

    init(fileURL: URL? = nil) {
        let url = fileURL ?? SaveLocations.directory().appendingPathComponent("legacy.json")
        store = VersionedFileStore(fileURL: url, currentVersion: Self.schemaVersion)
    }

    func load() -> LegacyProfile {
        store.load().payload ?? LegacyProfile()
    }

    /// Saves, reporting failure rather than throwing into the UI: a failed
    /// write must never take a run down with it.
    @discardableResult
    func save(_ profile: LegacyProfile) -> Bool {
        do {
            try store.save(profile)
            return true
        } catch {
            return false
        }
    }
}
