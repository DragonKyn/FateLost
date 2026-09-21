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

    /// A hero who is clearly nearer than the one an orb is flying to may take it.
    static let stealMargin: CGFloat = 0.75

    /// - Parameters:
    ///   - hero: Which hero is gathering (the party takes each in turn).
    ///   - targets: Where every hero is, so a thing in flight can tell whether
    ///     the hero it is flying to is still there to reach.
    static func step(_ combat: inout CombatState, player: PlayerState, hero: Int = 0, targets: [AITarget] = [],
                     dt: TimeInterval) {
        guard !player.isDefeated else { return }
        stepOrbs(&combat, player: player, hero: hero, targets: targets, dt: dt)
        stepDrops(&combat, player: player, hero: hero, targets: targets, dt: dt)
    }

    /// Whether `hero` moves a thing that is already flying. The hero it is
    /// flying to moves it and nobody else does (every hero's turn used to pull
    /// on it, so it jittered and often drifted to the host). It changes hands
    /// only when its hero is gone, or another is in range and clearly nearer.
    private static func mayMove(_ claim: inout Int?, hero: Int, at position: CGPoint, distance: CGFloat,
                                inRange: Bool, targets: [AITarget], world: ToroidalWorld) -> Bool {
        guard let current = claim, current != hero else {
            claim = hero
            return true
        }
        guard let holder = targets.first(where: { $0.hero == current && $0.isAlive }) else {
            claim = hero
            return true
        }
        if inRange, distance + stealMargin < world.distance(position, holder.position) {
            claim = hero
            return true
        }
        return false
    }

    // MARK: Experience

    private static func stepOrbs(_ combat: inout CombatState, player: PlayerState, hero: Int, targets: [AITarget],
                                 dt: TimeInterval) {
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
                orb.claimedBy = hero
            }
            if orb.attracted {
                guard mayMove(&orb.claimedBy, hero: hero, at: orb.position, distance: distanceSquared.squareRoot(),
                              inRange: distanceSquared <= radiusSquared, targets: targets, world: combat.world) else {
                    combat.orbs[index] = orb
                    index -= 1
                    continue
                }
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

    private static func stepDrops(_ combat: inout CombatState, player: PlayerState, hero: Int, targets: [AITarget],
                                  dt: TimeInterval) {
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
                    drop.claimedBy = hero
                }
                if drop.attracted {
                    guard mayMove(&drop.claimedBy, hero: hero, at: drop.position, distance: distance,
                                  inRange: distance <= radius, targets: targets, world: combat.world) else {
                        combat.drops[index] = drop
                        index -= 1
                        continue
                    }
                    drop.speed = min(drop.speed + acceleration * step, maximumSpeed)
                    if distance <= collectDistance + drop.speed * step {
                        collect(drop, &combat, player: player, hero: hero)
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

    private static func collect(_ drop: Drop, _ combat: inout CombatState, player: PlayerState, hero: Int) {
        switch drop.kind {
        case .vial:
            combat.pendingHealing += player.maxHealth * DropTable.vialHeal
        case .magnet:
            for index in combat.orbs.indices {
                combat.orbs[index].attracted = true
                combat.orbs[index].speed = max(combat.orbs[index].speed, initialSpeed)
                // Everything on the ground flies to whoever picked the magnet up.
                combat.orbs[index].claimedBy = hero
            }
        case .chest:
            break
        }
        combat.events.append(.dropCollected(kind: drop.kind, position: drop.position))
    }
}
