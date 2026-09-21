import CoreGraphics
import Foundation

/// Things that happened, as they travel to the players who should see them.
///
/// A client draws its own effects, sounds and damage numbers from these, so
/// only what happened is sent, never how it looks. Hero numbers in an event
/// are a *seat* on the relay on the wire, whatever they were inside the
/// simulation.
enum NetEventCodec {
    /// Most events one packet carries. Over that, the least interesting go first.
    static let maximumPerPacket = 48

    private enum Tag: UInt8 {
        case meleeSwing = 0, projectileFired, enemyHit, enemyKilled, enemyWindup, burst, cone, chain, strikeIncoming
        case bolt, dash, abilityCast, summoned, allyFell, summonsDismissed, summonsRecalled, enemyExploded
        case playerHit, playerDodged, playerHealed, barrierGained, stealthStarted, formChanged, cheatedDeath
        case waveBegan, bossArrived, bossDefeated, realmConquered, experienceCollected, shrineAppeared, shrineUsed
        case dropCollected, weaponWielded, relicGained, levelUp, playerDefeated, heroFell, reviveStarted
        case reviveInterrupted, heroRevived, riftOpened, riftEntered
    }

    /// A packet's worth of events, most important first if there are too many.
    static func trimmed(_ events: [CombatEvent]) -> [CombatEvent] {
        guard events.count > maximumPerPacket else { return events }
        // Keep everything that is not an ordinary hit, then as many hits as fit.
        var important: [CombatEvent] = []
        var hits: [CombatEvent] = []
        for event in events {
            if case .enemyHit(_, _, _, let critical, _, _, let isDot) = event {
                if critical { important.append(event) } else if !isDot { hits.append(event) }
            } else {
                important.append(event)
            }
        }
        let room = max(0, maximumPerPacket - important.count)
        return Array(important.prefix(maximumPerPacket)) + hits.prefix(room)
    }

    static func encode(_ events: [CombatEvent], slotOf: (Int) -> UInt8) -> Data {
        var writer = ByteWriter(reserving: 512)
        let list = Array(trimmed(events).prefix(255))
        writer.u8(UInt8(list.count))
        for event in list {
            write(event, to: &writer, slotOf: slotOf)
        }
        return writer.data
    }

    static func decode(_ data: Data) -> [CombatEvent]? {
        var reader = ByteReader(data)
        let count = Int(reader.u8())
        var events: [CombatEvent] = []
        for _ in 0..<count {
            guard let event = read(from: &reader) else { return nil }
            events.append(event)
        }
        return reader.failed ? nil : events
    }

    // MARK: One event

