import CoreGraphics
import Foundation

// MARK: - What a snapshot holds

struct NetHero: Equatable {
    static let defeated: UInt8 = 1 << 0
    static let invulnerable: UInt8 = 1 << 1
    static let stealthed: UInt8 = 1 << 2
    static let sheltered: UInt8 = 1 << 3
    static let connected: UInt8 = 1 << 4

    var slot: UInt8
    var flags: UInt8
    var position: CGPoint
    var velocity: CGPoint
    var facing: CGPoint
    var health: Double
    var maxHealth: Double
    var barrier: Double
    var level: Int
    var weaponSprite: SpriteID?
    var form: FormID?

    var isDefeated: Bool { flags & Self.defeated != 0 }
    var isInvulnerable: Bool { flags & Self.invulnerable != 0 }
    var isStealthed: Bool { flags & Self.stealthed != 0 }
    var isSheltered: Bool { flags & Self.sheltered != 0 }
    var isConnected: Bool { flags & Self.connected != 0 }
}

struct NetMarker: Equatable {
    var slot: UInt8
    var position: CGPoint
    var progress: Double
    /// The seat channelling the revive, if any.
    var reviver: UInt8?
}

struct NetEnemy: Equatable {
    var id: UInt32
    var kind: UInt16
    var strain: UInt8
    var position: CGPoint
    var healthFraction: Double
    var heading: CGPoint
    var statusMask: UInt16
    var windupFraction: Double
    var aim: CGPoint
    var isCharging: Bool
}

struct NetProjectile: Equatable {
    var id: UInt32
    var position: CGPoint
    var velocity: CGPoint
    var sprite: UInt16
    var visual: UInt8
    var radius: Double
    var isHostile: Bool
}

struct NetZone: Equatable {
    var id: UInt32
    var position: CGPoint
    var radius: Double
    var visual: UInt8
    var isAura: Bool
    /// Seconds left, or nil for a permanent aura.
    var remaining: Double?
}

struct NetAlly: Equatable {
    static let orbit: UInt8 = 0
    static let melee: UInt8 = 1
    static let ranged: UInt8 = 2

    var id: UInt32
    var position: CGPoint
    var heading: CGPoint
    var sprite: UInt16
    var scale: Double
    var tint: [UInt8]?
    var behavior: UInt8
    var visual: UInt8
    /// 0...1, or nil for something that cannot be hurt.
    var healthFraction: Double?
    var attackedRecently: Bool
}

struct NetOrb: Equatable {
    var id: UInt32
    var position: CGPoint
    var value: UInt16
    var attracted: Bool
}

struct NetDrop: Equatable {
    var id: UInt32
    var position: CGPoint
    var code: UInt8
    var attracted: Bool
}

struct NetShrine: Equatable {
    var id: UInt32
    var position: CGPoint
    var kind: UInt8
}

struct NetWave: Equatable {
    var index: Int
    var phase: UInt8
    var bossFraction: Double
    var bossTitle: String?
    var curseSeconds: Int
    /// The breather: seconds left, and how many of the party have voted to go on.
    var restSeconds: Int = 0
    var restVotes: Int = 0
    var restVoters: Int = 0

    static let fighting: UInt8 = 0
    static let bossIncoming: UInt8 = 1
    static let bossFight: UInt8 = 2
    static let conquered: UInt8 = 3
    static let resting: UInt8 = 4
    static let clearing: UInt8 = 5
}

/// A picture of the world as one player should see it, sent to them about
/// fifteen times a second. It holds only what is near their hero (plus the
/// whole party), so it stays small however big the fight is.
struct NetSnapshot: Equatable {
    /// The most of each thing one snapshot carries, so a frame always fits.
    enum Limit {
        static let enemies = 450
        static let projectiles = 200
        static let zones = 40
        static let allies = 100
        static let orbs = 150
        static let drops = 40
        static let shrines = 6
        static let markers = 4
    }

    var contentVersion: UInt8 = NetTables.contentVersion
    /// The host's simulated clock, in milliseconds.
    var tickMilliseconds: UInt32 = 0
    var wave = NetWave(index: 1, phase: 0, bossFraction: 0, bossTitle: nil, curseSeconds: 0)
    var heroes: [NetHero] = []
    var markers: [NetMarker] = []
    var enemies: [NetEnemy] = []
    var projectiles: [NetProjectile] = []
    var zones: [NetZone] = []
    var allies: [NetAlly] = []
    var orbs: [NetOrb] = []
    var drops: [NetDrop] = []
    var shrines: [NetShrine] = []

    // MARK: Encoding

