import CoreGraphics
import Foundation

/// A simulation that is not running but *watching*: how a phone that is not
/// the host draws a party run.
///
/// The host owns the truth. A client keeps an ordinary `GameSimulation` that
/// it never steps, and fills it from what the host sends: the enemies, drops
/// and shrines land in the same stores the renderers already read, and the
/// local hero's own state (level, build, offers) is set from `HeroSelfState`.
/// Between snapshots the mirror moves things a little so they do not judder:
/// enemies ease toward where they last were, shots fly on in a straight line,
/// and the local hero walks under their own thumb (client-side prediction),
/// pulled back gently if the host disagrees.
struct MirrorWorld {
    /// A snapshot is a round trip old, so a hero walking at speed is always a
    /// little ahead of where it says they are. That is lag, not disagreement:
    /// only a gap the host has plainly caused (it is ignoring the guest's
    /// position, or moved the hero) is followed, and a big one snapped to.
    /// Pulling back on every gap slowed a guest to a crawl.
    static let followDistance: CGFloat = 2.2
    /// A gap this big is a dash, a recall or a revival: taken at once.
    static let snapDistance: CGFloat = 3.5
    /// A hero standing still has no lag to excuse a gap, so a small one is
    /// eased away (a share per snapshot) instead of being left.
    static let settleDistance: CGFloat = 0.2
    static let settleShare: CGFloat = 0.2
    /// The local player's seat.
    var mySlot: UInt8
    var zones: [Zone] = []
    var hazards: [Hazard] = []
    var allies: [Ally] = []
    var projectiles: [Projectile] = []
    var cooldowns: [AbilityID: HeroSelfState.Cooldown] = [:]
    /// Every hero as of the last snapshot, and the markers where heroes lie.
    var heroes: [NetHero] = []
    var markers: [NetMarker] = []
    var moveSpeed: Double = 1
    var hasSummons = false
    var allyCount = 0
    var receivedSnapshot = false
    /// Whether the local hero has been placed from a snapshot yet.
    var syncedHero = false

    fileprivate var enemyTargets: [Int: CGPoint] = [:]
    fileprivate var allyTargets: [Int: CGPoint] = [:]
    fileprivate var orbTargets: [Int: CGPoint] = [:]
    fileprivate var dropTargets: [Int: CGPoint] = [:]
    fileprivate var zoneAges: [Int: Double] = [:]

    init(mySlot: UInt8) {
        self.mySlot = mySlot
    }
}

extension GameSimulation {
    /// Puts a simulation into watching mode for the player in `slot`.
    mutating func beginMirroring(slot: UInt8) {
        mirror = MirrorWorld(mySlot: slot)
    }

    /// Whether a snapshot from the host has arrived yet.
    var hasMirroredState: Bool { mirror?.receivedSnapshot ?? false }

    // MARK: Snapshots

