import CoreGraphics
import Foundation

/// Carries out `EffectAction`s: the one interpreter behind every ability and
/// triggered effect.
///
/// Actions are queued by casts and triggers and run here between systems,
/// never in the middle of another system's loop, so shared query buffers and
/// enemy indices are always safe to use.
enum ActionExecutor {
    /// Effects set off by effects set off by effects stop here.
    static let maximumDepth = 4

    /// Runs every queued action, including any they queue in turn.
    static func flush(_ combat: inout CombatState, player: inout PlayerState) {
        var rounds = 0
        while !combat.pendingActions.isEmpty, rounds < 8 {
            rounds += 1
            let batch = combat.pendingActions
            combat.pendingActions.removeAll(keepingCapacity: true)
            for queued in batch where queued.depth <= maximumDepth {
                run(queued.action, queued, &combat, &player)
            }
        }
        combat.pendingActions.removeAll(keepingCapacity: true)
    }

    static func run(_ action: EffectAction, _ context: QueuedAction, _ combat: inout CombatState,
                    _ player: inout PlayerState) {
        switch action {
        case .nova(let spec):
            let center = anchorPoint(spec.anchor, context, &combat, player)
            let radius = CGFloat(spec.radius.value * combat.sheet[.areaSize])
            combat.events.append(.burst(position: center, radius: radius, visual: spec.visual))
            affect(around: center, radius: radius, damage: spec.damage, status: spec.status, depth: context.depth,
                   source: source(of: context), &combat)
        case .cone(let spec):
            cone(spec, context, &combat, player)
        case .chain(let spec):
            chain(spec, context, &combat, player)
        case .volley(let spec):
            volley(spec, context, &combat, player)
        case .strikes(let spec):
            strikes(spec, context, &combat, player)
        case .zone(let spec):
            place(spec, context, &combat, player, isAura: false)
        case .summon(let spec):
            summon(spec, context, &combat, player)
        case .buff(let spec):
            player.applyBuff(id: spec.id, modifiers: spec.modifiers.map { $0.at(1) },
                             duration: spec.duration.value * combat.sheet[.effectDuration], maxStacks: spec.maxStacks)
        case .barrier(let fraction):
            let amount = fraction.value * player.maxHealth
            player.barrier = min(player.maxHealth, player.barrier + amount)
            combat.events.append(.barrierGained)
        case .heal(let fraction):
            let amount = fraction.value * player.maxHealth
            combat.pendingHealing += amount
            if amount >= 1 {
                combat.events.append(.playerHealed(amount: amount * combat.sheet[.healingReceived]))
            }
        case .selfDamage(let fraction):
            player.health = max(1, player.health - player.health * fraction.value)
        case .invulnerable(let seconds):
            player.invulnerability = max(player.invulnerability, seconds.value)
        case .dash(let spec):
            dash(spec, context, &combat, &player)
        case .stealth(let seconds):
            player.stealth = max(player.stealth, seconds.value * combat.sheet[.effectDuration])
            combat.playerStealthed = true
            combat.events.append(.stealthStarted)
        case .transform(let form):
            player.form = player.form == form ? nil : form
            combat.events.append(.formChanged(player.form))
            if player.form != nil {
                combat.fireProcs(combat.build.transformProcs, origin: player.position, depth: context.depth)
            }
        case let .afflict(status, radius):
            if radius.value <= 0 {
                if let id = context.targetID, let index = combat.index(ofEnemy: id) {
                    combat.applyStatus(status, to: index)
                }
            } else {
                let center = context.depth == 0 ? player.position : context.origin
                let scaled = CGFloat(radius.value * combat.sheet[.areaSize])
                combat.events.append(.burst(position: center, radius: scaled, visual: action.visual))
                affect(around: center, radius: scaled, damage: nil, status: status, depth: context.depth,
                       source: source(of: context), &combat)
            }
        case let .pull(radius, strength):
            let center = context.depth == 0 ? player.position : context.origin
            pull(around: center, radius: CGFloat(radius.value * combat.sheet[.areaSize]), strength: strength, &combat)
        case .reduceCooldowns(let seconds):
            for (id, remaining) in combat.abilityCooldowns {
                combat.abilityCooldowns[id] = max(0, remaining - seconds.value)
            }
        case .random(let actions):
            guard !actions.isEmpty else { return }
            let pick = min(actions.count - 1, Int(combat.random.unit() * Double(actions.count)))
            run(actions[pick], context, &combat, &player)
        case .all(let actions):
            for next in actions {
                run(next, context, &combat, &player)
            }
        }
    }

    private static func source(of context: QueuedAction) -> HitSource {
        context.depth == 0 ? .ability : .proc
    }

    // MARK: - Placement