    func encoded() -> Data {
        var writer = ByteWriter(reserving: 2048)
        writer.u8(contentVersion)
        writer.u32(tickMilliseconds)

        writer.u16(UInt16(clamping: wave.index))
        writer.u8(wave.phase)
        writer.fraction(wave.bossFraction)
        writer.u8(UInt8(clamping: wave.curseSeconds))
        writer.string(wave.bossTitle ?? "")
        writer.u8(UInt8(clamping: wave.restSeconds))
        writer.u8(UInt8(clamping: wave.restVotes))
        writer.u8(UInt8(clamping: wave.restVoters))

        writer.u8(UInt8(heroes.count))
        for hero in heroes {
            writer.u8(hero.slot)
            writer.u8(hero.flags | (hero.form != nil ? 1 << 5 : 0))
            writer.point(hero.position)
            writer.i8(NetScale.velocityByte(hero.velocity.x))
            writer.i8(NetScale.velocityByte(hero.velocity.y))
            writer.direction(hero.facing)
            writer.u16(UInt16(clamping: Int(hero.health.rounded())))
            writer.u16(UInt16(clamping: Int(hero.maxHealth.rounded())))
            writer.u16(UInt16(clamping: Int(hero.barrier.rounded())))
            writer.u8(UInt8(clamping: hero.level))
            writer.u16(hero.weaponSprite.map { NetTables.hash(of: $0) } ?? 0)
            if let form = hero.form { writer.string(form) }
        }

        let markerList = markers.prefix(Limit.markers)
        writer.u8(UInt8(markerList.count))
        for marker in markerList {
            writer.u8(marker.slot)
            writer.point(marker.position)
            writer.fraction(marker.progress)
            writer.u8(marker.reviver ?? 0xFF)
        }

        let enemyList = enemies.prefix(Limit.enemies)
        writer.u16(UInt16(enemyList.count))
        for enemy in enemyList {
            writer.u32(enemy.id)
            writer.u16(enemy.kind)
            writer.u8(enemy.strain)
            writer.point(enemy.position)
            writer.fraction(enemy.healthFraction)
            writer.direction(enemy.heading)
            writer.u16(enemy.statusMask)
            writer.fraction(enemy.windupFraction)
            writer.direction(enemy.aim)
            writer.bool(enemy.isCharging)
        }

        let projectileList = projectiles.prefix(Limit.projectiles)
        writer.u16(UInt16(projectileList.count))
        for projectile in projectileList {
            writer.u32(projectile.id)
            writer.point(projectile.position)
            writer.i8(NetScale.velocityByte(projectile.velocity.x))
            writer.i8(NetScale.velocityByte(projectile.velocity.y))
            writer.u16(projectile.sprite)
            writer.u8(projectile.visual)
            writer.u8(UInt8(max(0, min(255, (projectile.radius * 64).rounded()))))
            writer.bool(projectile.isHostile)
        }

        let zoneList = zones.prefix(Limit.zones)
        writer.u8(UInt8(zoneList.count))
        for zone in zoneList {
            writer.u32(zone.id)
            writer.point(zone.position)
            writer.u8(UInt8(max(0, min(255, (zone.radius * 8).rounded()))))
            writer.u8(zone.visual)
            writer.bool(zone.isAura)
            writer.u8(zone.remaining.map { UInt8(max(0, min(254, ($0 * 10).rounded()))) } ?? 255)
        }

        let allyList = allies.prefix(Limit.allies)
        writer.u8(UInt8(allyList.count))
        for ally in allyList {
            writer.u32(ally.id)
            writer.point(ally.position)
            writer.direction(ally.heading)
            writer.u16(ally.sprite)
            writer.u8(UInt8(max(0, min(255, (ally.scale * 32).rounded()))))
            writer.bool(ally.tint != nil)
            if let tint = ally.tint {
                for component in tint.prefix(3) { writer.u8(component) }
            }
            writer.u8(ally.behavior)
            writer.u8(ally.visual)
            writer.u8(ally.healthFraction.map { UInt8(max(0, min(254, ($0 * 254).rounded()))) } ?? 255)
            writer.bool(ally.attackedRecently)
        }

        let orbList = orbs.prefix(Limit.orbs)
        writer.u16(UInt16(orbList.count))
        for orb in orbList {
            writer.u32(orb.id)
            writer.point(orb.position)
            writer.u16(orb.value)
            writer.bool(orb.attracted)
        }

        let dropList = drops.prefix(Limit.drops)
        writer.u8(UInt8(dropList.count))
        for drop in dropList {
            writer.u32(drop.id)
            writer.point(drop.position)
            writer.u8(drop.code)
            writer.bool(drop.attracted)
        }

        let shrineList = shrines.prefix(Limit.shrines)
        writer.u8(UInt8(shrineList.count))
        for shrine in shrineList {
            writer.u32(shrine.id)
            writer.point(shrine.position)
            writer.u8(shrine.kind)
        }
        return writer.data
    }

