import CoreGraphics
import Foundation

/// What one rare elite on the field is up to, by enemy id.
///
/// An elite still fights as its family does (`EnemyAISystem` handles that);
/// this only tracks the move on top, the same way `BossBrain` sits beside a
/// champion's ordinary attack.
struct EliteBrain: Equatable {
    /// A shieldbreaker starts shielded and turns once its barrier gives out.
    var berserker = false
    /// Seconds until the next special move may begin.
    var cooldown: Double = 0
}

/// Runs the rare elites' own moves: a shieldbreaker's hook once its shield
/// breaks, and an explosive's thrown bombs. Called every step, whether or not
/// one is on the field.
enum EliteSystem {
    static func step(_ combat: inout CombatState, targets: [AITarget], dt: TimeInterval) {
        guard !combat.enemies.isEmpty else { return }
        for index in 0..<combat.enemies.count {
            guard combat.enemies.health[index] > 0 else { continue }
            let definition = combat.enemies.definition(at: index)
            guard let kit = definition.eliteKit else { continue }
            let id = combat.enemies.ids[index]
            var brain = combat.eliteBrains[id] ?? EliteBrain()
            brain.cooldown = max(0, brain.cooldown - dt)

            switch kit {
            case .shieldbreaker(let sb):
                stepShieldbreaker(sb, index: index, id: id, brain: &brain, targets: targets, combat: &combat)
            case .explosive(let ex):
                stepExplosive(ex, index: index, targets: targets, brain: &brain, combat: &combat)
            }
            combat.eliteBrains[id] = brain
        }
        // An elite that has left the field has nothing more to track.
        if !combat.eliteBrains.isEmpty {
            let living = Set(combat.enemies.ids)
            combat.eliteBrains = combat.eliteBrains.filter { living.contains($0.key) }
        }
    }

    // MARK: Shieldbreaker

    private static func stepShieldbreaker(_ kit: ShieldbreakerKit, index: Int, id: Int, brain: inout EliteBrain,
                                          targets: [AITarget], combat: inout CombatState) {
        if !brain.berserker, combat.enemies.barrier[index] <= 0 {
            brain.berserker = true
            combat.enemies.speedScale[index] *= kit.berserkerSpeedMultiplier
            combat.enemies.damageScale[index] *= kit.berserkerDamageMultiplier
            combat.events.append(.shieldBroke(enemyID: id, position: combat.enemies.positions[index]))
            // Straight into the fight it now is: no hook the instant it turns.
            brain.cooldown = max(brain.cooldown, kit.hookCooldown * 0.5)
        }
        guard brain.berserker, brain.cooldown <= 0 else { return }
        guard let target = nearest(to: combat.enemies.positions[index], in: targets, world: combat.world) else { return }
        let toTarget = combat.world.delta(from: combat.enemies.positions[index], to: target.position)
        let distance = toTarget.length
        guard distance > 0.5, distance <= kit.hookRange else { return }

        brain.cooldown = kit.hookCooldown
        let direction = toTarget / distance
        let origin = combat.world.wrap(combat.enemies.positions[index] + direction * combat.enemies.definition(at: index).radius)
        let travelSeconds = Double(kit.hookRange / kit.hookSpeed)
        combat.hostileProjectiles.append(Projectile(
            id: combat.makeEntityID(), position: origin, velocity: direction * kit.hookSpeed,
            remainingLife: travelSeconds + 0.2, pierceRemaining: 0,
            hit: Hit(amount: 0, type: .physical, tags: [.projectile], direction: direction, knockback: 0,
                     canCrit: false, depth: 1, source: .environment),
            radius: 0.32, splashRadius: 0, spriteID: .projectileHook, visual: .physical, isHostile: true,
            isGrapple: true, pullSeconds: kit.pullSeconds, stunSeconds: kit.stunSeconds))
    }

    // MARK: Explosive

    private static func stepExplosive(_ kit: ExplosiveKit, index: Int, targets: [AITarget], brain: inout EliteBrain,
                                      combat: inout CombatState) {
        guard brain.cooldown <= 0 else { return }
        guard let target = nearest(to: combat.enemies.positions[index], in: targets, world: combat.world) else { return }
        guard combat.world.distance(combat.enemies.positions[index], target.position) <= kit.bombRange else { return }

        brain.cooldown = kit.bombCooldown
        var bomb = Hazard(id: combat.makeEntityID(), shape: .circle, position: target.position, direction: .zero,
                          size: kit.bombRadius, width: 0, warning: kit.bombWindup, damage: kit.bombDamage,
                          type: .fire, visual: .fire)
        bomb.burnTickDamage = kit.burnTickDamage
        bomb.burnTicks = kit.burnTicks
        bomb.burnTickEvery = kit.burnTickEvery
        combat.hazards.append(bomb)
    }

    /// A death-fused bomb of its own: called once, when it falls.
    static func detonateOnDeath(_ kit: ExplosiveKit, at position: CGPoint, combat: inout CombatState) {
        var bomb = Hazard(id: combat.makeEntityID(), shape: .circle, position: position, direction: .zero,
                          size: kit.deathRadius, width: 0, warning: kit.deathFuseSeconds,
                          damage: kit.deathDamage, type: .fire, visual: .fire)
        bomb.burnTickDamage = kit.burnTickDamage
        bomb.burnTicks = kit.burnTicks
        bomb.burnTickEvery = kit.burnTickEvery
        combat.hazards.append(bomb)
    }

    private static func nearest(to position: CGPoint, in targets: [AITarget], world: ToroidalWorld) -> AITarget? {
        var best: AITarget?
        var bestSquared = CGFloat.greatestFiniteMagnitude
        for target in targets where target.isAlive && !target.isHidden {
            let squared = world.distanceSquared(position, target.position)
            if squared < bestSquared {
                bestSquared = squared
                best = target
            }
        }
        return best
    }
}
