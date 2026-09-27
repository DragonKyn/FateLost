import CoreGraphics
import Foundation

/// Every number the endgame is balanced on, in one place: the Abyss's
/// length, Fate's own fight (most of which lives on its `BossKit` in
/// `EnemyCatalog.fate`), and Fate's Echo's escalation and banking.
enum FateTuning {
    // MARK: The Abyss

    /// A champion every this many waves, as in every other realm.
    static let abyssBossEvery = 5
    /// The strongest champions the Abyss sends before Fate itself. Kept to a
    /// handful on purpose: every champion in the game, one after another,
    /// would put Fate at wave 140 — over ninety minutes in, with the run's
    /// time-based health curve having pushed Fate past twelve million health.
    /// Five, so Fate falls on wave 30 — as long as the Gate of Ruin, and
    /// inside the campaign's rule that no realm asks for an evening.
    static let abyssChampionsBeforeFate = 5
    /// The wave Fate is fought on. Conquering the Abyss is defeating Fate.
    static var abyssFinalWave: Int { abyssBossEvery * (abyssChampionsBeforeFate + 1) }

    // MARK: Fate's fight
    //
    // Fate's health, barrier fraction, reach, tempo and summon limits live on
    // its `BossKit` in `EnemyCatalog.fate`. These are the attacks' own timings.

    /// Firebomb rain: how many fall, the first one's warning, and the gap
    /// between each landing after it.
    static let firebombCount = 7
    static let firebombWarning = 1.6
    static let firebombStagger = 0.35
    static let firebombRadius: CGFloat = 1.6
    static let firebombSpread: CGFloat = 6

    /// The Encroaching Abyss: the safe circle, the warning before the dark
    /// hurts, how long it then hurts, and how much (a fraction of max health
    /// every second spent outside the circle).
    static let eclipseSafeRadius: CGFloat = 2.6
    static let eclipseWarning = 4.0
    static let eclipseDuration = 7.5
    static let eclipseDamagePerSecond = 0.05
    /// How far from the hero the safe circle may open — always reachable
    /// inside the warning at an ordinary walking pace.
    static let eclipseSafeDistance: CGFloat = 8

    // MARK: Fate's Echo

    /// Fate's Echo's own starting values (tier 0, waves 1–5), as multiples
    /// of an enemy's catalogue health and damage. Every tier compounds on
    /// these. A little above an ordinary realm's first wave, since the only
    /// way here is past Fate.
    static let echoBaseHealth = 1.6
    static let echoBaseDamage = 1.3
    /// Waves per tier. Waves 1–5 are tier 0, 6–10 tier 1, and so on.
    static let echoWavesPerTier = 5
    /// Compounding per tier, against Fate's Echo's own starting values.
    static let echoHealthPerTier = 0.20
    static let echoDamagePerTier = 0.10
    /// Past this tier (wave 600) the multipliers stop growing. 1.2^120 is
    /// about 3 billion — already far beyond what any hero outlasts — and
    /// the cap keeps every derived number (health, damage, the Int a damage
    /// number is shown as) finite and well clear of overflow forever.
    static let echoMaxTier = 120
    /// Waves between each offer to bank echoes and leave.
    static let echoOfferEvery = 10

    /// The tier a wave belongs to: 0 for waves 1–5, 1 for 6–10, 2 for 11–15.
    static func echoTier(atWave wave: Int) -> Int {
        min(echoMaxTier, max(0, (wave - 1) / echoWavesPerTier))
    }

    static func echoHealthMultiplier(atWave wave: Int) -> Double {
        pow(1 + echoHealthPerTier, Double(echoTier(atWave: wave)))
    }

    static func echoDamageMultiplier(atWave wave: Int) -> Double {
        pow(1 + echoDamagePerTier, Double(echoTier(atWave: wave)))
    }

    /// Whether finishing `wave` should stop and offer the choice: after
    /// waves 10, 20, 30…
    static func offersChoice(afterWave wave: Int) -> Bool {
        wave > 0 && wave % echoOfferEvery == 0
    }

    // MARK: The ending


    /// Seconds of quiet after Fate falls before the ending card appears.
    static let endingPause: Double = 2.5
    static let studioURL = URL(string: "https://WickedStudios.ca")!
}

/// Fate's Echo stopping to ask: bank what this run has earned and leave, or
/// keep it at risk and go on. Held on the simulation until answered; the
/// scene stays still the whole time it is up.
struct EchoOffer: Equatable {
    /// The wave just finished: 10, 20, 30…
    let completedWave: Int
    /// The wave that begins if the player goes on.
    var nextWave: Int { completedWave + 1 }
    /// Whether going on crosses into a harder five-wave tier.
    var nextWaveIsHarder: Bool {
        FateTuning.echoTier(atWave: nextWave) > FateTuning.echoTier(atWave: completedWave)
    }
}
