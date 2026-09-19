import CoreGraphics

/// Something that happened during a simulation step that presentation may
/// want to show, play or feel.
///
/// The simulation appends events as it resolves combat; the scene drains
/// them once per frame and turns them into effects, sounds and haptics. Game
/// rules never depend on whether an event was presented.
enum CombatEvent: Equatable {
    /// A melee weapon swung. `direction` is a unit vector in world space.
    case meleeSwing(origin: CGPoint, direction: CGPoint, range: CGFloat, arcDegrees: Double)
    case projectileFired(spriteID: SpriteID, origin: CGPoint, direction: CGPoint)
    case enemyHit(enemyID: Int, position: CGPoint, amount: Double, isCritical: Bool, direction: CGPoint)
    case enemyKilled(enemyID: Int, kind: EnemyKindID, position: CGPoint, direction: CGPoint)
    /// An enemy began a strike (the telegraph).
    case enemyWindup(enemyID: Int)
    case explosion(position: CGPoint, radius: CGFloat)
    /// `direction` points from the attacker toward the player.
    case playerHit(amount: Double, direction: CGPoint)
    case playerDefeated
}

/// Running totals for the end-of-run summary.
struct RunStats: Equatable {
    var kills = 0
    var damageDealt: Double = 0
    var damageTaken: Double = 0
    var criticalHits = 0
    var mostEnemiesAlive = 0
}
