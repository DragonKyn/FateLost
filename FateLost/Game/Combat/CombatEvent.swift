import CoreGraphics

/// Something that happened during a simulation step that presentation may
/// want to show, play or feel.
///
/// The simulation appends events as it resolves combat; the scene drains
/// them once per frame and turns them into effects, sounds and haptics. Game
/// rules never depend on whether an event was presented.
enum CombatEvent: Equatable {
    /// A melee weapon swung. `direction` is a unit vector in world space.
    case meleeSwing(origin: CGPoint, direction: CGPoint, range: CGFloat, arcDegrees: Double)
    case projectileFired(spriteID: SpriteID, origin: CGPoint, direction: CGPoint)
    case enemyHit(enemyID: Int, position: CGPoint, amount: Double, isCritical: Bool, direction: CGPoint,
                  type: DamageType, isDot: Bool)
    case enemyKilled(enemyID: Int, kind: EnemyKindID, position: CGPoint, direction: CGPoint)
    /// An enemy began a strike (the telegraph).
    case enemyWindup(enemyID: Int)
    /// Area damage or impact: novas, bursts, splashes.
    case burst(position: CGPoint, radius: CGFloat, visual: VisualStyle)
    case cone(origin: CGPoint, direction: CGPoint, range: CGFloat, arcDegrees: Double, visual: VisualStyle)
    /// A chain leaping through these points in order.
    case chain(points: [CGPoint], visual: VisualStyle)
    /// Warning of an impact about to land.
    case strikeIncoming(position: CGPoint, radius: CGFloat, delay: Double, visual: VisualStyle)
    /// A single strike from above (storm bolts).
    case bolt(position: CGPoint, visual: VisualStyle)
    case dash(from: CGPoint, to: CGPoint, visual: VisualStyle)
    case abilityCast(id: AbilityID, visual: VisualStyle)
    case summoned(position: CGPoint, visual: VisualStyle)
    /// A summon was cut down.
    case allyFell(position: CGPoint, visual: VisualStyle)
    /// The player sent their companions away, or called them back.
    case summonsDismissed
    case summonsRecalled
    /// An enemy's powder keg went off.
    case enemyExploded(position: CGPoint, radius: CGFloat)
    /// `direction` points from the attacker toward the player.
    case playerHit(amount: Double, direction: CGPoint)
    case playerDodged
    case playerHealed(amount: Double)
    case barrierGained
    case stealthStarted
    case formChanged(FormID?)
    /// A killing blow was refused (Last Bastion, Phoenix Heart).
    case cheatedDeath
    /// A new wave began.
    case waveBegan(wave: Int)
    /// A realm's champion has landed, and holds the wave open.
    case bossArrived(title: String)
    case bossDefeated(title: String)
    /// The realm's final champion fell: the run is won.
    case realmConquered
    case experienceCollected(amount: Int)
    /// A shrine rose out of the ground, and one was agreed to.
    case shrineAppeared(kind: ShrineKind, position: CGPoint)
    case shrineUsed(kind: ShrineKind, position: CGPoint)
    /// A drop was picked up.
    case dropCollected(kind: DropKind, position: CGPoint)
    /// A weapon found in a run was taken up.
    case weaponWielded(title: String, rarity: ItemRarity)
    /// A relic was taken, at the rank it now stands at.
    case relicGained(id: RelicID, rank: Int)
    case levelUp(level: Int, position: CGPoint)
    case playerDefeated
}

/// Running totals for the end-of-run summary.
struct RunStats: Equatable {
    var kills = 0
    var damageDealt: Double = 0
    var damageTaken: Double = 0
    var criticalHits = 0
    var mostEnemiesAlive = 0
    var highestHit: Double = 0
    var healingReceived: Double = 0
    var experience = 0
    var dodges = 0
    /// Summons cut down over the run.
    var summonsLost = 0
    var eliteKills = 0
    var bossKills = 0
    /// Highest wave reached.
    var wave = 1
    /// Spoils: chests opened, shrines agreed to, relics taken and weapons
    /// found and wielded.
    var chestsOpened = 0
    var shrinesUsed = 0
    var relicsTaken = 0
    var weaponsWielded = 0
    /// Times each ability was used.
    var abilityUses: [AbilityID: Int] = [:]

    var mostUsedAbility: AbilityID? {
        abilityUses.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key
    }
}

/// Where a hit came from, for life steal, triggers and statistics.
enum HitSource: UInt8 {
    case weapon
    case ability
    case proc
    case summon
    case damageOverTime
    case environment
    case levelUp
}

/// Extra damage of other types riding on a hit (e.g. "+20% as holy").
/// Fixed slots, so a hit never allocates.
struct AddedDamage: Equatable {
    private(set) var first: DamageType?
    private(set) var firstFraction: Double = 0
    private(set) var second: DamageType?
    private(set) var secondFraction: Double = 0
    private(set) var third: DamageType?
    private(set) var thirdFraction: Double = 0

    init() {}

    var isEmpty: Bool { first == nil }

    mutating func add(_ type: DamageType, _ fraction: Double) {
        if first == type || first == nil {
            first = type
            firstFraction += fraction
        } else if second == type || second == nil {
            second = type
            secondFraction += fraction
        } else if third == type || third == nil {
            third = type
            thirdFraction += fraction
        }
    }

    /// Every added type with its fraction.
    func forEach(_ body: (DamageType, Double) -> Void) {
        if let first { body(first, firstFraction) }
        if let second { body(second, secondFraction) }
        if let third { body(third, thirdFraction) }
    }

    var typeMask: UInt16 {
        var mask: UInt16 = 0
        forEach { type, _ in mask |= type.bit }
        return mask
    }
}

/// One application of damage to one enemy, before stats are applied.
///
/// All damage in the game, whatever its source, is described with this and
/// resolved by `CombatState.strike(_:with:)`, so the maths lives in exactly
/// one place.
struct Hit {
    /// Damage before the player's stats and the target's weaknesses.
    var amount: Double
    var type: DamageType
    var tags: TagMask
    /// Unit vector the blow travels along.
    var direction: CGPoint = .zero
    /// Fraction of standard knockback.
    var knockback: CGFloat = 0.5
    var critBonus: Double = 0
    var canCrit = true
    /// 0 for the player's own attacks and abilities; higher for effects
    /// set off by other effects. Triggers only answer shallow hits, which
    /// stops chains of procs feeding themselves.
    var depth: Int = 0
    /// A status this particular hit tries to inflict.
    var status: StatusApplication?
    var added = AddedDamage()
    var source: HitSource = .weapon

    var isDamageOverTime: Bool { source == .damageOverTime }

    /// Bits of every damage type involved.
    var typeMask: UInt16 { type.bit | added.typeMask }
}
