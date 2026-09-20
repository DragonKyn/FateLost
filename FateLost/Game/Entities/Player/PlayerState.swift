import CoreGraphics

/// A temporary stat boost on the player.
struct ActiveBuff {
    let id: String
    /// Modifiers for one stack.
    let modifiers: [StatModifier]
    var remaining: Double
    var stacks: Int
    let maxStacks: Int
}

/// Simulation state of the player character.
///
/// Holds only facts about the character. Behaviour lives in systems
/// (`MovementSystem`, `EnemyAISystem` for incoming hits, the skill runtime
/// for everything a build adds), which keeps this type small as the game
/// grows and keeps multiclass logic out of the player entirely.
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
    /// Absorbs damage before health.
    var barrier: Double = 0
    /// Seconds spent moving; drives the walk cycle.
    var strideTime: Double = 0
    /// Displacement velocity from being struck, decaying to zero.
    var knockback: CGPoint = .zero
    /// Seconds of hit immunity remaining.
    var invulnerability: Double = 0
    /// Seconds of stealth remaining.
    var stealth: Double = 0
    /// Current shapeshifted form, if any.
    var form: FormID?
    var buffs: [ActiveBuff] = []
    /// Bumped whenever buffs change, so stats know to recompute.
    var buffsVersion = 0

    // Timers that conditions read.
    var timeSinceHit: Double = .infinity
    var timeSinceKill: Double = .infinity
    var timeSinceDodge: Double = .infinity
    var timeStationary: Double = 0
    /// Blows that have landed on the hero. A friend channelling a revive is
    /// interrupted the moment this changes.
    var hitsTaken = 0

    init(position: CGPoint, maxHealth: Double) {
        self.position = position
        self.maxHealth = maxHealth
        health = maxHealth
    }

    var isMoving: Bool { velocity.lengthSquared > 0.0001 }
    var isDefeated: Bool { health <= 0 }
    var isInvulnerable: Bool { invulnerability > 0 }
    var isStealthed: Bool { stealth > 0 }
    var healthFraction: Double { maxHealth > 0 ? health / maxHealth : 0 }

    /// Adds or refreshes a buff, stacking up to its limit.
    mutating func applyBuff(id: String, modifiers: [StatModifier], duration: Double, maxStacks: Int) {
        if let index = buffs.firstIndex(where: { $0.id == id }) {
            buffs[index].remaining = max(buffs[index].remaining, duration)
            if buffs[index].stacks < buffs[index].maxStacks {
                buffs[index].stacks += 1
                buffsVersion &+= 1
            }
        } else {
            buffs.append(ActiveBuff(id: id, modifiers: modifiers, remaining: duration, stacks: 1,
                                    maxStacks: max(1, maxStacks)))
            buffsVersion &+= 1
        }
    }

    mutating func tickBuffs(_ dt: Double) {
        guard !buffs.isEmpty else { return }
        var index = buffs.count - 1
        while index >= 0 {
            buffs[index].remaining -= dt
            if buffs[index].remaining <= 0 {
                buffs.swapRemove(at: index)
                buffsVersion &+= 1
            }
            index -= 1
        }
    }
}

/// What the player wants to do this tick, already converted to world space.
struct PlayerIntent: Equatable {
    /// World-space direction with magnitude 0…1 (analogue stick travel).
    var move: CGPoint = .zero
    /// Bit per ability slot pressed this tick (0–2 abilities, 3 ultimate).
    var abilityPresses: UInt8 = 0
    /// Set for the step in which the player asked to interact: to begin
    /// reviving a fallen friend they are standing beside.
    var interact = false

    static let idle = PlayerIntent()

    func pressed(_ slot: Int) -> Bool {
        abilityPresses & (1 << UInt8(slot)) != 0
    }
}
