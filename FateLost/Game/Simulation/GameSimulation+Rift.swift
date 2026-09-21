import CoreGraphics
import Foundation

/// Portals and the fights behind them (see `Rift.swift`). Host only: a guest
/// draws what the snapshots say and never runs any of this.
extension GameSimulation {
    var isInRift: Bool { mirror?.rift != nil || combat.rift != nil }

    /// The rift the party is in, for drawing.
    var activeRiftKind: RiftKind? { mirror?.rift ?? combat.rift?.kind }

    /// Every portal standing, for drawing.
    var allPortals: [Portal] { mirror?.portals ?? combat.portals }

    mutating func stepRifts(dt: TimeInterval) {
        guard mirror == nil else { return }
        if let spot = waves.takeFallenBossSpot() {
            maybeOpenPortal(at: spot)
        }
        stepPortals(dt)
        stepRiftFight(dt)
    }

    // MARK: Opening

    private mutating func maybeOpenPortal(at spot: CGPoint) {
        guard combat.rift == nil, combat.portals.isEmpty,
              combat.lootRandom.chance(tuning.simulation.riftChance) else { return }
        let kinds = RiftKind.allCases
        let kind = kinds[Int(combat.lootRandom.unit() * Double(kinds.count)) % kinds.count]
        openPortal(kind, at: spot)
    }

    /// Opens a way into a rift. (Also how the tests and the developer panel make one.)
    mutating func openPortal(_ kind: RiftKind, at spot: CGPoint) {
        combat.portals.append(Portal(id: combat.makeEntityID(), kind: kind, position: world.wrap(spot),
                                     isReturn: false))
        combat.events.append(.riftOpened(kind: kind, position: world.wrap(spot)))
    }

    // MARK: Stepping through

    private mutating func stepPortals(_ dt: TimeInterval) {
        guard !combat.portals.isEmpty else { return }
        for index in combat.portals.indices { combat.portals[index].age += dt }
        combat.portals.removeAll { !$0.isReturn && $0.age > RiftTuning.lifetime }
        guard let touched = combat.portals.first(where: { someoneIsAt($0.position) }) else { return }
        if touched.isReturn {
            leaveRift()
        } else if combat.rift == nil {
            enterRift(through: touched)
        }
    }

    private func someoneIsAt(_ point: CGPoint) -> Bool {
        (0..<heroCount).contains { hero in
            let state = playerState(of: hero)
            return !state.isDefeated && !members[hero].isGone
                && world.distance(state.position, point) <= RiftTuning.touchDistance
        }
    }

    private var standingHeroes: [Int] {
        (0..<heroCount).filter { !members[$0].isGone }
    }

    /// Puts a hero at `point`, with their summons, and a few moments of immunity.
    private mutating func place(_ hero: Int, at point: CGPoint) {
        perform(as: hero) { sim in
            sim.player.position = point
            sim.player.velocity = .zero
            sim.player.knockback = .zero
            sim.player.invulnerability = max(sim.player.invulnerability, RiftTuning.immunity)
            sim.combat.projectiles.removeAll()
            sim.combat.strikes.removeAll()
            for index in sim.combat.allies.indices {
                sim.combat.allies[index].position = sim.world.wrap(point + CGPoint(x: CGFloat(index % 3) - 1, y: 0.8))
            }
            sim.syncPlayerSnapshot()
        }
    }

    private mutating func clearTheField() {
        combat.enemies.removeAll()
        combat.hostileProjectiles.removeAll()
        combat.hazards.removeAll()
        combat.bossBrains.removeAll()
        combat.grid.removeAll()
    }

