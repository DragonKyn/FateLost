import CoreGraphics

/// Simulation state of the player character.
///
/// Holds only facts about the character. Behaviour lives in systems
/// (`MovementSystem`, `EnemyAISystem` for incoming hits; stats and skills in
/// later phases), which keeps this type small as the game grows and keeps
/// multiclass logic out of the player entirely.
struct PlayerState {
    /// Wrapped world position, in tiles.
    var position: CGPoint
    /// World units per second.
    var velocity: CGPoint = .zero
    /// Last non-zero movement direction in world space, for facing and
    /// directional attacks.
    var facing: CGPoint = CGPoint(x: 1, y: 0)
    var maxHealth: Double
    var health: Double
    /// Seconds spent moving; drives the walk cycle.
    var strideTime: Double = 0
    /// Displacement velocity from being struck, decaying to zero.
    var knockback: CGPoint = .zero
    /// Seconds of hit immunity remaining.
    var invulnerability: Double = 0
    /// Seconds since the player was last hit, for presentation.
    var timeSinceHit: Double = .infinity

    init(position: CGPoint, maxHealth: Double) {
        self.position = position
        self.maxHealth = maxHealth
        health = maxHealth
    }

    var isMoving: Bool { velocity.lengthSquared > 0.0001 }
    var isDefeated: Bool { health <= 0 }
    var isInvulnerable: Bool { invulnerability > 0 }
}

/// What the player wants to do this tick, already converted to world space.
struct PlayerIntent: Equatable {
    /// World-space direction with magnitude 0…1 (analogue stick travel).
    var move: CGPoint = .zero

    static let idle = PlayerIntent()
}
