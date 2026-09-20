import CoreGraphics

/// How one combatant regards another. Every rule about who an effect may
/// touch is expressed through this, so no skill needs a multiplayer special
/// case of its own.
enum Relationship: Equatable {
    /// The hero themself.
    case selfHero
    /// Another living member of the party.
    case ally
    /// A member of the party who has fallen and waits at a revive marker.
    case deadAlly
    /// The horde.
    case enemy
}

/// What an effect is allowed to reach. Effects say so explicitly: a nova
/// hurts `.enemies` and nothing else (friendly fire does not exist), a
/// healing blessing reaches `.blessing`, a resurrection reaches `.deadAllies`.
struct TargetRule: OptionSet {
    let rawValue: UInt8

    static let selfHero = TargetRule(rawValue: 1 << 0)
    static let allies = TargetRule(rawValue: 1 << 1)
    static let deadAllies = TargetRule(rawValue: 1 << 2)
    static let enemies = TargetRule(rawValue: 1 << 3)

    /// Damage and crowd control: the horde only.
    static let hostile: TargetRule = [.enemies]
    /// Healing, shields and helpful auras: the caster and living friends.
    static let blessing: TargetRule = [.selfHero, .allies]
    /// A resurrection: the fallen only.
    static let resurrection: TargetRule = [.deadAllies]

    func permits(_ relationship: Relationship) -> Bool {
        switch relationship {
        case .selfHero: return contains(.selfHero)
        case .ally: return contains(.allies)
        case .deadAlly: return contains(.deadAllies)
        case .enemy: return contains(.enemies)
        }
    }
}

enum Relations {
    /// How hero `subject` regards hero `other`.
    static func between(_ subject: Int, _ other: Int, otherIsDefeated: Bool) -> Relationship {
        if subject == other { return .selfHero }
        return otherIsDefeated ? .deadAlly : .ally
    }
}

/// Something an enemy did to a hero (or a hero's summon), carried out once
/// the whole horde has moved. Deferring it lets one enemy pass serve every
/// hero: each blow is resolved in the context of the hero it lands on.
enum WorldIncident {
    case strikeHero(hero: Int, amount: Double, direction: CGPoint)
    case woundAlly(hero: Int, index: Int, id: Int, amount: Double)
}

/// A helpful effect that reaches beyond the caster: a heal, a shield, an aura.
/// Queued while the caster's state is live and delivered to the others by the
/// party once their state can be reached.
struct PartyEffect {
    enum Kind {
        case heal(fraction: Double)
        case barrier(fraction: Double)
        case buff(id: String, modifiers: [StatModifier], duration: Double)
    }

    let source: Int
    let center: CGPoint
    let radius: CGFloat
    let rule: TargetRule
    let kind: Kind
}

/// Where a fallen hero lies, waiting for a friend.
///
/// A marker is the whole of the "down" state: the hero is out of the fight,
/// their build and stats kept, until someone channels beside the marker for
/// long enough. There is no crawling and no bleed-out.
struct ReviveMarker: Equatable {
    let hero: Int
    var position: CGPoint
    /// Who is channelling, if anyone.
    var reviver: Int?
    /// 0 to 1.
    var progress: Double = 0
    /// The reviver's hit count when the channel began. Any change interrupts.
    var hitsAtStart: Int = 0
    var age: Double = 0
}

/// Party-only facts about one hero that are not part of the swapped state.
struct PartyMember: Equatable {
    /// The service's id for this player, empty in a solo run.
    var id: String
    var name: String
    /// The player's seat on the relay (0 is the host).
    var slot: Int
    var isConnected = true
    /// Seconds spent disconnected, while the hero is protected.
    var awaySeconds: Double = 0
    /// The player left the party for good.
    var isGone = false
    /// A skill tree or a find is open on their screen. The game does not
    /// stop for them, so the hero is sheltered while they choose.
    var menuOpen = false
    var menuSeconds: Double = 0
    /// The menu outlasted its shelter. It stays unsheltered until the player
    /// closes it, so a menu the host is still told about cannot protect a hero forever.
    var menuLocked = false
    /// Whether the hero was alive when this step began.
    var stepAlive = true
    /// Experience earned while fallen, paid out on revival.
    var bankedExperience = 0
    var intent = PlayerIntent.idle
    /// The weapon the hero began the run with.
    var starterWeaponID: WeaponID