    private static func write(_ event: CombatEvent, to w: inout ByteWriter, slotOf: (Int) -> UInt8) {
        func visual(_ style: VisualStyle) { w.u8(NetTables.visualIndex(style)) }
        switch event {
        case let .meleeSwing(origin, direction, range, arc):
            w.u8(Tag.meleeSwing.rawValue); w.point(origin); w.direction(direction); w.f32(Float(range)); w.f32(Float(arc))
        case let .projectileFired(sprite, origin, direction):
            w.u8(Tag.projectileFired.rawValue); w.u16(NetTables.hash(of: sprite)); w.point(origin); w.direction(direction)
        case let .enemyHit(id, position, amount, critical, direction, type, isDot):
            w.u8(Tag.enemyHit.rawValue); w.u32(UInt32(truncatingIfNeeded: id)); w.point(position)
            w.f32(Float(amount)); w.u8((critical ? 1 : 0) | (isDot ? 2 : 0)); w.direction(direction); w.u8(type.index)
        case let .enemyKilled(id, kind, position, direction):
            w.u8(Tag.enemyKilled.rawValue); w.u32(UInt32(truncatingIfNeeded: id)); w.u16(NetTables.hash16(kind))
            w.point(position); w.direction(direction)
        case .enemyWindup(let id):
            w.u8(Tag.enemyWindup.rawValue); w.u32(UInt32(truncatingIfNeeded: id))
        case let .burst(position, radius, style):
            w.u8(Tag.burst.rawValue); w.point(position); w.f32(Float(radius)); visual(style)
        case let .cone(origin, direction, range, arc, style):
            w.u8(Tag.cone.rawValue); w.point(origin); w.direction(direction); w.f32(Float(range)); w.f32(Float(arc))
            visual(style)
        case let .chain(points, style):
            w.u8(Tag.chain.rawValue)
            let list = points.prefix(16)
            w.u8(UInt8(list.count))
            for point in list { w.point(point) }
            visual(style)
        case let .strikeIncoming(position, radius, delay, style):
            w.u8(Tag.strikeIncoming.rawValue); w.point(position); w.f32(Float(radius)); w.f32(Float(delay)); visual(style)
        case let .bolt(position, style):
            w.u8(Tag.bolt.rawValue); w.point(position); visual(style)
        case let .dash(from, to, style):
            w.u8(Tag.dash.rawValue); w.point(from); w.point(to); visual(style)
        case let .abilityCast(id, style):
            w.u8(Tag.abilityCast.rawValue); w.string(id); visual(style)
        case let .summoned(position, style):
            w.u8(Tag.summoned.rawValue); w.point(position); visual(style)
        case let .allyFell(position, style):
            w.u8(Tag.allyFell.rawValue); w.point(position); visual(style)
        case .summonsDismissed: w.u8(Tag.summonsDismissed.rawValue)
        case .summonsRecalled: w.u8(Tag.summonsRecalled.rawValue)
        case let .enemyExploded(position, radius):
            w.u8(Tag.enemyExploded.rawValue); w.point(position); w.f32(Float(radius))
        case let .playerHit(amount, direction):
            w.u8(Tag.playerHit.rawValue); w.f32(Float(amount)); w.direction(direction)
        case .playerDodged: w.u8(Tag.playerDodged.rawValue)
        case .playerHealed(let amount): w.u8(Tag.playerHealed.rawValue); w.f32(Float(amount))
        case .barrierGained: w.u8(Tag.barrierGained.rawValue)
        case .stealthStarted: w.u8(Tag.stealthStarted.rawValue)
        case .formChanged(let form): w.u8(Tag.formChanged.rawValue); w.string(form ?? "")
        case .cheatedDeath: w.u8(Tag.cheatedDeath.rawValue)
        case .waveBegan(let wave): w.u8(Tag.waveBegan.rawValue); w.u16(UInt16(clamping: wave))
        case .bossArrived(let title): w.u8(Tag.bossArrived.rawValue); w.string(title)
        case .bossDefeated(let title): w.u8(Tag.bossDefeated.rawValue); w.string(title)
        case .realmConquered: w.u8(Tag.realmConquered.rawValue)
        case .experienceCollected(let amount): w.u8(Tag.experienceCollected.rawValue); w.u32(UInt32(clamping: max(0, amount)))
        case let .shrineAppeared(kind, position):
            w.u8(Tag.shrineAppeared.rawValue); w.u8(NetTables.shrineIndex(kind)); w.point(position)
        case let .shrineUsed(kind, position):
            w.u8(Tag.shrineUsed.rawValue); w.u8(NetTables.shrineIndex(kind)); w.point(position)
        case let .riftOpened(kind, position):
            w.u8(Tag.riftOpened.rawValue); w.u8(UInt8(kind.rawValue)); w.point(position)
        case .riftEntered(let kind):
            w.u8(Tag.riftEntered.rawValue); w.u8(UInt8(kind.rawValue))
        case let .dropCollected(kind, position):
            w.u8(Tag.dropCollected.rawValue); w.u8(NetTables.dropCode(kind)); w.point(position)
        case let .weaponWielded(title, rarity):
            w.u8(Tag.weaponWielded.rawValue); w.string(title); w.u8(UInt8(clamping: rarity.rawValue))
        case let .relicGained(id, rank):
            w.u8(Tag.relicGained.rawValue); w.string(id); w.u8(UInt8(clamping: rank))
        case let .levelUp(level, position):
            w.u8(Tag.levelUp.rawValue); w.u16(UInt16(clamping: level)); w.point(position)
        case .playerDefeated: w.u8(Tag.playerDefeated.rawValue)
        case let .heroFell(hero, position):
            w.u8(Tag.heroFell.rawValue); w.u8(slotOf(hero)); w.point(position)
        case let .reviveStarted(hero, reviver):
            w.u8(Tag.reviveStarted.rawValue); w.u8(slotOf(hero)); w.u8(slotOf(reviver))
        case .reviveInterrupted(let hero):
            w.u8(Tag.reviveInterrupted.rawValue); w.u8(slotOf(hero))
        case let .heroRevived(hero, position):
            w.u8(Tag.heroRevived.rawValue); w.u8(slotOf(hero)); w.point(position)
        }
    }

