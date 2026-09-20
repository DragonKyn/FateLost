import CoreGraphics
import Foundation

/// The damage pipeline: every hit in the game, from any source, resolves
/// here. Stats, target weaknesses, criticals, knockback, life steal,
/// statuses and triggers are all applied in one place, in one order.
extension CombatState {
    /// A hit from content damage at the current level.
    func hit(from spec: DamageSpec, direction: CGPoint, depth: Int, source: HitSource) -> Hit {
        Hit(amount: spec.power.value * skillPower, type: spec.type, tags: spec.tags, direction: direction,
            knockback: spec.knockback, critBonus: spec.critBonus, depth: depth, source: source)
    }

    /// Applies a hit to a living enemy.
    ///
    /// - Returns: false if the enemy was already dead.
    @discardableResult
    mutating func strike(_ index: Int, with hit: Hit) -> Bool {
        guard index < enemies.count, enemies.health[index] > 0 else { return false }
        let sheet = self.sheet
        let isDot = hit.isDamageOverTime

        // Damage over time had the player's multipliers applied when the
        // status was inflicted.
        var amount = isDot ? hit.amount : hit.amount * sheet.damageMultiplier(for: hit.type, tags: hit.tags)
        if !hit.added.isEmpty {
            let base = hit.amount
            let tags = hit.tags
            var extra = 0.0
            hit.added.forEach { type, fraction in
                extra += base * fraction * sheet.damageMultiplier(for: type, tags: tags)
            }
            amount += extra
        }

        var bonus = 0.0
        var critChance = tuning.critChance + sheet[.critChance] + hit.critBonus
        var critMultiplier = tuning.critMultiplier + sheet[.critDamage]
        if !isDot {
            for rule in build.hitBonuses where matches(rule.condition, index) {
                switch rule.kind {
                case .damage: bonus += rule.value
                case .critChance: critChance += rule.value
                case .critDamage: critMultiplier += rule.value
                }
            }
            if playerStealthed {
                critChance += 1
            }
        }
        if enemies.statusMask[index] != 0 {
            bonus += enemies.potency(.shock, at: index) + enemies.potency(.curse, at: index)
            critChance += enemies.potency(.mark, at: index)
        }
        amount *= max(0, 1 + bonus)

        var isCritical = false
        if !isDot {
            let variance = tuning.damageVariance
            amount *= random.range(1 - variance, 1 + variance)
            if hit.canCrit, random.chance(critChance) {
                isCritical = true
                amount *= critMultiplier
            }
        }

        let dealt = min(amount, enemies.health[index])
        enemies.health[index] -= amount
        // A sapper's keg felling its own kin is not the hero's doing.
        if hit.source != .environment {
            stats.damageDealt += dealt
            stats.highestHit = max(stats.highestHit, amount)
        }
        if isCritical {
            stats.criticalHits += 1
        }
        enemies.lastHitType[index] = hit.type.index
        enemies.lastHitDepth[index] = UInt8(min(max(hit.depth, 0), 255))

        if hit.knockback > 0 {
            let resistance = enemies.definition(at: index).knockbackResistance
            let push = tuning.weaponKnockbackSpeed * hit.knockback * CGFloat(sheet[.knockback]) * max(0, 1 - resistance)
            enemies.knockback[index] = enemies.knockback[index] + hit.direction * push
        }

        if !isDot {
            let steal = hit.source == .summon ? sheet[.summonLifeSteal] : sheet[.lifeSteal]
            if steal > 0 {
                pendingHealing += dealt * steal
            }
        }

        let position = enemies.positions[index]
        events.append(.enemyHit(enemyID: enemies.ids[index], position: position, amount: amount,
                                isCritical: isCritical, direction: hit.direction, type: hit.type, isDot: isDot))
        guard !isDot else { return true }

        if let status = hit.status {
            applyStatus(status, to: index)
        }
        if hit.depth == 0 || hit.source == .summon {
            for infliction in build.inflictions where Self.filter(infliction.filter, accepts: hit) {
                applyStatus(infliction.status, to: index)
            }
        }
        if hit.depth == 0 {
            for procIndex in build.hitProcs {
                guard case let .hit(tags, type) = build.procs[procIndex].trigger else { continue }
                guard Self.filter(HitFilter(tags: tags, type: type), accepts: hit) else { continue }
                fireProc(procIndex, origin: position, targetIndex: index, depth: hit.depth, direction: hit.direction)
            }
            if isCritical {
                for procIndex in build.criticalProcs {
                    fireProc(procIndex, origin: position, targetIndex: index, depth: hit.depth,
                             direction: hit.direction)
                }
            }
        }
        return true
    }