    /// Adopts what the host says the world looks like.
    mutating func applyMirror(_ snapshot: NetSnapshot) {
        guard var world = mirror else { return }
        elapsed = Double(snapshot.tickMilliseconds) / 1000
        world.receivedSnapshot = true

        // The wave clock.
        let phase: WaveState.Phase
        switch snapshot.wave.phase {
        case NetWave.bossIncoming: phase = .bossIncoming
        case NetWave.bossFight: phase = .bossFight
        case NetWave.conquered: phase = .conquered
        case NetWave.resting: phase = .resting
        case NetWave.clearing: phase = .clearing
        default: phase = .fighting
        }
        var wave = WaveState()
        wave.index = snapshot.wave.index
        wave.phase = phase
        wave.bossID = phase == .bossFight ? 1 : nil
        wave.bossTitle = snapshot.wave.bossTitle ?? ""
        wave.bossMaxHealth = 1
        wave.bossHealth = snapshot.wave.bossFraction
        wave.restRemaining = Double(snapshot.wave.restSeconds)
        wave.restVotes = snapshot.wave.restVotes
        wave.restVoters = snapshot.wave.restVoters
        waves.mirror(wave)
        combat.curseRemaining = Double(snapshot.wave.curseSeconds)

        // The horde. Rebuilt each time, but each enemy keeps where it was
        // drawn so it eases to its new place instead of jumping.
        var drawnAt: [Int: CGPoint] = [:]
        drawnAt.reserveCapacity(combat.enemies.count)
        for index in 0..<combat.enemies.count {
            drawnAt[combat.enemies.ids[index]] = combat.enemies.positions[index]
        }
        combat.enemies.removeAll()
        world.enemyTargets.removeAll(keepingCapacity: true)
        for enemy in snapshot.enemies {
            guard let definition = NetTables.enemyByHash[enemy.kind] else { continue }
            let id = Int(enemy.id)
            let kind = combat.enemies.kindIndex(for: definition)
            let strain = min(Int(enemy.strain), EnemyStrain.all.count - 1)
            var start = enemy.position
            if let previous = drawnAt[id], self.world.distance(previous, enemy.position) < 6 {
                start = previous
            }
            combat.enemies.append(id: id, kind: kind, position: start, speedScale: 1, healthScale: 1, strain: strain)
            let index = combat.enemies.count - 1
            combat.enemies.health[index] = combat.enemies.maxHealth[index] * max(0.001, enemy.healthFraction)
            combat.enemies.heading[index] = enemy.heading
            combat.enemies.statusMask[index] = enemy.statusMask
            combat.enemies.windup[index] = enemy.windupFraction * definition.attackWindup
            combat.enemies.aim[index] = enemy.windupFraction > 0 ? enemy.aim : .zero
            combat.enemies.dash[index] = enemy.isCharging ? enemy.heading : .zero
            combat.enemies.special[index] = enemy.isCharging ? 0.3 : 0
            world.enemyTargets[id] = enemy.position
        }

        // Shots, fields and summons of every hero.
        world.projectiles = snapshot.projectiles.compactMap { shot in
            guard let sprite = NetTables.sprite(shot.sprite) else { return nil }
            return Projectile(id: Int(shot.id), position: shot.position, velocity: shot.velocity, remainingLife: 3,
                              pierceRemaining: 0, hit: Hit(amount: 0, type: .physical, tags: []),
                              radius: CGFloat(shot.radius), splashRadius: 0, spriteID: sprite,
                              visual: NetTables.visual(shot.visual), isHostile: shot.isHostile)
        }
        var ages: [Int: Double] = [:]
        world.zones = snapshot.zones.map { zone in
            let id = Int(zone.id)
            let age = world.zoneAges[id] ?? 0.4
            ages[id] = age
            let spec = ZoneSpec(radius: RankValue(zone.radius), duration: RankValue(0), visual: NetTables.visual(zone.visual))
            return Zone(id: id, spec: spec, position: zone.position, remaining: zone.remaining ?? .infinity,
                        tickTimer: 0, isAura: zone.isAura, depth: 0, radius: CGFloat(zone.radius), age: age)
        }
        world.zoneAges = ages

        // Marked ground: its age comes from the host, and runs on here between snapshots.
        world.hazards = snapshot.hazards.compactMap { net in
            guard let shape = Hazard.Shape(rawValue: net.shape) else { return nil }
            return Hazard(id: Int(net.id), shape: shape, position: net.position, direction: net.direction,
                          size: CGFloat(net.size), width: CGFloat(net.width), warning: net.warning, age: net.age,
                          damage: 0, type: .physical, visual: NetTables.visual(net.visual),
                          hasLanded: net.age >= net.warning)
        }

        var previousAllies: [Int: CGPoint] = [:]
        for ally in world.allies { previousAllies[ally.id] = ally.position }
        world.allyTargets.removeAll(keepingCapacity: true)
        world.allies = snapshot.allies.compactMap { ally in
            guard let sprite = NetTables.sprite(ally.sprite) else { return nil }
            let id = Int(ally.id)
            var tint: RGBA?
            if let parts = ally.tint, parts.count == 3 {
                tint = RGBA(red: Double(parts[0]) / 255, green: Double(parts[1]) / 255, blue: Double(parts[2]) / 255)
            }
            let behavior: AllyBehavior
            switch ally.behavior {
            case NetAlly.orbit: behavior = .orbit(radius: 1.2, angularSpeed: 3)
            case NetAlly.ranged: behavior = .ranged(range: 6, projectileSpeed: 10, sprite: .projectileBolt)
            default: behavior = .melee(range: 0.8)
            }
            let spec = SummonSpec(key: "net", name: "", sprite: sprite, tint: tint, scale: CGFloat(ally.scale),
                                  behavior: behavior, damage: DamageSpec(RankValue(0), .physical),
                                  visual: NetTables.visual(ally.visual))
            var start = ally.position
            if let previous = previousAllies[id], self.world.distance(previous, ally.position) < 6 { start = previous }
            world.allyTargets[id] = ally.position
            var mirrored = Ally(id: id, spec: spec, position: start, remaining: .infinity, angle: 0,
                                heading: ally.heading, companionKey: nil, restAngle: 0)
            mirrored.timeSinceAttack = ally.attackedRecently ? 0 : 10
            if let fraction = ally.healthFraction {
                mirrored.maxHealth = 100
                mirrored.health = 100 * fraction
            }
            return mirrored
        }

        // What lies on the ground.
        var orbsDrawn: [Int: CGPoint] = [:]
        for orb in combat.orbs { orbsDrawn[orb.id] = orb.position }
        world.orbTargets.removeAll(keepingCapacity: true)
        combat.orbs = snapshot.orbs.map { orb in
            let id = Int(orb.id)
            world.orbTargets[id] = orb.position
            var start = orb.position
            if let previous = orbsDrawn[id], self.world.distance(previous, orb.position) < 6 { start = previous }
            return ExperienceOrb(id: id, position: start, value: Int(orb.value), attracted: orb.attracted)
        }
        var dropsDrawn: [Int: CGPoint] = [:]
        for drop in combat.drops { dropsDrawn[drop.id] = drop.position }
        world.dropTargets.removeAll(keepingCapacity: true)
        var oldDropAges: [Int: Double] = [:]
        for drop in combat.drops { oldDropAges[drop.id] = drop.age }
        combat.drops = snapshot.drops.map { drop in
            let id = Int(drop.id)
            world.dropTargets[id] = drop.position
            var start = drop.position
            if let previous = dropsDrawn[id], self.world.distance(previous, drop.position) < 6 { start = previous }
            return Drop(id: id, kind: NetTables.drop(drop.code), position: start, attracted: drop.attracted,
                        speed: 0, age: oldDropAges[id] ?? 0)
        }
        combat.shrines = snapshot.shrines.map { shrine in
            Shrine(id: Int(shrine.id), kind: NetTables.shrine(shrine.kind), position: shrine.position)
        }

        world.heroes = snapshot.heroes
        world.markers = snapshot.markers
        mirror = world
        reconcileLocalHero(from: snapshot)
    }