    private static func read(from r: inout ByteReader) -> CombatEvent? {
        guard let tag = Tag(rawValue: r.u8()) else { return nil }
        func visual() -> VisualStyle { NetTables.visual(r.u8()) }
        switch tag {
        case .meleeSwing:
            return .meleeSwing(origin: r.point(), direction: r.direction(), range: CGFloat(r.f32()), arcDegrees: Double(r.f32()))
        case .projectileFired:
            // A sprite this app does not know is drawn as a plain bolt.
            let sprite = NetTables.sprite(r.u16()) ?? .projectileBolt
            return .projectileFired(spriteID: sprite, origin: r.point(), direction: r.direction())
        case .enemyHit:
            let id = Int(r.u32())
            let position = r.point()
            let amount = Double(r.f32())
            let flags = r.u8()
            let direction = r.direction()
            let type = DamageType(index: r.u8())
            return .enemyHit(enemyID: id, position: position, amount: amount, isCritical: flags & 1 != 0,
                             direction: direction, type: type, isDot: flags & 2 != 0)
        case .enemyKilled:
            let id = Int(r.u32())
            let hash = r.u16()
            let position = r.point()
            let direction = r.direction()
            let kind = NetTables.enemyByHash[hash]?.id ?? EnemyCatalog.goblin.id
            return .enemyKilled(enemyID: id, kind: kind, position: position, direction: direction)
        case .enemyWindup: return .enemyWindup(enemyID: Int(r.u32()))
        case .burst: return .burst(position: r.point(), radius: CGFloat(r.f32()), visual: visual())
        case .cone:
            return .cone(origin: r.point(), direction: r.direction(), range: CGFloat(r.f32()),
                         arcDegrees: Double(r.f32()), visual: visual())
        case .chain:
            let count = Int(r.u8())
            var points: [CGPoint] = []
            for _ in 0..<count { points.append(r.point()) }
            return .chain(points: points, visual: visual())
        case .strikeIncoming:
            return .strikeIncoming(position: r.point(), radius: CGFloat(r.f32()), delay: Double(r.f32()), visual: visual())
        case .bolt: return .bolt(position: r.point(), visual: visual())
        case .dash: return .dash(from: r.point(), to: r.point(), visual: visual())
        case .abilityCast: return .abilityCast(id: r.string(), visual: visual())
        case .summoned: return .summoned(position: r.point(), visual: visual())
        case .allyFell: return .allyFell(position: r.point(), visual: visual())
        case .summonsDismissed: return .summonsDismissed
        case .summonsRecalled: return .summonsRecalled
        case .enemyExploded: return .enemyExploded(position: r.point(), radius: CGFloat(r.f32()))
        case .playerHit: return .playerHit(amount: Double(r.f32()), direction: r.direction())
        case .playerDodged: return .playerDodged
        case .playerHealed: return .playerHealed(amount: Double(r.f32()))
        case .barrierGained: return .barrierGained
        case .stealthStarted: return .stealthStarted
        case .formChanged:
            let form = r.string()
            return .formChanged(form.isEmpty ? nil : form)
        case .cheatedDeath: return .cheatedDeath
        case .waveBegan: return .waveBegan(wave: Int(r.u16()))
        case .bossArrived: return .bossArrived(title: r.string())
        case .bossDefeated: return .bossDefeated(title: r.string())
        case .realmConquered: return .realmConquered
        case .experienceCollected: return .experienceCollected(amount: Int(r.u32()))
        case .shrineAppeared: return .shrineAppeared(kind: NetTables.shrine(r.u8()), position: r.point())
        case .shrineUsed: return .shrineUsed(kind: NetTables.shrine(r.u8()), position: r.point())
        case .riftOpened:
            let kind = RiftKind(rawValue: Int(r.u8())) ?? .cinders
            return .riftOpened(kind: kind, position: r.point())
        case .riftEntered: return .riftEntered(kind: RiftKind(rawValue: Int(r.u8())) ?? .cinders)
        case .dropCollected: return .dropCollected(kind: NetTables.drop(r.u8()), position: r.point())
        case .weaponWielded:
            return .weaponWielded(title: r.string(), rarity: ItemRarity(rawValue: Int(r.u8())) ?? .common)
        case .relicGained: return .relicGained(id: r.string(), rank: Int(r.u8()))
        case .levelUp: return .levelUp(level: Int(r.u16()), position: r.point())
        case .playerDefeated: return .playerDefeated
        case .heroFell: return .heroFell(hero: Int(r.u8()), position: r.point())
        case .reviveStarted: return .reviveStarted(hero: Int(r.u8()), reviver: Int(r.u8()))
        case .reviveInterrupted: return .reviveInterrupted(hero: Int(r.u8()))
        case .heroRevived: return .heroRevived(hero: Int(r.u8()), position: r.point())
        }
    }
}
