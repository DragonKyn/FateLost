import CoreGraphics
import Foundation

/// Gathers what lies in the world: experience, vials, magnets and chests.
///
/// Orbs within the player's pickup radius are drawn in, accelerating, and
/// collected on arrival, so walking near a fight sweeps up its rewards
/// without chasing every mote. Vials and magnets do the same. Chests do not:
/// a chest stays where it fell and opens when the player walks onto it, so
/// getting to one is a decision made in the middle of a fight.
enum PickupSystem {
    static let collectDistance: CGFloat = 0.35
    static let initialSpeed: CGFloat = 3
    static let acceleration: CGFloat = 32
    static let maximumSpeed: CGFloat = 20

    static func step(_ combat: inout CombatState, player: PlayerState, dt: TimeInterval) {
        guard !player.isDefeated else { return }
        stepOrbs(&combat, player: player, dt: dt)
        stepDrops(&combat, player: player, dt: dt)
    }

    // MARK: Experience

    private static func stepOrbs(_ combat: inout CombatState, player: PlayerState, dt: TimeInterval) {
        guard !combat.orbs.isEmpty else { return }
        let radius = CGFloat(combat.sheet[.pickupRadius])
        let radiusSquared = radius * radius
        let step = CGFloat(dt)

        var index = combat.orbs.count - 1
        while index >= 0 {
            var orb = combat.orbs[index]
            let offset = combat.world.delta(from: orb.position, to: player.position)
            let distanceSquared = offset.lengthSquared
            if !orb.attracted, distanceSquared <= radiusSquared {
                orb.attracted = true
                orb.speed = initialSpeed
            }
            if orb.attracted {
                orb.speed = min(orb.speed + acceleration * step, maximumSpeed)
                let distance = distanceSquared.squareRoot()
                if distance <= collectDistance + orb.speed * step {
                    combat.experienceCollected += orb.value
                    combat.orbs.swapRemove(at: index)
                    index -= 1
                    continue
                }
                orb.position = combat.world.wrap(orb.position + offset / distance * orb.speed * step)
            }
            combat.orbs[index] = orb
            index -= 1
        }
    }

    // MARK: Drops

    private static func stepDrops(_ combat: inout CombatState, player: PlayerState, dt: TimeInterval) {
        guard !combat.drops.isEmpty else { return }
        let radius = CGFloat(combat.sheet[.pickupRadius])
        let step = CGFloat(dt)

        var index = combat.drops.count - 1
        while index >= 0 {
            var drop = combat.drops[index]
            drop.age += dt
            let offset = combat.world.delta(from: drop.position, to: player.position)
            let distance = offset.length

            switch drop.kind {
            case .chest(let tier):
                if tier == .cache, drop.age > DropTable.cacheLifetime {
                    combat.drops.swapRemove(at: index)
                } else if distance <= DropTable.chestOpenDistance {
                    combat.pendingFinds.append(tier)
                    combat.stats.chestsOpened += 1
                    combat.events.append(.dropCollected(kind: drop.kind, position: drop.position))
                    combat.drops.swapRemove(at: index)
                } else {
                    combat.drops[index] = drop
                }

            case .vial, .magnet:
                if !drop.attracted, distance <= radius {
                    drop.attracted = true
                    drop.speed = initialSpeed
                }
                if drop.attracted {
                    drop.speed = min(drop.speed + acceleration * step, maximumSpeed)
                    if distance <= collectDistance + drop.speed * step {
                        collect(drop, &combat, player: player)
                        combat.drops.swapRemove(at: index)
                        index -= 1
                        continue
                    }
                    drop.position = combat.world.wrap(drop.position + offset / distance * drop.speed * step)
                }
                combat.drops[index] = drop
            }
            index -= 1
        }
    }

    private static func collect(_ drop: Drop, _ combat: inout CombatState, player: PlayerState) {
        switch drop.kind {
        case .vial:
            combat.pendingHealing += player.maxHealth * DropTable.vialHeal
        case .magnet:
            for index in combat.orbs.indices {
                combat.orbs[index].attracted = true
                combat.orbs[index].speed = max(combat.orbs[index].speed, initialSpeed)
            }
        case .chest:
            break
        }
        combat.events.append(.dropCollected(kind: drop.kind, position: drop.position))
    }
}