    /// The local hero: health and flags come from the host; where they are is
    /// their own, unless the host disagrees enough to matter.
    private mutating func reconcileLocalHero(from snapshot: NetSnapshot) {
        guard let world = mirror, let mine = snapshot.heroes.first(where: { $0.slot == world.mySlot }) else { return }
        let firstTime = !world.syncedHero
        mirror?.syncedHero = true
        player.maxHealth = max(1, mine.maxHealth)
        player.health = mine.isDefeated ? 0 : min(mine.health, player.maxHealth)
        player.barrier = mine.barrier
        player.invulnerability = mine.isInvulnerable ? max(player.invulnerability, 0.3) : 0
        player.stealth = mine.isStealthed ? max(player.stealth, 0.3) : 0
        player.form = mine.form
        if mine.isDefeated {
            player.velocity = .zero
        }

        let error = self.world.delta(from: player.position, to: mine.position)
        let distance = error.length
        if firstTime || distance > MirrorWorld.snapDistance {
            player.position = mine.position
            player.velocity = mine.velocity
        } else if distance > MirrorWorld.followDistance {
            // The host moved the hero (a shove, a dash): follow, gently.
            player.position = self.world.wrap(player.position + error * 0.2)
        } else if distance > MirrorWorld.settleDistance, player.velocity.length < 0.3 {
            // Standing still, the host and this phone should agree.
            player.position = self.world.wrap(player.position + error * MirrorWorld.settleShare)
        }
        combat.playerPosition = player.position
        combat.playerFacing = player.facing
    }

    // MARK: Between snapshots