    static func anchorPoint(_ anchor: ActionAnchor, _ context: QueuedAction, _ combat: inout CombatState,
                            _ player: PlayerState) -> CGPoint {
        switch anchor {
        case .player:
            return player.position
        case .origin:
            return context.origin
        case .cluster:
            if let index = Targeting.densestCluster(around: player.position, within: 8, clusterRadius: 1.8,
                                                    padding: combat.largestEnemyRadius, combat: &combat) {
                return combat.enemies.positions[index]
            }
            return combat.world.wrap(player.position + player.facing.normalized * 3)
        }
    }

    /// Direction toward the nearest enemy, or `fallback`.
    static func aim(from origin: CGPoint, within range: CGFloat, fallback: CGPoint,
                    _ combat: inout CombatState) -> CGPoint {
        if let target = Targeting.nearest(to: origin, within: range, padding: combat.largestEnemyRadius,
                                          combat: &combat) {
            let direction = combat.world.delta(from: origin, to: combat.enemies.positions[target]).normalized
            if direction != .zero {
                return direction
            }
        }
        let normalized = fallback.normalized
        return normalized == .zero ? CGPoint(x: 1, y: 0) : normalized
    }

    // MARK: - Area

    /// Damages and/or afflicts every enemy within `radius` of `center`.
    static func affect(around center: CGPoint, radius: CGFloat, damage: DamageSpec?, status: StatusApplication?,
                       depth: Int, source: HitSource, _ combat: inout CombatState) {
        guard damage != nil || status != nil else { return }
        combat.nearbySecondary.removeAll(keepingCapacity: true)
        combat.grid.query(around: center, radius: radius + combat.largestEnemyRadius, into: &combat.nearbySecondary)
        let candidates = combat.nearbySecondary
        for index in candidates where index < combat.enemies.count && combat.enemies.health[index] > 0 {
            let offset = combat.world.delta(from: center, to: combat.enemies.positions[index])
            let distance = offset.length
            guard distance <= radius + combat.enemies.definition(at: index).radius else { continue }
            let direction = distance > 0.0001 ? offset / distance : CGPoint(x: 1, y: 0)
            if let damage {
                var hit = combat.hit(from: damage, direction: direction, depth: depth, source: source)
                hit.status = status
                combat.strike(index, with: hit)
            } else if let status {
                combat.applyStatus(status, to: index)
            }
        }
    }

    static func pull(around center: CGPoint, radius: CGFloat, strength: CGFloat, _ combat: inout CombatState) {
        combat.nearbySecondary.removeAll(keepingCapacity: true)
        combat.grid.query(around: center, radius: radius + combat.largestEnemyRadius, into: &combat.nearbySecondary)
        let candidates = combat.nearbySecondary
        for index in candidates where index < combat.enemies.count {
            let offset = combat.world.delta(from: combat.enemies.positions[index], to: center)
            let distance = offset.length
            guard distance <= radius, distance > 0.2 else { continue }
            let resistance = combat.enemies.definition(at: index).knockbackResistance
            combat.enemies.knockback[index] = combat.enemies.knockback[index]
                + offset / distance * strength * max(0.2, 1 - resistance)
        }
    }

    private static func cone(_ spec: ConeSpec, _ context: QueuedAction, _ combat: inout CombatState,
                             _ player: PlayerState) {
        let origin = player.position
        let range = CGFloat(spec.range.value * combat.sheet[.areaSize])
        let fallback = context.direction == .zero ? player.facing : context.direction
        let direction = aim(from: origin, within: range + 2, fallback: fallback, &combat)
        combat.events.append(.cone(origin: origin, direction: direction, range: range, arcDegrees: spec.arcDegrees,
                                   visual: spec.visual))

        let halfArcCosine = CGFloat(cos(spec.arcDegrees * .pi / 360))
        combat.nearbySecondary.removeAll(keepingCapacity: true)
        combat.grid.query(around: origin, radius: range + combat.largestEnemyRadius, into: &combat.nearbySecondary)
        let candidates = combat.nearbySecondary
        for index in candidates where index < combat.enemies.count && combat.enemies.health[index] > 0 {
            let offset = combat.world.delta(from: origin, to: combat.enemies.positions[index])
            let distance = offset.length
            guard distance <= range + combat.enemies.definition(at: index).radius else { continue }
            let inArc = distance < 0.6 || (distance > 0.0001 && (offset / distance).dot(direction) >= halfArcCosine)
            guard inArc else { continue }
            let push = distance > 0.0001 ? offset / distance : direction
            var hit = combat.hit(from: spec.damage, direction: push, depth: context.depth, source: source(of: context))
            hit.status = spec.status
            combat.strike(index, with: hit)
        }
    }

