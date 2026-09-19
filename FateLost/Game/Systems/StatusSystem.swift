import Foundation

/// Counts down enemy statuses and deals damage over time.
///
/// Damage over time ticks for every enemy together twice a second rather
/// than every frame: the same total damage, a fraction of the events.
struct StatusSystem {
    static let damageInterval: Double = 0.5
    private static let damageKinds: [StatusKind] = [.burn, .poison, .bleed]
    private static let allKinds = StatusKind.allCases

    private var damageTimer: Double = 0

    mutating func step(_ combat: inout CombatState, dt: TimeInterval) {
        damageTimer += dt
        let damageTick = damageTimer >= Self.damageInterval
        if damageTick {
            damageTimer -= Self.damageInterval
        }
        let elapsed = Float(dt)

        for index in 0..<combat.enemies.count {
            var mask = combat.enemies.statusMask[index]
            guard mask != 0 else { continue }

            if damageTick, combat.enemies.health[index] > 0 {
                for kind in Self.damageKinds where mask & kind.bit != 0 {
                    let perSecond = Double(combat.enemies.statusPotency[kind.rawValue][index])
                    guard perSecond > 0 else { continue }
                    let hit = Hit(amount: perSecond * Self.damageInterval, type: kind.damageType, tags: .dot,
                                  knockback: 0, canCrit: false, depth: 9, source: .damageOverTime)
                    combat.strike(index, with: hit)
                }
            }

            for kind in Self.allKinds where mask & kind.bit != 0 {
                let slot = kind.rawValue
                combat.enemies.statusTime[slot][index] -= elapsed
                if combat.enemies.statusTime[slot][index] <= 0 {
                    combat.enemies.statusTime[slot][index] = 0
                    combat.enemies.statusPotency[slot][index] = 0
                    mask &= ~kind.bit
                }
            }
            combat.enemies.statusMask[index] = mask
        }
    }
}