    /// Reads a snapshot, or nil if the bytes are not one (short, broken, or
    /// from a version of the content this app does not share).
    static func decode(_ data: Data) -> NetSnapshot? {
        var reader = ByteReader(data)
        var snapshot = NetSnapshot()
        snapshot.contentVersion = reader.u8()
        guard snapshot.contentVersion == NetTables.contentVersion else { return nil }
        snapshot.tickMilliseconds = reader.u32()

        let index = Int(reader.u16())
        let phase = reader.u8()
        let bossFraction = reader.fraction()
        let curse = Int(reader.u8())
        let title = reader.string()
        let restSeconds = Int(reader.u8())
        let restVotes = Int(reader.u8())
        let restVoters = Int(reader.u8())
        snapshot.wave = NetWave(index: index, phase: phase, bossFraction: bossFraction,
                                bossTitle: title.isEmpty ? nil : title, curseSeconds: curse,
                                restSeconds: restSeconds, restVotes: restVotes, restVoters: restVoters)

        let heroCount = Int(reader.u8())
        guard heroCount <= PartyProtocol.maxPlayers else { return nil }
        for _ in 0..<heroCount {
            let slot = reader.u8()
            let flags = reader.u8()
            let position = reader.point()
            let vx = NetScale.velocity(fromByte: reader.i8())
            let vy = NetScale.velocity(fromByte: reader.i8())
            let facing = reader.direction()
            let health = Double(reader.u16())
            let maxHealth = Double(reader.u16())
            let barrier = Double(reader.u16())
            let level = Int(reader.u8())
            let weapon = reader.u16()
            let form: FormID? = flags & (1 << 5) != 0 ? reader.string() : nil
            snapshot.heroes.append(NetHero(
                slot: slot, flags: flags & ~(1 << 5), position: position, velocity: CGPoint(x: vx, y: vy),
                facing: facing, health: health, maxHealth: maxHealth, barrier: barrier, level: level,
                weaponSprite: weapon == 0 ? nil : NetTables.sprite(weapon), form: form))
        }

        let markerCount = Int(reader.u8())
        guard markerCount <= Limit.markers else { return nil }
        for _ in 0..<markerCount {
            let slot = reader.u8()
            let position = reader.point()
            let progress = reader.fraction()
            let reviver = reader.u8()
            snapshot.markers.append(NetMarker(slot: slot, position: position, progress: progress,
                                              reviver: reviver == 0xFF ? nil : reviver))
        }

        let enemyCount = Int(reader.u16())
        guard enemyCount <= Limit.enemies else { return nil }
        for _ in 0..<enemyCount {
            snapshot.enemies.append(NetEnemy(
                id: reader.u32(), kind: reader.u16(), strain: reader.u8(), position: reader.point(),
                healthFraction: reader.fraction(), heading: reader.direction(), statusMask: reader.u16(),
                windupFraction: reader.fraction(), aim: reader.direction(), isCharging: reader.bool()))
        }

        let projectileCount = Int(reader.u16())
        guard projectileCount <= Limit.projectiles else { return nil }
        for _ in 0..<projectileCount {
            let id = reader.u32()
            let position = reader.point()
            let vx = NetScale.velocity(fromByte: reader.i8())
            let vy = NetScale.velocity(fromByte: reader.i8())
            snapshot.projectiles.append(NetProjectile(
                id: id, position: position, velocity: CGPoint(x: vx, y: vy), sprite: reader.u16(),
                visual: reader.u8(), radius: Double(reader.u8()) / 64, isHostile: reader.bool()))
        }

        let zoneCount = Int(reader.u8())
        guard zoneCount <= Limit.zones else { return nil }
        for _ in 0..<zoneCount {
            let id = reader.u32()
            let position = reader.point()
            let radius = Double(reader.u8()) / 8
            let visual = reader.u8()
            let aura = reader.bool()
            let remaining = reader.u8()
            snapshot.zones.append(NetZone(id: id, position: position, radius: radius, visual: visual, isAura: aura,
                                          remaining: remaining == 255 ? nil : Double(remaining) / 10))
        }

        let allyCount = Int(reader.u8())
        guard allyCount <= Limit.allies else { return nil }
        for _ in 0..<allyCount {
            let id = reader.u32()
            let position = reader.point()
            let heading = reader.direction()
            let sprite = reader.u16()
            let scale = Double(reader.u8()) / 32
            var tint: [UInt8]?
            if reader.bool() {
                tint = [reader.u8(), reader.u8(), reader.u8()]
            }
            let behavior = reader.u8()
            let visual = reader.u8()
            let health = reader.u8()
            let attacked = reader.bool()
            snapshot.allies.append(NetAlly(
                id: id, position: position, heading: heading, sprite: sprite, scale: scale, tint: tint,
                behavior: behavior, visual: visual, healthFraction: health == 255 ? nil : Double(health) / 254,
                attackedRecently: attacked))
        }

        let orbCount = Int(reader.u16())
        guard orbCount <= Limit.orbs else { return nil }
        for _ in 0..<orbCount {
            snapshot.orbs.append(NetOrb(id: reader.u32(), position: reader.point(), value: reader.u16(),
                                        attracted: reader.bool()))
        }

        let dropCount = Int(reader.u8())
        guard dropCount <= Limit.drops else { return nil }
        for _ in 0..<dropCount {
            snapshot.drops.append(NetDrop(id: reader.u32(), position: reader.point(), code: reader.u8(),
                                          attracted: reader.bool()))
        }

        let shrineCount = Int(reader.u8())
        guard shrineCount <= Limit.shrines else { return nil }
        for _ in 0..<shrineCount {
            snapshot.shrines.append(NetShrine(id: reader.u32(), position: reader.point(), kind: reader.u8()))
        }

        guard !reader.failed else { return nil }
        return snapshot
    }
}