    private static func chain(_ spec: ChainSpec, _ context: QueuedAction, _ combat: inout CombatState,
                              _ player: PlayerState) {
        let jumps = max(1, Int((spec.jumps.value + combat.sheet[.chainJumps]).rounded()))
        var visited: [Int] = []
        if let target = context.targetID {
            // A chain set off by a hit leaps onward from that enemy.
            visited.append(target)
        }
        var current = context.depth == 0 ? player.position : context.origin
        var points = [current]
        for jump in 0..<jumps {
            let reach = jump == 0 && context.targetID == nil ? max(spec.range, 6.5) : spec.range
            guard let next = nearest(to: current, within: reach, excluding: visited, &combat) else { break }
            let position = combat.enemies.positions[next]
            let direction = combat.world.delta(from: current, to: position).normalized
            var hit = combat.hit(from: spec.damage, direction: direction, depth: context.depth, source: source(of: context))
            hit.status = spec.status
            hit.knockback = min(hit.knockback, 0.25)
            visited.append(combat.enemies.ids[next])
            combat.strike(next, with: hit)
            // Points are kept continuous across the wrap seam for drawing.
            let previous = points[points.count - 1]
            points.append(previous + combat.world.delta(from: current, to: position))
            current = position
        }
        if points.count > 1 {
            combat.events.append(.chain(points: points, visual: spec.visual))
        }
    }

