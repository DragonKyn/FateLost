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
    /// Starters bought from the Armoury, on top of the three every player
    /// begins with.
    var weapons: Set<WeaponID> = []
    /// Ranks of mastery bought per weapon.
    var weaponRanks: [WeaponID: Int] = [:]
    /// Looks bought from the character screen, by `HeroOption.id`.
    var cosmetics: Set<String> = []

    var totalEarned: Int { echoes + spent }

    /// Adds echoes outright. Only the developer tools use this: a run pays out
    /// through `record`.
    mutating func grant(echoes amount: Int) {
        echoes += max(0, amount)
    }

    /// Extra rerolls on every find, earned by filling in the codex.
    var bonusRerolls: Int { CodexRewards.bonusRerolls(discovered: lifetime.relicsDiscovered) }

    init() {}

    /// Decoded field by field so a profile written before a field existed
    /// still loads. A save is a player's history; adding to the game must
    /// never cost them any of it.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        echoes = try container.decodeIfPresent(Int.self, forKey: .echoes) ?? 0
        spent = try container.decodeIfPresent(Int.self, forKey: .spent) ?? 0
        unlocked = try container.decodeIfPresent(Set<String>.self, forKey: .unlocked) ?? []
        realms = try container.decodeIfPresent(RealmProgress.self, forKey: .realms) ?? RealmProgress()
        lifetime = try container.decodeIfPresent(LifetimeStats.self, forKey: .lifetime) ?? LifetimeStats()
        weapons = try container.decodeIfPresent(Set<WeaponID>.self, forKey: .weapons) ?? []
        weaponRanks = try container.decodeIfPresent([WeaponID: Int].self, forKey: .weaponRanks) ?? [:]
        cosmetics = try container.decodeIfPresent(Set<String>.self, forKey: .cosmetics) ?? []
    }

    // MARK: The wardrobe

    /// Whether the player may wear this: free, or already bought.
    func owns(_ option: HeroOption) -> Bool {
        HeroUnlocks.isFree(option) || cosmetics.contains(option.id)
    }

    /// Why an option cannot be bought right now, or nil if it can.
    func denial(for option: HeroOption) -> String? {
        if owns(option) { return "Already yours" }
        let cost = HeroUnlocks.cost(of: option)
        return echoes >= cost ? nil : "Costs \(cost) echoes"
    }

    @discardableResult
    mutating func buy(_ option: HeroOption) -> Bool {
        guard denial(for: option) == nil else { return false }
        let cost = HeroUnlocks.cost(of: option)
        echoes -= cost
        spent += cost
        cosmetics.insert(option.id)
        return true
    }

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

    // MARK: The Armoury

    func isUnlocked(_ weapon: WeaponDefinition) -> Bool {
        StarterWeapons.defaultUnlocked.contains(weapon.id) || weapons.contains(weapon.id)
    }

    func rank(of weapon: WeaponDefinition) -> Int {
        min(weaponRanks[weapon.id] ?? 0, WeaponMastery.maxRank)
    }

    /// Why a weapon cannot be bought right now, or nil if it can.
    func weaponDenial(for weapon: WeaponDefinition) -> String? {
        if isUnlocked(weapon) { return "Already on the rack" }
        let cost = WeaponMastery.unlockCost(weapon)
        return echoes >= cost ? nil : "Costs \(cost) echoes"
    }

    /// Why the next rank cannot be bought, or nil if it can.
    func masteryDenial(for weapon: WeaponDefinition) -> String? {
        guard isUnlocked(weapon) else { return "Unlock it first" }
        let next = rank(of: weapon) + 1
        if next > WeaponMastery.maxRank { return "Mastered" }
        let cost = WeaponMastery.rankCost(next)
        return echoes >= cost ? nil : "Costs \(cost) echoes"
    }

    @discardableResult
    mutating func buy(weapon: WeaponDefinition) -> Bool {
        guard weaponDenial(for: weapon) == nil else { return false }
        let cost = WeaponMastery.unlockCost(weapon)
        echoes -= cost
        spent += cost
        weapons.insert(weapon.id)
        return true
    }

    @discardableResult
    mutating func master(weapon: WeaponDefinition) -> Bool {
        guard masteryDenial(for: weapon) == nil else { return false }
        let next = rank(of: weapon) + 1
        let cost = WeaponMastery.rankCost(next)
        echoes -= cost
        spent += cost
        weaponRanks[weapon.id] = next
        return true
    }

    /// What mastery of this weapon is worth to a run started with it.
    func modifiers(startingWith weapon: WeaponDefinition) -> [StatModifier] {
        WeaponMastery.modifiers(for: weapon, rank: rank(of: weapon))
    }

    /// Every bonus the board currently grants, ready for a run's stat sheet.
    var modifiers: [StatModifier] {
        unlocked.compactMap { LegacyTree.node($0)?.modifier }
    }

    // MARK: Runs

    /// Folds a finished run into the lifetime record and pays out its echoes.
    /// A party's run passes what the party's shared pool pays this hero.
    mutating func record(_ summary: RunSummary, realm: RealmDefinition, echoes fixed: Int? = nil) {
        let earned = fixed ?? LegacyEchoes.earned(from: summary.stats, wave: summary.wave, level: summary.level,
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

    /// Spoils, over every run.
    var chestsOpened = 0
    var shrinesUsed = 0
    var relicsTaken = 0
    var weaponsFound = 0
    var mostRelicsCarried = 0
    /// The highest rank each relic has ever been carried at. Its keys are the
    /// codex: a relic is discovered the first time one is carried.
    var relicsSeen: [String: Int] = [:]

    /// Relics discovered so far.
    var relicsDiscovered: Int { relicsSeen.keys.filter { RelicCatalog.relic($0) != nil }.count }

    init() {}

    /// Decoded field by field, like the profile that holds it, so a record
    /// written before spoils existed still loads with every total intact.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runs = try c.decodeIfPresent(Int.self, forKey: .runs) ?? 0
        conquests = try c.decodeIfPresent(Int.self, forKey: .conquests) ?? 0
        kills = try c.decodeIfPresent(Int.self, forKey: .kills) ?? 0
        eliteKills = try c.decodeIfPresent(Int.self, forKey: .eliteKills) ?? 0
        bossKills = try c.decodeIfPresent(Int.self, forKey: .bossKills) ?? 0
        deaths = try c.decodeIfPresent(Int.self, forKey: .deaths) ?? 0
        secondsPlayed = try c.decodeIfPresent(Int.self, forKey: .secondsPlayed) ?? 0
        damageDealt = try c.decodeIfPresent(Double.self, forKey: .damageDealt) ?? 0
        damageTaken = try c.decodeIfPresent(Double.self, forKey: .damageTaken) ?? 0
        healingReceived = try c.decodeIfPresent(Double.self, forKey: .healingReceived) ?? 0
        summonsLost = try c.decodeIfPresent(Int.self, forKey: .summonsLost) ?? 0
        echoesEarned = try c.decodeIfPresent(Int.self, forKey: .echoesEarned) ?? 0
        highestWave = try c.decodeIfPresent(Int.self, forKey: .highestWave) ?? 0
        highestLevel = try c.decodeIfPresent(Int.self, forKey: .highestLevel) ?? 0
        highestHit = try c.decodeIfPresent(Double.self, forKey: .highestHit) ?? 0
        longestRunSeconds = try c.decodeIfPresent(Int.self, forKey: .longestRunSeconds) ?? 0
        largestHorde = try c.decodeIfPresent(Int.self, forKey: .largestHorde) ?? 0
        bestWaveByRealm = try c.decodeIfPresent([String: Int].self, forKey: .bestWaveByRealm) ?? [:]
        runsByWeapon = try c.decodeIfPresent([String: Int].self, forKey: .runsByWeapon) ?? [:]
        pointsByArchetype = try c.decodeIfPresent([String: Int].self, forKey: .pointsByArchetype) ?? [:]
        chestsOpened = try c.decodeIfPresent(Int.self, forKey: .chestsOpened) ?? 0
        shrinesUsed = try c.decodeIfPresent(Int.self, forKey: .shrinesUsed) ?? 0
        relicsTaken = try c.decodeIfPresent(Int.self, forKey: .relicsTaken) ?? 0
        weaponsFound = try c.decodeIfPresent(Int.self, forKey: .weaponsFound) ?? 0
        mostRelicsCarried = try c.decodeIfPresent(Int.self, forKey: .mostRelicsCarried) ?? 0
        relicsSeen = try c.decodeIfPresent([String: Int].self, forKey: .relicsSeen) ?? [:]
    }

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
        chestsOpened += summary.stats.chestsOpened
        shrinesUsed += summary.stats.shrinesUsed
        relicsTaken += summary.stats.relicsTaken
        weaponsFound += summary.stats.weaponsWielded
        mostRelicsCarried = max(mostRelicsCarried, summary.relics.count)
        for (relic, rank) in summary.relics.held {
            relicsSeen[relic.id] = max(relicsSeen[relic.id] ?? 0, rank)
        }
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

    /// Forgets everything. The next launch is a first launch.
    func erase() {
        store.erase()
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
