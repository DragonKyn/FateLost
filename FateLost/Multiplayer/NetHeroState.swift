import CoreGraphics
import Foundation

// MARK: - Input

/// What a player's phone tells the host, about twenty times a second.
///
/// A client is never trusted with what it does, only with what it wants:
/// which way it is pushing the stick, which ability buttons it pressed, that
/// it wants to interact. It also says where it believes it is, as a hint the
/// host may adopt when it is plausible, so movement feels immediate.
struct NetInput: Equatable {
    var sequence: UInt16 = 0
    /// World-space direction, length 0 to 1.
    var move: CGPoint = .zero
    var abilityPresses: UInt8 = 0
    var interact = false
    /// A menu (skill tree, a find) is open on their screen.
    var menuOpen = false
    var position: CGPoint = .zero

    func encoded() -> Data {
        var writer = ByteWriter(reserving: 12)
        writer.u16(sequence)
        writer.i8(Int8(max(-127, min(127, (move.x * 127).rounded()))))
        writer.i8(Int8(max(-127, min(127, (move.y * 127).rounded()))))
        writer.u8(abilityPresses & 0x0F)
        writer.u8((interact ? 1 : 0) | (menuOpen ? 2 : 0))
        writer.point(position)
        return writer.data
    }

    static func decode(_ data: Data) -> NetInput? {
        var reader = ByteReader(data)
        var input = NetInput()
        input.sequence = reader.u16()
        var move = CGPoint(x: CGFloat(reader.i8()) / 127, y: CGFloat(reader.i8()) / 127)
        // Whatever was sent, a stick cannot push harder than its full travel.
        if move.length > 1 { move = move.normalized }
        input.move = move
        input.abilityPresses = reader.u8() & 0x0F
        let flags = reader.u8()
        input.interact = flags & 1 != 0
        input.menuOpen = flags & 2 != 0
        input.position = reader.point()
        return reader.failed ? nil : input
    }
}

// MARK: - Commands

/// A build decision a player makes, sent to the host to carry out. The host
/// applies it only if it is legal for that player's hero right now.
struct NetCommand: Codable, Equatable {
    enum Kind: String, Codable {
        case commit
        case equip
        case chooseRelic
        case chooseWeapon
        case rerollOffer
        case toggleSummons
    }

    var kind: Kind
    /// For `commit`: every skill the draft holds, with its rank.
    var ranks: [String: Int]?
    /// For `commit` and `equip`: the ability in each of the four slots.
    var slots: [String?]?
    /// For `chooseRelic`.
    var index: Int?

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data) -> NetCommand? {
        guard data.count <= 4096, let command = try? JSONDecoder().decode(NetCommand.self, from: data) else {
            return nil
        }
        // Bound what a draft can ask the host to loop over.
        if let ranks = command.ranks {
            guard ranks.count <= 400, ranks.values.allSatisfy({ (0...12).contains($0) }) else { return nil }
        }
        if let slots = command.slots, slots.count > AbilitySlots.count { return nil }
        return command
    }
}

// MARK: - A hero's own state

/// Everything a player's screen needs to know about their own hero that the
/// shared snapshot does not carry: their level, their build, what they
/// carry, what is on offer, and how long their abilities take to return. Sent
/// as JSON a few times a second, and whenever something changes.
struct HeroSelfState: Codable, Equatable {
    struct Relic: Codable, Equatable {
        var id: String
        var rank: Int
    }

    struct Wielded: Codable, Equatable {
        var weapon: String
        var rarity: Int
        var affixes: [String]
        var damageScale: Double
    }

    struct Offer: Codable, Equatable {
        struct Choice: Codable, Equatable {
            var relic: String
            var rank: Int
        }

        var tier: Int
        var wave: Int
        var choices: [Choice]
        var rerollsLeft: Int
        var weapon: Wielded?
        var wielding: String?
    }