    private mutating func enterRift(through portal: Portal) {
        var origins: [Int: CGPoint] = [:]
        for hero in standingHeroes { origins[hero] = playerState(of: hero).position }

        // The rift raises the fallen, so nobody misses the fight.
        for hero in standingHeroes where playerState(of: hero).isDefeated {
            combat.reviveMarkers.removeAll { $0.hero == hero }
            revive(hero, at: origins[hero] ?? portal.position)
        }

        // The far side of the map from where the portal stood: nothing else is there.
        let centre = world.wrap(portal.position + CGPoint(x: world.width / 2, y: world.height / 2))
        clearTheField()
        let heroes = standingHeroes
        for (slot, hero) in heroes.enumerated() {
            let angle = 2 * Double.pi * Double(slot) / Double(max(1, heroes.count))
            place(hero, at: world.wrap(centre + CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle))) * 3))
        }
        combat.portals.removeAll()
        let title = portal.kind.name
        combat.rift = RiftFight(kind: portal.kind, timer: RiftTuning.arrivalSeconds, centre: centre, origins: origins,
                                lastBossPosition: centre, savedWave: waves.state)
        var display = WaveState()
        display.index = waves.state.index
        display.phase = .bossIncoming
        display.bossTitle = title
        waves.mirror(display)
        combat.events.append(.riftEntered(kind: portal.kind))
    }

    private mutating func leaveRift() {
        guard let rift = combat.rift, rift.stage == .won else { return }
        clearTheField()
        for hero in standingHeroes {
            place(hero, at: world.wrap(rift.origins[hero] ?? rift.lastBossPosition))
        }
        // What was left behind in the rift is gone with it.
        combat.orbs.removeAll { world.distance($0.position, rift.centre) < 40 }
        combat.portals.removeAll()
        waves.mirror(rift.savedWave)
        combat.rift = nil
    }

    // MARK: The fight

    private mutating func stepRiftFight(_ dt: TimeInterval) {
        guard var rift = combat.rift else { return }
        switch rift.stage {
        case .arriving:
            rift.timer -= dt
            if rift.timer <= 0, let definition = EnemyCatalog.definition(for: rift.kind.bossID) {
                let spot = world.wrap(rift.centre + CGPoint(x: 0, y: -RiftTuning.bossDistance))
                let kind = combat.enemies.kindIndex(for: definition)
                let id = combat.makeEntityID()
                combat.enemies.append(id: id, kind: kind, position: spot, speedScale: 1,
                                      healthScale: combat.enemyHealthScale)
                rift.bossID = id
                rift.lastBossPosition = spot
                rift.stage = .fighting
                combat.events.append(.bossArrived(title: bossTitle(definition)))
            }
            combat.rift = rift

        case .fighting:
            guard let id = rift.bossID, let index = combat.index(ofEnemy: id), combat.enemies.health[index] > 0 else {
                combat.rift = rift
                win(&rift)
                return
            }
            rift.lastBossPosition = combat.enemies.positions[index]
            combat.rift = rift
            var display = WaveState()
            display.index = waves.state.index
            display.phase = .bossFight
            display.bossID = id
            display.bossTitle = EnemyCatalog.definition(for: rift.kind.bossID).map(bossTitle) ?? rift.kind.name
            display.bossHealth = combat.enemies.health[index]
            display.bossMaxHealth = combat.enemies.maxHealth[index]
            waves.mirror(display)

        case .won:
            break
        }
    }

    private func bossTitle(_ definition: EnemyDefinition) -> String {
        definition.epithet.map { "\(definition.name), \($0)" } ?? definition.name
    }

    /// The great one has fallen: experience, a find for everyone, and a way home.
    private mutating func win(_ rift: inout RiftFight) {
        let spot = rift.lastBossPosition
        let title = EnemyCatalog.definition(for: rift.kind.bossID).map(bossTitle) ?? rift.kind.name
        clearTheField()
        combat.events.append(.bossDefeated(title: title))
        combat.dropExperience(max(1, Int((Double(progression.required) * RiftTuning.experienceMultiple).rounded())),
                              at: spot)
        for hero in standingHeroes {
            perform(as: hero) { $0.combat.pendingFinds.append(.rift) }
        }
        combat.portals.append(Portal(id: combat.makeEntityID(), kind: rift.kind, position: spot, isReturn: true))
        rift.stage = .won
        combat.rift = rift
        var display = WaveState()
        display.index = waves.state.index
        display.phase = .fighting
        waves.mirror(display)
    }
}
