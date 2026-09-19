import Foundation

/// How a realm paces its waves.
///
/// A wave is a stretch of time, not a fixed list of bodies: the horde never
/// stops arriving, and the wave number is what decides how hard it pushes
/// and what is allowed to walk in. Every `bossEvery` waves the realm sends
/// its champion, and that wave stays open until the champion falls — the one
/// moment in a run where the game asks for a fight rather than a retreat.
struct WavePlan: Equatable {
    /// Seconds an ordinary wave lasts.
    var waveSeconds: Double = 45
    /// A boss arrives on every wave whose number is a multiple of this.
    var bossEvery: Int = 5
    /// Seconds of warning before the champion lands.
    var bossGraceSeconds: Double = 2.5
    /// Bodies that arrive with it.
    var escortCount: Int = 5
    /// While a boss is up, ordinary spawning is cut to this share, so the
    /// fight is against the champion rather than the crowd.
    var bossSpawnShare: Double = 0.35
    /// Spawn rate gained per wave, compounding gently.
    var pressurePerWave: Double = 0.07
    /// The realm's champions, in the order they are sent. The last one
    /// repeats for as long as the run continues.
    var bosses: [EnemyKindID] = []

    /// The champion for a given boss wave.
    func boss(forWave wave: Int) -> EnemyKindID? {
        guard !bosses.isEmpty, bossEvery > 0, wave % bossEvery == 0 else { return nil }
        let ordinal = wave / bossEvery - 1
        return bosses[min(ordinal, bosses.count - 1)]
    }

    func isBossWave(_ wave: Int) -> Bool {
        boss(forWave: wave) != nil
    }

    /// How much harder the horde pushes by this wave.
    func pressure(atWave wave: Int) -> Double {
        1 + pressurePerWave * Double(max(0, wave - 1))
    }
}