// MARK: - Taking a snapshot of the simulation

extension GameSimulation {
    /// Every zone any hero has out, for drawing.
    var allZones: [Zone] {
        if let mirror { return mirror.zones }
        guard slots.count > 1 else { return combat.zones }
        var all = combat.zones
        for hero in slots.indices where hero != activeHero {
            all.append(contentsOf: slots[hero].combat.zones)
        }
        return all
    }

    /// Every summon any hero has out, for drawing.
    var allAllies: [Ally] {
        if let mirror { return mirror.allies }
        guard slots.count > 1 else { return combat.allies }
        var all = combat.allies
        for hero in slots.indices where hero != activeHero {
            all.append(contentsOf: slots[hero].combat.allies)
        }
        return all
    }

    /// The world as the hero in `viewer` should see it: the whole party, and
    /// whatever lies within `radius` of them.
    func snapshot(forViewer viewer: Int, radius: CGFloat) -> NetSnapshot {
        var snapshot = NetSnapshot()
        snapshot.tickMilliseconds = UInt32(truncatingIfNeeded: Int(elapsed * 1000))
        let center = playerState(of: viewer).position
        let world = self.world

        func near(_ point: CGPoint) -> Bool { world.distance(center, point) <= radius }

        let state = wave
        let phase: UInt8
        switch state.phase {
        case .fighting: phase = NetWave.fighting
        case .bossIncoming: phase = NetWave.bossIncoming
        case .bossFight: phase = NetWave.bossFight
        case .conquered: phase = NetWave.conquered
        case .resting: phase = NetWave.resting
        case .clearing: phase = NetWave.clearing
        }
        snapshot.wave = NetWave(index: state.index, phase: phase, bossFraction: state.bossHealthFraction,
                                bossTitle: state.isBossActive ? state.bossTitle : nil,
                                curseSeconds: Int(curseRemaining.rounded(.up)),
                                restSeconds: Int(state.restRemaining.rounded(.up)),
                                restVotes: state.restVotes, restVoters: state.restVoters)

        for hero in 0..<heroCount {
            let summary = heroSummary(hero)
            var flags: UInt8 = 0
            if summary.isDefeated { flags |= NetHero.defeated }
            if summary.isInvulnerable { flags |= NetHero.invulnerable }
            if summary.isStealthed { flags |= NetHero.stealthed }
            if summary.isSheltered { flags |= NetHero.sheltered }
            if summary.isConnected { flags |= NetHero.connected }
            snapshot.heroes.append(NetHero(
                slot: UInt8(clamping: summary.slot), flags: flags, position: summary.position,
                velocity: summary.velocity, facing: summary.facing, health: summary.health,
                maxHealth: summary.maxHealth, barrier: summary.barrier, level: summary.level,
                weaponSprite: summary.weaponSprite, form: summary.form))
        }

        for marker in combat.reviveMarkers where marker.hero < members.count {
            snapshot.markers.append(NetMarker(
                slot: UInt8(clamping: members[marker.hero].slot), position: marker.position,
                progress: marker.progress,
                reviver: marker.reviver.flatMap { $0 < members.count ? UInt8(clamping: members[$0].slot) : nil }))
        }

        let store = combat.enemies
        var candidates: [(distance: CGFloat, index: Int)] = []
        candidates.reserveCapacity(store.count)
        for index in 0..<store.count {
            let distance = world.distance(center, store.positions[index])
            if distance <= radius { candidates.append((distance, index)) }
        }
        if candidates.count > NetSnapshot.Limit.enemies {
            candidates.sort { $0.distance < $1.distance }
            candidates.removeSubrange(NetSnapshot.Limit.enemies...)
        }
        for entry in candidates {
            let index = entry.index
            let definition = store.definition(at: index)
            let strength = store.maxHealth[index] > 0 ? store.health[index] / store.maxHealth[index] : 0
            let windupFraction = definition.attackWindup > 0
                ? max(0, min(1, store.windup[index] / definition.attackWindup)) : 0
            snapshot.enemies.append(NetEnemy(
                id: UInt32(truncatingIfNeeded: store.ids[index]), kind: NetTables.hash16(definition.id),
                strain: UInt8(clamping: store.strains[index]), position: store.positions[index],
                healthFraction: strength, heading: store.heading[index],
                statusMask: store.statusMask[index], windupFraction: windupFraction, aim: store.aim[index],
                isCharging: store.dash[index] != .zero))
        }

        var shots = combat.hostileProjectiles
        for hero in 0..<heroCount {
            shots.append(contentsOf: hero == activeHero || slots.isEmpty ? combat.projectiles
                                                                          : slots[hero].combat.projectiles)
        }
        for projectile in shots where near(projectile.position) {
            if snapshot.projectiles.count >= NetSnapshot.Limit.projectiles { break }
            snapshot.projectiles.append(NetProjectile(
                id: UInt32(truncatingIfNeeded: projectile.id), position: projectile.position,
                velocity: projectile.velocity, sprite: NetTables.hash(of: projectile.spriteID),
                visual: NetTables.visualIndex(projectile.visual), radius: Double(projectile.radius),
                isHostile: projectile.isHostile))
        }

        for zone in allZones where near(zone.position) {
            if snapshot.zones.count >= NetSnapshot.Limit.zones { break }
            snapshot.zones.append(NetZone(
                id: UInt32(truncatingIfNeeded: zone.id), position: zone.position, radius: Double(zone.radius),
                visual: NetTables.visualIndex(zone.spec.visual), isAura: zone.isAura,
                remaining: zone.remaining.isFinite ? zone.remaining : nil))
        }

        for ally in allAllies where near(ally.position) {
            if snapshot.allies.count >= NetSnapshot.Limit.allies { break }
            let behavior: UInt8
            switch ally.spec.behavior {
            case .orbit: behavior = NetAlly.orbit
            case .melee: behavior = NetAlly.melee
            case .ranged: behavior = NetAlly.ranged
            }
            var tint: [UInt8]?
            if let color = ally.spec.tint {
                tint = [UInt8(max(0, min(255, color.red * 255))), UInt8(max(0, min(255, color.green * 255))),
                        UInt8(max(0, min(255, color.blue * 255)))]
            }
            snapshot.allies.append(NetAlly(
                id: UInt32(truncatingIfNeeded: ally.id), position: ally.position, heading: ally.heading,
                sprite: NetTables.hash(of: ally.spec.sprite(forAlly: ally.id)), scale: Double(ally.spec.scale),
                tint: tint, behavior: behavior, visual: NetTables.visualIndex(ally.spec.visual),
                healthFraction: ally.isMortal ? ally.healthFraction : nil,
                attackedRecently: ally.timeSinceAttack < 0.2))
        }

        for orb in combat.orbs where near(orb.position) {
            if snapshot.orbs.count >= NetSnapshot.Limit.orbs { break }
            snapshot.orbs.append(NetOrb(id: UInt32(truncatingIfNeeded: orb.id), position: orb.position,
                                        value: UInt16(clamping: orb.value), attracted: orb.attracted))
        }
        for drop in combat.drops where near(drop.position) {
            if snapshot.drops.count >= NetSnapshot.Limit.drops { break }
            snapshot.drops.append(NetDrop(id: UInt32(truncatingIfNeeded: drop.id), position: drop.position,
                                          code: NetTables.dropCode(drop.kind), attracted: drop.attracted))
        }
        for shrine in combat.shrines.prefix(NetSnapshot.Limit.shrines) {
            snapshot.shrines.append(NetShrine(id: UInt32(truncatingIfNeeded: shrine.id), position: shrine.position,
                                              kind: NetTables.shrineIndex(shrine.kind)))
        }
        return snapshot
    }
}
