import CoreGraphics
import Foundation

/// Pulses lasting areas (fields, auras, storms) and lands impacts that were
/// announced earlier (arrow rain, meteors, pillars of light).
enum ZoneSystem {
    static func step(_ combat: inout CombatState, player: inout PlayerState, dt: TimeInterval) {
        stepZones(&combat, player: &player, dt: dt)
        stepStrikes(&combat, dt: dt)
    }

    private static func stepZones(_ combat: inout CombatState, player: inout PlayerState, dt: TimeInterval) {
        guard !combat.zones.isEmpty else { return }
        let areaSize = CGFloat(combat.sheet[.areaSize])
        var index = combat.zones.count - 1
        while index >= 0 {
            var zone = combat.zones[index]
            zone.remaining -= dt
            zone.age += dt
            if zone.remaining <= 0 {
                combat.zones.swapRemove(at: index)
                index -= 1
                continue
            }
            if zone.spec.follows {
                zone.position = player.position
            }
            zone.radius = CGFloat(zone.spec.radius.value) * areaSize
            zone.tickTimer -= dt
            let pulses = zone.tickTimer <= 0
            if pulses {
                zone.tickTimer += max(zone.spec.tick, 0.05)
            }
            combat.zones[index] = zone
            if pulses {
                pulse(zone, &combat, player: &player)
            }
            index -= 1
        }
    }

    private static func pulse(_ zone: Zone, _ combat: inout CombatState, player: inout PlayerState) {
        let spec = zone.spec
        if !spec.playerBuff.isEmpty,
           combat.world.distance(player.position, zone.position) <= zone.radius {
            player.applyBuff(id: "zone.\(zone.id)", modifiers: spec.playerBuff.map { $0.at(1) },
                             duration: spec.tick * 1.6 + 0.05, maxStacks: 1)
        }
        guard spec.damage != nil || spec.status != nil || spec.pull > 0 else { return }

        combat.nearbySecondary.removeAll(keepingCapacity: true)
        combat.grid.query(around: zone.position, radius: zone.radius + combat.largestEnemyRadius,
                          into: &combat.nearbySecondary)
        var inside: [Int] = []
        for index in combat.nearbySecondary where index < combat.enemies.count && combat.enemies.health[index] > 0 {
            let reach = zone.radius + combat.enemies.definition(at: index).radius
            if combat.world.distance(zone.position, combat.enemies.positions[index]) <= reach {
                inside.append(index)
            }
        }
        guard !inside.isEmpty else { return }

        let source: HitSource = zone.depth == 0 && !zone.isAura ? .ability : .proc
        // Aura damage counts as the player's own, but never sets off triggers.
        let depth = zone.isAura ? 1 : zone.depth

        if spec.strikesPerTick > 0 {
            var remaining = spec.strikesPerTick
            while remaining > 0, !inside.isEmpty {
                let pick = min(inside.count - 1, Int(combat.random.unit() * Double(inside.count)))
                let index = inside.swapRemoveReturning(at: pick)
                let position = combat.enemies.positions[index]
                if let damage = spec.damage {
                    var hit = combat.hit(from: damage, direction: CGPoint(x: 0, y: 1), depth: depth, source: source)
                    hit.status = spec.status
                    combat.strike(index, with: hit)
                } else if let status = spec.status {
                    combat.applyStatus(status, to: index)
                }
                combat.events.append(.bolt(position: position, visual: spec.visual))
                remaining -= 1
            }
            return
        }

        for index in inside {
            let offset = combat.world.delta(from: zone.position, to: combat.enemies.positions[index])
            let distance = offset.length
            let outward = distance > 0.0001 ? offset / distance : CGPoint(x: 1, y: 0)
            if let damage = spec.damage {
                var hit = combat.hit(from: damage, direction: outward, depth: depth, source: source)
                hit.status = spec.status
                combat.strike(index, with: hit)
            } else if let status = spec.status {
                combat.applyStatus(status, to: index)
            }
            if spec.pull > 0, distance > 0.3 {
                combat.enemies.knockback[index] = combat.enemies.knockback[index] - outward * spec.pull
            }
        }
    }

    private static func stepStrikes(_ combat: inout CombatState, dt: TimeInterval) {
        guard !combat.strikes.isEmpty else { return }
        var index = combat.strikes.count - 1
        while index >= 0 {
            combat.strikes[index].remaining -= dt
            if combat.strikes[index].remaining <= 0 {
                let strike = combat.strikes[index]
                combat.strikes.swapRemove(at: index)
                combat.events.append(.burst(position: strike.position, radius: strike.radius, visual: strike.visual))
                ActionExecutor.affect(around: strike.position, radius: strike.radius, damage: strike.damage,
                                      status: strike.status, depth: strike.depth,
                                      source: strike.depth == 0 ? .ability : .proc, &combat)
            }
            index -= 1
        }
    }
}

extension Array {
    /// Removes and returns an element without preserving order.
    mutating func swapRemoveReturning(at index: Int) -> Element {
        let element = self[index]
        swapRemove(at: index)
        return element
    }
}