    init(id: String = "", name: String = "", slot: Int = 0, starterWeaponID: WeaponID = "") {
        self.id = id
        self.name = name
        self.slot = slot
        self.starterWeaponID = starterWeaponID
    }
}

/// Who joins a party run and what they bring.
struct PartyHeroConfig {
    var id: String
    var name: String
    var slot: Int
    var weaponID: WeaponID
    var legacy: [StatModifier] = []
    var bonusRerolls = 0
}

/// A read-only picture of one hero, for drawing, the HUD and the network.
struct HeroSummary: Equatable {
    var index: Int
    var id: String
    var name: String
    var slot: Int
    var position: CGPoint
    var velocity: CGPoint
    var facing: CGPoint
    var health: Double
    var maxHealth: Double
    var barrier: Double
    var isDefeated: Bool
    var isInvulnerable: Bool
    var isStealthed: Bool
    var isSheltered: Bool
    var isConnected: Bool
    var level: Int
    var weaponSprite: SpriteID
    var form: FormID?
}

/// Party numbers, kept together so a balance pass never touches logic.
struct PartyTuning {
    static let maximumHeroes = 4
    /// Each extra hero adds this much to enemy health and to the spawn rate,
    /// so a party of four faces a bigger horde without the fight becoming
    /// four times as long.
    var enemyHealthPerExtraHero: Double = 0.55
    var spawnRatePerExtraHero: Double = 0.45
    /// Seconds a friend must channel beside a marker.
    var reviveSeconds: Double = 3
    /// How close a friend must be to begin, and to keep going.
    var reviveStartRange: CGFloat = 1.8
    var reviveHoldRange: CGFloat = 2.6
    /// Share of maximum health a revived hero returns with: all of it, so a
    /// friend raised just before a wave is not cut down by its first blow.
    var reviveHealthFraction: Double = 1.0
    /// Seconds of immunity after being revived.
    var reviveInvulnerability: Double = 2
    /// The longest a hero is sheltered while their player is in a menu.
    var menuShelterSeconds: Double = 25
    /// A player who drops out is protected this long while they reconnect.
    var disconnectGraceSeconds: Double = 60
    /// The horde stops for a breather after every this-many waves (0: never).
    var restEveryWaves = 2
    /// How long the breather lasts if nobody asks to go on.
    var restSeconds: Double = 90
    /// Distance from the arena's centre point that the party starts spread out.
    var startRingRadius: CGFloat = 1.4
}

/// A hero as the horde sees them: enough to chase, strike and shoot without
/// reaching into the hero's state.
struct AITarget {
    var position: CGPoint
    var isAlive: Bool
    /// Stealthed, or sheltered while their player is in a menu. Enemies
    /// cannot find a hidden hero, though a blast can still reach them.
    var isHidden: Bool
    var hero: Int
}

enum WorldIncidents {
    /// Carries out what the horde did, for a run with one hero: the blows
    /// land on that hero straight away.
    static func applyToLoneHero(_ combat: inout CombatState, player: inout PlayerState, godMode: Bool) {
        guard !combat.incidents.isEmpty else { return }
        let incidents = combat.incidents
        combat.incidents.removeAll(keepingCapacity: true)
        for incident in incidents {
            switch incident {
            case let .strikeHero(_, amount, direction):
                guard !player.isDefeated else { continue }
                combat.strikePlayer(&player, amount: amount, direction: direction, godMode: godMode)
            case let .woundAlly(_, index, id, amount):
                guard index < combat.allies.count, combat.allies[index].id == id else { continue }
                AllySystem.wound(index, amount: amount, &combat)
            }
        }
    }
}