    private static func nearest(to point: CGPoint, within range: CGFloat, excluding: [Int],
                                _ combat: inout CombatState) -> Int? {
        combat.nearby.removeAll(keepingCapacity: true)
        combat.grid.query(around: point, radius: range + combat.largestEnemyRadius, into: &combat.nearby)
        var best: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for index in combat.nearby where index < combat.enemies.count && combat.enemies.health[index] > 0 {
            guard !excluding.contains(combat.enemies.ids[index]) else { continue }
            let distance = combat.world.distance(point, combat.enemies.positions[index])
            if distance <= range, distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    // MARK: - Projectiles and impacts

    private static func volley(_ spec: VolleySpec, _ context: QueuedAction, _ combat: inout CombatState,
                               _ player: PlayerState) {
        let origin = spec.anchor == .origin ? context.origin : player.position
        let count = max(1, Int(spec.count.value.rounded()) + Int(combat.sheet[.projectileCount]))
        let speed = spec.speed * CGFloat(combat.sheet[.projectileSpeed])
        let pierce = spec.pierce + Int(combat.sheet[.pierce])
        let splash = spec.splash * CGFloat(combat.sheet[.areaSize])
        let life = Double(spec.range / max(spec.speed, 0.01)) * 1.1

        var template = combat.hit(from: spec.damage, direction: .zero, depth: context.depth, source: source(of: context))
        template.status = spec.status

        let baseAngle: Double
        let step: Double
        switch spec.pattern {
        case .radial:
            baseAngle = combat.random.range(0, 2 * .pi)
            step = 2 * .pi / Double(count)
        case .aimed(let spreadDegrees):
            let fallback = context.direction == .zero ? player.facing : context.direction
            let direction = aim(from: origin, within: spec.range, fallback: fallback, &combat)
            let spread = max(spreadDegrees, count > 1 ? 8 * Double(count - 1) : 0) * .pi / 180
            step = count > 1 ? spread / Double(count - 1) : 0
            baseAngle = atan2(Double(direction.y), Double(direction.x)) - spread / 2
        }

        for shot in 0..<count {
            let angle = baseAngle + step * Double(shot)
            let heading = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
            combat.projectiles.append(Projectile(
                id: combat.makeEntityID(),
                position: combat.world.wrap(origin + heading * 0.35),
                velocity: heading * speed,
                remainingLife: life,
                pierceRemaining: pierce,
                hit: template,
                radius: spec.size,
                splashRadius: splash,
                spriteID: spec.sprite,
                visual: spec.visual
            ))
        }
        let firstAngle = baseAngle
        combat.events.append(.projectileFired(spriteID: spec.sprite, origin: origin,
                                              direction: CGPoint(x: CGFloat(cos(firstAngle)), y: CGFloat(sin(firstAngle)))))
    }

    private static func strikes(_ spec: StrikeSpec, _ context: QueuedAction, _ combat: inout CombatState,
                                _ player: PlayerState) {
        let anchor = anchorPoint(spec.anchor, context, &combat, player)
        let count = max(1, Int(spec.count.value.rounded()))
        let radius = CGFloat(spec.radius.value * combat.sheet[.areaSize])

        var targets: [Int] = []
        if spec.seeksEnemies, spec.scatter > 0 {
            combat.nearby.removeAll(keepingCapacity: true)
            combat.grid.query(around: anchor, radius: spec.scatter, into: &combat.nearby)
            for index in combat.nearby where index < combat.enemies.count && combat.enemies.health[index] > 0 {
                if combat.world.distance(anchor, combat.enemies.positions[index]) <= spec.scatter {
                    targets.append(index)
                }
            }
        }

        let stagger = count > 1 ? min(0.06, 0.8 / Double(count)) : 0
        for number in 0..<count {
            let position: CGPoint
            if !targets.isEmpty, number < targets.count * 2 {
                let pick = targets[min(targets.count - 1, Int(combat.random.unit() * Double(targets.count)))]
                position = combat.randomPoint(around: combat.enemies.positions[pick], within: 0.3)
            } else if spec.scatter > 0 {
                position = combat.randomPoint(around: anchor, within: spec.scatter)
            } else {
                position = anchor
            }
            let delay = spec.delay + stagger * Double(number)
            combat.strikes.append(PendingStrike(position: position, remaining: delay, radius: radius, damage: spec.damage,
                                                status: spec.status, visual: spec.visual, depth: context.depth))
            combat.events.append(.strikeIncoming(position: position, radius: radius, delay: delay, visual: spec.visual))
        }
    }

    // MARK: - Zones and allies

    /// Places a zone. Auras from passives pass `isAura`.
    static func place(_ spec: ZoneSpec, _ context: QueuedAction, _ combat: inout CombatState, _ player: PlayerState,
                      isAura: Bool) {
        let position = spec.follows ? player.position : anchorPoint(spec.anchor, context, &combat, player)
        let duration = spec.duration.value <= 0 ? Double.infinity : spec.duration.value * combat.sheet[.effectDuration]
        combat.zones.append(Zone(id: combat.makeEntityID(), spec: spec, position: position, remaining: duration,
                                 tickTimer: isAura ? spec.tick : 0.05, isAura: isAura, depth: context.depth,
                                 radius: CGFloat(spec.radius.value * combat.sheet[.areaSize])))
    }

    private static func summon(_ spec: SummonSpec, _ context: QueuedAction, _ combat: inout CombatState,
                               _ player: PlayerState) {
        let count = max(1, Int(spec.count.value) + Int(combat.sheet[.summonCount]))
        let duration = spec.duration.value <= 0 ? 8 : spec.duration.value * combat.sheet[.effectDuration]
        // Raised from a corpse where there is one.
        let center = context.depth > 0 && context.targetID != nil ? context.origin : player.position
        for slot in 0..<count {
            AllySystem.spawn(spec, around: center, duration: duration, companionKey: nil, slot: slot, of: count,
                             &combat)
        }
        AllySystem.trimTemporaryAllies(&combat)
        combat.events.append(.summoned(position: center, visual: spec.visual))
    }

    // MARK: - Movement

    private static func dash(_ spec: DashSpec, _ context: QueuedAction, _ combat: inout CombatState,
                             _ player: inout PlayerState) {
        var direction = player.velocity.lengthSquared > 0.05 ? player.velocity.normalized : player.facing.normalized
        if direction == .zero {
            direction = CGPoint(x: 1, y: 0)
        }
        let distance = CGFloat(spec.distance.value)
        let from = player.position

        if spec.damage != nil || spec.status != nil {
            var struck: [Int] = []
            let samples = max(2, Int(distance / 0.8) + 1)
            for sample in 0...samples {
                let point = combat.world.wrap(from + direction * (distance * CGFloat(sample) / CGFloat(samples)))
                combat.nearbySecondary.removeAll(keepingCapacity: true)
                combat.grid.query(around: point, radius: 1 + combat.largestEnemyRadius, into: &combat.nearbySecondary)
                let candidates = combat.nearbySecondary
                for index in candidates where index < combat.enemies.count && combat.enemies.health[index] > 0 {
                    let id = combat.enemies.ids[index]
                    guard !struck.contains(id) else { continue }
                    let reach = 0.9 + combat.enemies.definition(at: index).radius
                    guard combat.world.distance(point, combat.enemies.positions[index]) <= reach else { continue }
                    struck.append(id)
                    if let damage = spec.damage {
                        var hit = combat.hit(from: damage, direction: direction, depth: context.depth,
                                             source: source(of: context))
                        hit.status = spec.status
                        combat.strike(index, with: hit)
                    } else if let status = spec.status {
                        combat.applyStatus(status, to: index)
                    }
                }
            }
        }

        player.position = combat.world.wrap(from + direction * distance)
        player.facing = direction
        player.invulnerability = max(player.invulnerability, spec.invulnerability)
        combat.playerPosition = player.position
        combat.events.append(.dash(from: from, to: from + direction * distance, visual: spec.visual))
    }
}