    /// Moves everything a little, and walks the local hero under their thumb.
    mutating func advanceMirror(dt: TimeInterval, intent: PlayerIntent) {
        guard var world = mirror else { return }
        let ease = CGFloat(1 - exp(-16 * dt))
        let step = CGFloat(dt)

        for index in 0..<combat.enemies.count {
            guard let target = world.enemyTargets[combat.enemies.ids[index]] else { continue }
            let offset = self.world.delta(from: combat.enemies.positions[index], to: target)
            combat.enemies.positions[index] = self.world.wrap(combat.enemies.positions[index] + offset * ease)
        }
        for index in world.allies.indices {
            guard let target = world.allyTargets[world.allies[index].id] else { continue }
            let offset = self.world.delta(from: world.allies[index].position, to: target)
            world.allies[index].position = self.world.wrap(world.allies[index].position + offset * ease)
            world.allies[index].timeSinceAttack += dt
        }
        for index in combat.orbs.indices {
            guard let target = world.orbTargets[combat.orbs[index].id] else { continue }
            let offset = self.world.delta(from: combat.orbs[index].position, to: target)
            combat.orbs[index].position = self.world.wrap(combat.orbs[index].position + offset * ease)
        }
        for index in combat.drops.indices {
            guard let target = world.dropTargets[combat.drops[index].id] else { continue }
            let offset = self.world.delta(from: combat.drops[index].position, to: target)
            combat.drops[index].position = self.world.wrap(combat.drops[index].position + offset * ease)
            combat.drops[index].age += dt
        }
        for index in world.projectiles.indices {
            world.projectiles[index].position = self.world.wrap(
                world.projectiles[index].position + world.projectiles[index].velocity * step)
        }
        for index in world.zones.indices {
            world.zones[index].age += dt
            world.zoneAges[world.zones[index].id] = world.zones[index].age
            if world.zones[index].remaining.isFinite { world.zones[index].remaining -= dt }
        }
        for index in world.hazards.indices { world.hazards[index].age += dt }
        world.hazards.removeAll { $0.isFinished }
        for (id, cooldown) in world.cooldowns {
            world.cooldowns[id]?.remaining = max(0, cooldown.remaining - dt)
        }

        // The local hero walks at once; the host confirms.
        let sheltered = false
        if !player.isDefeated, !sheltered {
            movement.step(&player, intent: intent, speedMultiplier: CGFloat(world.moveSpeed),
                          world: self.world, dt: step)
        } else {
            player.velocity = .zero
        }
        player.invulnerability = max(0, player.invulnerability - dt)
        player.timeSinceHit += dt
        combat.playerPosition = player.position
        combat.playerFacing = player.facing
        mirror = world
    }

    // MARK: Self state

    /// Adopts the local hero's level, build and finds from the host.
    mutating func applySelfState(_ state: HeroSelfState) {
        guard var world = mirror else { return }
        progression.level = state.level
        progression.experience = state.experience
        progression.required = max(1, state.required)
        progression.earnedPoints = state.earnedPoints
        progression.unspentPoints = state.unspentPoints

        var inventory = RelicInventory()
        for relic in state.relics {
            inventory.add(relic.id, rank: relic.rank)
        }
        if allocation.ranks != state.ranks || relics != inventory {
            var draft = SkillAllocation()
            for (id, rank) in state.ranks {
                guard let skill = SkillCatalog.skill(id) else { continue }
                for _ in 0..<max(0, min(rank, 12)) { draft.add(skill) }
            }
            allocation = draft
            relics = inventory
            combat.install(CompiledBuild.compile(allocation, relics: relics))
        }
        buildVersion = state.buildVersion

        var slotsNow = state.slots
        while slotsNow.count < AbilitySlots.count { slotsNow.append(nil) }
        abilitySlots = Array(slotsNow.prefix(AbilitySlots.count))

        wielded = state.wielded?.find
        let starter = StarterWeapons.definition(for: state.weapon) ?? StarterWeapons.sword
        weapon = wielded?.definition ?? starter
        offer = state.offer?.relicOffer
        combat.companionsDismissed = state.summonsDismissed
        combat.stats = state.stats

        world.cooldowns = state.cooldowns
        world.moveSpeed = state.moveSpeed
        world.hasSummons = state.hasSummons
        world.allyCount = state.allyCount
        mirror = world
    }
}