    static func filter(_ filter: HitFilter, accepts hit: Hit) -> Bool {
        guard hit.tags.isSuperset(of: filter.tags) else { return false }
        if let type = filter.type, hit.typeMask & type.bit == 0 {
            return false
        }
        return true
    }

    // MARK: - Statuses

    /// Tries to inflict a status, rolling its chance.
    mutating func applyStatus(_ application: StatusApplication, to index: Int, rollChance: Bool = true) {
        guard index < enemies.count, enemies.health[index] > 0 else { return }
        if rollChance {
            let chance = application.chance.value * sheet[.statusChance]
            if chance < 1, !random.chance(chance) { return }
        }
        let kind = application.kind
        var duration = application.duration.value * sheet[.effectDuration]
        switch kind {
        case .freeze, .stun, .root, .fear, .confuse:
            // Big enemies shake off control faster.
            duration *= 1 - 0.5 * Double(enemies.definition(at: index).knockbackResistance)
        default:
            break
        }
        guard duration > 0 else { return }

        let slot = kind.rawValue
        var potency = application.potency.value
        if kind.isDamageOverTime {
            potency *= skillPower * sheet.damageMultiplier(for: kind.damageType, tags: .dot)
        }
        let active = enemies.hasStatus(kind, at: index)
        let current = active ? Double(enemies.statusPotency[slot][index]) : 0
        let combined: Double
        switch kind {
        case .poison:
            // Poison stacks, up to five applications' worth.
            combined = max(current, min(current + potency, potency * 5))
        case .chill:
            combined = min(0.7, max(current, potency))
        default:
            combined = max(current, potency)
        }
        enemies.statusPotency[slot][index] = Float(combined)
        let remaining = active ? enemies.statusTime[slot][index] : 0
        enemies.statusTime[slot][index] = max(remaining, Float(duration))
        enemies.statusMask[index] |= kind.bit

        switch kind {
        case .freeze, .stun, .fear, .confuse:
            // Losing control interrupts a strike in progress.
            enemies.windup[index] = 0
        default:
            break
        }
    }

    /// Whether an enemy matches a condition.
    func matches(_ condition: TargetCondition, _ index: Int) -> Bool {
        switch condition {
        case .status(let kind):
            return enemies.hasStatus(kind, at: index)
        case .afflicted:
            return enemies.statusMask[index] != 0
        case .elementalStatuses(let required):
            var count = 0
            for kind in StatusKind.elemental where enemies.hasStatus(kind, at: index) {
                count += 1
            }
            return count >= required
        case .healthBelow(let fraction):
            return enemies.health[index] < enemies.maxHealth[index] * fraction
        case .healthAbove(let fraction):
            return enemies.health[index] > enemies.maxHealth[index] * fraction
        case .facingAway:
            // Turned away, distracted or unable to act.
            let distracted = StatusKind.incapacitating | StatusKind.fear.bit | StatusKind.confuse.bit
            if enemies.statusMask[index] & distracted != 0 { return true }
            let toPlayer = world.delta(from: enemies.positions[index], to: playerPosition).normalized
            return enemies.heading[index].dot(toPlayer) < 0.3
        case .within(let distance):
            return world.distance(playerPosition, enemies.positions[index]) <= distance
        case .beyond(let distance):
            return world.distance(playerPosition, enemies.positions[index]) > distance
        }
    }

    // MARK: - Triggers

    /// Rolls one proc and queues its action if it fires.
    mutating func fireProc(_ procIndex: Int, origin: CGPoint, targetIndex: Int?, depth: Int,
                           direction: CGPoint = .zero) {
        guard procIndex < procCooldowns.count, procCooldowns[procIndex] <= 0 else { return }
        let rule = build.procs[procIndex]
        if let requires = rule.requires, !conditions.holds(requires) { return }
        if let target = rule.target {
            guard let targetIndex, targetIndex < enemies.count, matches(target, targetIndex) else { return }
        }
        if rule.chance < 1, !random.chance(rule.chance) { return }
        procCooldowns[procIndex] = rule.cooldown
        var targetID: Int?
        if let targetIndex, targetIndex < enemies.count {
            targetID = enemies.ids[targetIndex]
        }
        pendingActions.append(QueuedAction(action: rule.action, origin: origin, targetID: targetID,
                                           direction: direction, depth: depth + 1, ability: nil))
    }

