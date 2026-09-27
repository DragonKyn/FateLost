import CoreGraphics
import Foundation

/// The Encroaching Abyss: Fate's darkness spreads over the whole arena,
/// leaving one small circle lit. It warns before it hurts, the same as any
/// hazard, and it hurts through `strikePlayer`'s ordinary rules — armor,
/// barrier and invulnerability all apply, exactly as they would to standing
/// in a boss's fire pool. See `BossSystem.advanceDarkness`.
struct DarknessState: Equatable {
    var safeCenter: CGPoint
    var safeRadius: CGFloat
    /// Seconds until the dark actually starts costing health.
    var warningRemaining: Double
    /// Seconds it keeps hurting once the warning ends, then it lifts.
    var activeRemaining: Double
    /// Fraction of max health lost per second spent outside the safe circle.
    var damagePerSecond: Double

    var isWarning: Bool { warningRemaining > 0 }
    /// Finished and due to be cleared: past both the warning and the hurt.
    var isFinished: Bool { warningRemaining <= 0 && activeRemaining <= 0 }
}