    struct Cooldown: Codable, Equatable {
        var remaining: Double
        var total: Double
    }

    var level: Int
    var experience: Int
    var required: Int
    var earnedPoints: Int
    var unspentPoints: Int
    var ranks: [String: Int]
    var slots: [String?]
    var buildVersion: Int
    var relics: [Relic]
    var offer: Offer?
    /// The starter the hero began with, and the rolled weapon in the hand, if any.
    var weapon: String
    var wielded: Wielded?
    var cooldowns: [String: Cooldown]
    var moveSpeed: Double
    var summonsDismissed: Bool
    var hasSummons: Bool
    var allyCount: Int
    var stats: RunStats
    /// Seconds of shelter left while a menu is open, or zero.
    var shelterSecondsLeft: Double
}

extension GameSimulation {
    /// The hero currently live, described for their own screen.
    func captureSelfState() -> HeroSelfState {
        var cooldowns: [String: HeroSelfState.Cooldown] = [:]
        for slot in 0..<AbilitySlots.count {
            if let id = abilitySlots[slot], let value = cooldown(forSlot: slot) {
                cooldowns[id] = .init(remaining: value.remaining, total: value.total)
            }
        }
        let held = relics.held.map { HeroSelfState.Relic(id: $0.relic.id, rank: $0.rank) }
        let member = members.indices.contains(activeHero) ? members[activeHero] : PartyMember()
        return HeroSelfState(
            level: progression.level, experience: progression.experience, required: progression.required,
            earnedPoints: progression.earnedPoints, unspentPoints: progression.unspentPoints,
            ranks: allocation.ranks, slots: abilitySlots, buildVersion: buildVersion, relics: held,
            offer: offer.map { HeroSelfState.Offer(find: $0) },
            weapon: member.starterWeaponID.isEmpty ? run.starterWeaponID : member.starterWeaponID,
            wielded: wielded.map { HeroSelfState.Wielded(find: $0) }, cooldowns: cooldowns,
            moveSpeed: combat.sheet[.moveSpeed], summonsDismissed: combat.companionsDismissed,
            hasSummons: hasSummons, allyCount: combat.allies.count, stats: combat.stats,
            shelterSecondsLeft: member.menuOpen ? max(0, tuning.party.menuShelterSeconds - member.menuSeconds) : 0)
    }
}

extension HeroSelfState.Wielded {
    init(find: WeaponFind) {
        self.init(weapon: find.weapon, rarity: find.rarity.rawValue, affixes: find.affixes.map { $0.id },
                  damageScale: find.damageScale)
    }

    /// The find, rebuilt from its parts, or nil if it names something unknown.
    var find: WeaponFind? {
        guard StarterWeapons.definition(for: weapon) != nil, let rarity = ItemRarity(rawValue: rarity) else {
            return nil
        }
        let list = affixes.compactMap { id in WeaponAffixCatalog.all.first { $0.id == id } }
        return WeaponFind(weapon: weapon, rarity: rarity, affixes: list, damageScale: max(0.5, min(3, damageScale)))
    }
}

extension HeroSelfState.Offer {
    init(find offer: RelicOffer) {
        self.init(tier: offer.tier.rawValue, wave: offer.wave,
                  choices: offer.choices.map { .init(relic: $0.relic, rank: $0.rank) },
                  rerollsLeft: offer.rerollsLeft, weapon: offer.weapon.map { HeroSelfState.Wielded(find: $0) },
                  wielding: offer.wielding)
    }

    var relicOffer: RelicOffer? {
        guard let tier = LootTier(rawValue: tier) else { return nil }
        let cards = choices.filter { RelicCatalog.relic($0.relic) != nil }
            .map { RelicChoice(relic: $0.relic, rank: max(1, min(3, $0.rank))) }
        return RelicOffer(tier: tier, wave: wave, choices: cards, rerollsLeft: rerollsLeft,
                          weapon: weapon?.find, wielding: wielding)
    }
}
