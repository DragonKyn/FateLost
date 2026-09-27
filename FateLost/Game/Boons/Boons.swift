import Foundation

/// A timed blessing a player earns by choosing to watch a rewarded advert.
///
/// Boons are counted in seconds of *play*, not seconds of the clock: they
/// only run down while a solo run is actually being fought, so time spent in
/// menus, paused, backgrounded or watching an advert costs nothing.
enum Boon: String, Codable, CaseIterable, Identifiable {
    /// Echoes earned while it runs are doubled.
    case doubleEchoes
    /// A fallen champion is likelier to leave a rift behind it.
    case riftCalling

    var id: String { rawValue }

    var name: String {
        switch self {
        case .doubleEchoes: return "Double Echoes"
        case .riftCalling: return "Rift's Calling"
        }
    }

    /// Exactly what the advert pays, said before it is shown.
    var rewardText: String {
        switch self {
        case .doubleEchoes:
            return "Echoes you earn in solo runs are doubled for 10 minutes of play. "
                + "Echoes already earned are not changed."
        case .riftCalling:
            return "In solo runs, each champion you fell gets +10% chance to open a rift to a "
                + "Rift Guardian (10% becomes 20%), for 10 minutes of play."
        }
    }

    /// The watch button's words.
    var watchLabel: String {
        switch self {
        case .doubleEchoes: return "Watch ad: Double Echoes for 10 minutes"
        case .riftCalling: return "Watch ad: +10% Rift chance for 10 minutes"
        }
    }

    var symbol: String {
        switch self {
        case .doubleEchoes: return "sparkles"
        case .riftCalling: return "circle.hexagongrid.fill"
        }
    }
}

enum BoonTuning {
    /// Seconds of play one advert adds. Watching another adds the same again
    /// on top of whatever is left: they stack in time, never in strength.
    static let secondsPerAdvert: TimeInterval = 10 * 60
    /// Rift's Calling adds this much to the chance a fallen champion opens a
    /// rift: ten percentage points on top of the base (10% becomes 20%).
    static let riftChanceBonus: Double = 0.10
    /// Double Echoes pays each echo earned under it once more: ×2, whatever
    /// else is boosting the run, and never ×4 for two adverts.
    static let echoMultiplier = 2
    /// The most play time a stack of adverts may bank, so a counter can never
    /// grow without bound. Far beyond anything a player would reach.
    static let maximumSeconds: TimeInterval = 24 * 60 * 60
}

/// What is left on each boon, in seconds of play.
struct BoonTimers: Codable, Equatable {
    var doubleEchoesSeconds: Double = 0
    var riftCallingSeconds: Double = 0

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        doubleEchoesSeconds = Self.sane((try? values.decodeIfPresent(Double.self, forKey: .doubleEchoesSeconds)) ?? 0)
        riftCallingSeconds = Self.sane((try? values.decodeIfPresent(Double.self, forKey: .riftCallingSeconds)) ?? 0)
    }

    func remaining(_ boon: Boon) -> Double {
        switch boon {
        case .doubleEchoes: return doubleEchoesSeconds
        case .riftCalling: return riftCallingSeconds
        }
    }

    func isActive(_ boon: Boon) -> Bool {
        remaining(boon) > 0
    }

    /// Whole seconds left, rounded up, for display: a boon with a sliver left
    /// still reads as running.
    func wholeSeconds(_ boon: Boon) -> Int {
        Int(remaining(boon).rounded(.up))
    }

    /// Adds one advert's worth of time on top of what is left.
    mutating func grant(_ boon: Boon) {
        set(boon, Self.sane(remaining(boon) + BoonTuning.secondsPerAdvert))
    }

    /// Runs every boon down by some seconds of play.
    mutating func consume(_ seconds: Double) {
        guard seconds > 0, seconds.isFinite else { return }
        for boon in Boon.allCases where isActive(boon) {
            set(boon, max(0, remaining(boon) - seconds))
        }
    }

    private mutating func set(_ boon: Boon, _ value: Double) {
        switch boon {
        case .doubleEchoes: doubleEchoesSeconds = value
        case .riftCalling: riftCallingSeconds = value
        }
    }

    /// A value read from disk or added up is kept finite, non-negative and
    /// under the cap, whatever the file said.
    private static func sane(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(0, value), BoonTuning.maximumSeconds)
    }
}

/// Keeps count of the echoes a run earned while Double Echoes was running,
/// so exactly those — and nothing earned before or after — are doubled.
///
/// A run's echoes are worked out from its record when it ends, not paid as
/// they fall, so the tally samples what the run *would* pay at the moments
/// the boon starts and stops, and adds up the difference.
struct EchoBoostTally: Equatable {
    /// Echoes earned under the boon in spans that have already closed.
    private(set) var closed = 0
    /// What the run would have paid when the current span opened, if one is open.
    private(set) var openedAt: Int?

    var isOpen: Bool { openedAt != nil }

    /// The boon is running from here: `payoutSoFar` is what the run is worth now.
    mutating func open(at payoutSoFar: Int) {
        guard openedAt == nil else { return }
        openedAt = max(0, payoutSoFar)
    }

    /// The boon has run out: what was earned under it is banked.
    mutating func close(at payoutSoFar: Int) {
        guard let start = openedAt else { return }
        closed += max(0, payoutSoFar - start)
        openedAt = nil
    }

    /// The extra echoes Double Echoes adds to a run that paid `finalPayout`.
    ///
    /// Never more than the run paid (so it is at most ×2), and nothing at all
    /// for a run that paid nothing, such as a fall in Fate's Echo before banking.
    func bonus(finalPayout: Int) -> Int {
        guard finalPayout > 0 else { return 0 }
        var boosted = closed
        if let start = openedAt {
            boosted += max(0, finalPayout - start)
        }
        let extra = boosted * (BoonTuning.echoMultiplier - 1)
        return min(max(0, extra), finalPayout * (BoonTuning.echoMultiplier - 1))
    }
}

/// Where boon timers are kept between launches: their own small file, so
/// nothing that happens to the profile can touch them or they it.
final class BoonStore {
    static let schemaVersion = 1
    private let store: VersionedFileStore<BoonTimers>

    init(fileURL: URL? = nil) {
        let url = fileURL ?? SaveLocations.directory().appendingPathComponent("boons.json")
        store = VersionedFileStore(fileURL: url, currentVersion: Self.schemaVersion)
    }

    func load() -> BoonTimers {
        store.load().payload ?? BoonTimers()
    }

    func erase() {
        store.erase()
    }

    @discardableResult
    func save(_ timers: BoonTimers) -> Bool {
        do {
            try store.save(timers)
            return true
        } catch {
            return false
        }
    }
}