    /// Fires every proc in a group that has no enemy involved.
    mutating func fireProcs(_ indices: [Int], origin: CGPoint, depth: Int = 0) {
        for procIndex in indices {
            fireProc(procIndex, origin: origin, targetIndex: nil, depth: depth)
        }
    }

    /// Everything between an enemy's blow and the player's health: immunity,
    /// dodging, armour, barriers, a refused death, and the triggers that
    /// answer being struck.
    mutating func strikePlayer(_ player: inout PlayerState, amount rawAmount: Double,
                               direction: CGPoint, godMode: Bool) {
        guard !player.isInvulnerable else { return }
        if random.chance(sheet[.dodgeChance]) {
            player.timeSinceDodge = 0
            stats.dodges += 1
            events.append(.playerDodged)
            fireProcs(build.dodgeProcs, origin: player.position)
            return
        }

        let armor = max(0, sheet[.armor])
        let reduction = min(0.8, armor / (armor + 75))
        var amount = godMode ? 0 : rawAmount * (1 - reduction)

        if player.barrier > 0 {
            let absorbed = min(player.barrier, amount)
            player.barrier -= absorbed
            amount -= absorbed
        }

        if amount >= player.health, let refusal = build.cheatDeath, cheatDeathCooldown <= 0 {
            cheatDeathCooldown = refusal.cooldown
            player.health = max(1, player.maxHealth * refusal.restore)
            player.invulnerability = refusal.invulnerability
            events.append(.cheatedDeath)
            if let action = refusal.action {
                pendingActions.append(QueuedAction(action: action, origin: player.position, targetID: nil,
                                                          direction: direction, depth: 1, ability: nil))
            }
            return
        }

        let dealt = min(amount, player.health)
        player.health -= dealt
        player.invulnerability = tuning.invulnerabilityDuration
        player.timeSinceHit = 0
        // `direction` points at the player, so the shove carries on the same way.
        player.knockback = player.knockback + direction * tuning.playerKnockbackSpeed
        stats.damageTaken += dealt
        events.append(.playerHit(amount: rawAmount, direction: direction))
        conditions.healthFraction = player.healthFraction
        fireProcs(build.hurtProcs, origin: player.position)
        if player.isDefeated {
            events.append(.playerDefeated)
        }
    }

    // MARK: - Death

    /// Removes every enemy whose health has run out: reports the kills,
    /// drops their experience and fires death triggers.
    ///
    /// - Returns: whether anything was removed.
    @discardableResult
    mutating func removeDefeatedEnemies() -> Bool {
        var removedAny = false
        var index = enemies.count - 1
        while index >= 0 {
            if enemies.health[index] <= 0 {
                let position = enemies.positions[index]
                let definition = enemies.definition(at: index)
                let direction = enemies.knockback[index].lengthSquared > 0.0001
                    ? enemies.knockback[index].normalized
                    : enemies.heading[index] * -1
                events.append(.enemyKilled(enemyID: enemies.ids[index], kind: definition.id, position: position,
                                           direction: direction))
                stats.kills += 1
                killsThisStep += 1
                if definition.rank >= .elite {
                    stats.eliteKills += 1
                }
                if definition.isBoss {
                    stats.bossKills += 1
                }
                dropExperience(definition.experienceValue + enemies.strain(at: index).experienceBonus,
                               at: position)
                dropLoot(for: definition, at: position)

                let depth = Int(enemies.lastHitDepth[index])
                if depth < 2 {
                    let killedBy = DamageType(index: enemies.lastHitType[index])
                    for procIndex in build.killProcs {
                        if case .kill(let required?) = build.procs[procIndex].trigger, required != killedBy {
                            continue
                        }
                        fireProc(procIndex, origin: position, targetIndex: index, depth: depth)
                    }
                }
                enemies.remove(at: index)
                removedAny = true
            }
            index -= 1
        }
        return removedAny
    }

    /// Leaves experience where an enemy fell, merging into nearby orbs once
    /// the ground is crowded so a huge fight stays cheap to draw.
    mutating func dropExperience(_ value: Int, at position: CGPoint) {
        guard value > 0 else { return }
        if orbs.count >= 320 {
            var best = 0
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for index in orbs.indices where !orbs[index].attracted {
                let distance = world.distanceSquared(orbs[index].position, position)
                if distance < bestDistance {
                    bestDistance = distance
                    best = index
                }
            }
            orbs[best].value += value
            return
        }
        orbs.append(ExperienceOrb(id: makeEntityID(), position: position, value: value))
    }
}
