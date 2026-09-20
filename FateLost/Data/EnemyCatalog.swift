import CoreGraphics
import Foundation

/// Enemy catalogue. Balance lives here, not in the systems that use it.
///
/// Every creature is an answer to a different question. Melee asks you to
/// move, ranged asks you to close, chargers ask you to step aside, summoners
/// ask you to pick a target, exploders ask you to let go of a kill. A realm
/// picks a roster from these so that no single habit carries a player
/// through all ten of them.
///
/// `earliestWave` is the gate: a roster's easy kinds are there from the
/// first wave and its nastier ones arrive later, so a run gets harder by
/// changing shape rather than only by multiplying numbers.
enum EnemyCatalog {
    // MARK: - Goblinoid: the Ashen Wilds warband

    /// Small, quick and fragile. Dangerous only in numbers.
    static let goblin = EnemyDefinition(
        id: "enemy.goblin", name: "Goblin", family: .goblinoid, rank: .minion,
        maxHealth: 18, moveSpeed: 2.5, radius: 0.3,
        attackDamage: 7, attackReach: 0.28, attackWindup: 0.32, attackCooldown: 1.1,
        knockbackResistance: 0, damageType: .physical, behavior: .melee,
        experience: 1, spawnWeight: 1, earliestWave: 1,
        spriteVariants: [.enemyGoblin, .enemyGoblinHooded, .enemyGoblinHelmed]
    )

    /// Lean and fast, with twin knives. Punishes standing still.
    static let skulker = EnemyDefinition(
        id: "enemy.goblinSkulker", name: "Goblin Skulker", family: .goblinoid, rank: .minion,
        maxHealth: 11, moveSpeed: 3.5, radius: 0.26,
        attackDamage: 5, attackReach: 0.24, attackWindup: 0.22, attackCooldown: 0.85,
        knockbackResistance: 0, damageType: .physical, behavior: .melee,
        experience: 1, spawnWeight: 0.45, earliestWave: 1,
        spriteVariants: [.enemyGoblinSkulker, .enemyGoblinSkulkerPale]
    )

    /// Shoots from the back of the crowd. Walking at it is the answer. They
    /// were massing early and taking the fun out of the opening waves, so they
    /// are rarer, arrive a wave later and loose a shot only every four seconds.
    static let goblinArcher = EnemyDefinition(
        id: "enemy.goblinArcher", name: "Goblin Archer", family: .goblinoid, rank: .soldier,
        maxHealth: 15, moveSpeed: 2.0, radius: 0.28,
        attackDamage: 8, attackReach: 0.3, attackWindup: 0.55, attackCooldown: 4,
        knockbackResistance: 0, damageType: .physical,
        behavior: .ranged(range: 7, projectileSpeed: 10, sprite: .projectileArrow),
        experience: 2, spawnWeight: 0.2, earliestWave: 3,
        spriteVariants: [.enemyGoblinArcher]
    )

    /// Long reach behind a spear. Keeps its distance a heartbeat longer.
    static let spearman = EnemyDefinition(
        id: "enemy.goblinSpearman", name: "Goblin Spearman", family: .goblinoid, rank: .soldier,
        maxHealth: 26, moveSpeed: 2.2, radius: 0.32,
        attackDamage: 9, attackReach: 0.8, attackWindup: 0.5, attackCooldown: 1.4,
        knockbackResistance: 0.2, damageType: .physical, behavior: .melee,
        experience: 2, spawnWeight: 0.3, earliestWave: 3,
        spriteVariants: [.enemyGoblinSpearman, .enemyGoblinSpearmanRed]
    )

    /// A hulking club-wielder. Shrugs off shoves and hits very hard.
    static let brute = EnemyDefinition(
        id: "enemy.goblinBrute", name: "Goblin Brute", family: .goblinoid, rank: .soldier,
        maxHealth: 80, moveSpeed: 1.8, radius: 0.46,
        attackDamage: 17, attackReach: 0.42, attackWindup: 0.6, attackCooldown: 1.7,
        knockbackResistance: 0.65, damageType: .physical, behavior: .melee,
        experience: 5, spawnWeight: 0.14, earliestWave: 3,
        spriteVariants: [.enemyGoblinBrute, .enemyGoblinBruteScarred]
    )

    /// Carries a lit powder keg. Its long fuse is the warning.
    static let sapper = EnemyDefinition(
        id: "enemy.goblinSapper", name: "Goblin Sapper", family: .goblinoid, rank: .soldier,
        maxHealth: 14, moveSpeed: 3.1, radius: 0.3,
        attackDamage: 24, attackReach: 0.5, attackWindup: 0.9, attackCooldown: 1,
        knockbackResistance: 0, damageType: .fire, behavior: .exploder(radius: 1.6),
        experience: 2, spawnWeight: 0.1, earliestWave: 5,
        spriteVariants: [.enemyGoblinSapper]
    )

    /// Calls the warband in. Leaving one alive is a choice you pay for.
    static let goblinShaman = EnemyDefinition(
        id: "enemy.goblinShaman", name: "Goblin Shaman", family: .goblinoid, rank: .soldier,
        maxHealth: 34, moveSpeed: 2.3, radius: 0.3,
        attackDamage: 8, attackReach: 0.3, attackWindup: 0.5, attackCooldown: 1.5,
        knockbackResistance: 0.1, damageType: .poison,
        behavior: .summoner(spawns: "enemy.goblin", count: 3, interval: 9, range: 6),
        experience: 4, spawnWeight: 0.12, earliestWave: 4,
        spriteVariants: [.enemyGoblinShaman]
    )

    /// A captain in looted plate that throws itself across the gap.
    static let hobgoblin = EnemyDefinition(
        id: "enemy.hobgoblin", name: "Hobgoblin Captain", family: .goblinoid, rank: .elite,
        maxHealth: 150, moveSpeed: 2.4, radius: 0.48,
        attackDamage: 22, attackReach: 0.5, attackWindup: 0.55, attackCooldown: 1.5,
        knockbackResistance: 0.7, damageType: .physical,
        behavior: .charger(range: 5.5, speed: 13, distance: 5),
        experience: 6, spawnWeight: 0.07, earliestWave: 6,
        spriteVariants: [.enemyHobgoblin], drawScale: 1.05
    )

    // MARK: - Undead

    static let skeletonWarrior = EnemyDefinition(
        id: "enemy.skeletonWarrior", name: "Risen Soldier", family: .undead, rank: .minion,
        maxHealth: 24, moveSpeed: 2.4, radius: 0.3,
        attackDamage: 9, attackReach: 0.3, attackWindup: 0.38, attackCooldown: 1.15,
        knockbackResistance: 0.15, damageType: .physical, behavior: .melee,
        experience: 1, spawnWeight: 1, earliestWave: 1,
        spriteVariants: [.enemySkeletonWarrior]
    )

    static let skeletonArcher = EnemyDefinition(
        id: "enemy.skeletonArcher", name: "Bone Archer", family: .undead, rank: .soldier,
        maxHealth: 18, moveSpeed: 2.2, radius: 0.28,
        attackDamage: 10, attackReach: 0.3, attackWindup: 0.6, attackCooldown: 1.7,
        knockbackResistance: 0.1, damageType: .physical,
        behavior: .ranged(range: 7.5, projectileSpeed: 11, sprite: .projectileArrow),
        experience: 2, spawnWeight: 0.4, earliestWave: 2,
        spriteVariants: [.enemySkeletonArcherFoe]
    )

    /// Runs on will alone, and runs fast.
    static let boneHound = EnemyDefinition(
        id: "enemy.boneHound", name: "Bone Hound", family: .undead, rank: .minion,
        maxHealth: 16, moveSpeed: 3.4, radius: 0.3,
        attackDamage: 8, attackReach: 0.3, attackWindup: 0.3, attackCooldown: 1,
        knockbackResistance: 0, damageType: .physical,
        behavior: .charger(range: 4.5, speed: 12, distance: 4),
        experience: 2, spawnWeight: 0.35, earliestWave: 2,
        spriteVariants: [.enemyBoneHound]
    )

    /// No body to speak of, and it moves like it.
    static let wraith = EnemyDefinition(
        id: "enemy.wraith", name: "Wraith", family: .undead, rank: .soldier,
        maxHealth: 30, moveSpeed: 3.6, radius: 0.3,
        attackDamage: 13, attackReach: 0.35, attackWindup: 0.3, attackCooldown: 1.2,
        knockbackResistance: 0.4, damageType: .shadow, behavior: .melee,
        experience: 3, spawnWeight: 0.25, earliestWave: 4,
        spriteVariants: [.enemyWraith]
    )

    /// Raises what you have already killed.
    static let necromancer = EnemyDefinition(
        id: "enemy.necromancer", name: "Necromancer", family: .undead, rank: .soldier,
        maxHealth: 44, moveSpeed: 2.1, radius: 0.3,
        attackDamage: 11, attackReach: 0.3, attackWindup: 0.55, attackCooldown: 1.6,
        knockbackResistance: 0.1, damageType: .shadow,
        behavior: .summoner(spawns: "enemy.skeletonWarrior", count: 3, interval: 8, range: 7),
        experience: 5, spawnWeight: 0.12, earliestWave: 5,
        spriteVariants: [.enemyNecromancer]
    )

    static let rotHulk = EnemyDefinition(
        id: "enemy.rotHulk", name: "Rot Hulk", family: .undead, rank: .elite,
        maxHealth: 210, moveSpeed: 1.5, radius: 0.58,
        attackDamage: 26, attackReach: 0.55, attackWindup: 0.75, attackCooldown: 2,
        knockbackResistance: 0.85, damageType: .poison, behavior: .melee,
        experience: 7, spawnWeight: 0.06, earliestWave: 7,
        spriteVariants: [.enemyRotHulk], drawScale: 1.1
    )

    // MARK: - Beast

    static let direWolf = EnemyDefinition(
        id: "enemy.direWolf", name: "Dire Wolf", family: .beast, rank: .minion,
        maxHealth: 22, moveSpeed: 3.6, radius: 0.34,
        attackDamage: 10, attackReach: 0.32, attackWindup: 0.3, attackCooldown: 1,
        knockbackResistance: 0.1, damageType: .physical,
        behavior: .charger(range: 5, speed: 14, distance: 4.5),
        experience: 2, spawnWeight: 0.8, earliestWave: 1,
        spriteVariants: [.enemyDireWolf]
    )

    static let giantSpider = EnemyDefinition(
        id: "enemy.giantSpider", name: "Great Spider", family: .beast, rank: .soldier,
        maxHealth: 34, moveSpeed: 2.8, radius: 0.36,
        attackDamage: 11, attackReach: 0.32, attackWindup: 0.5, attackCooldown: 1.5,
        knockbackResistance: 0.15, damageType: .poison,
        behavior: .ranged(range: 6, projectileSpeed: 8, sprite: .projectileShard),
        experience: 3, spawnWeight: 0.35, earliestWave: 3,
        spriteVariants: [.enemyGiantSpider]
    )

    static let corruptedStag = EnemyDefinition(
        id: "enemy.corruptedStag", name: "Rotwood Stag", family: .beast, rank: .elite,
        maxHealth: 170, moveSpeed: 2.6, radius: 0.5,
        attackDamage: 24, attackReach: 0.55, attackWindup: 0.5, attackCooldown: 1.6,
        knockbackResistance: 0.6, damageType: .poison,
        behavior: .charger(range: 7, speed: 16, distance: 7),
        experience: 6, spawnWeight: 0.07, earliestWave: 6,
        spriteVariants: [.enemyCorruptedStag], drawScale: 1.05
    )

    // MARK: - Demon

    static let impling = EnemyDefinition(
        id: "enemy.impling", name: "Impling", family: .demon, rank: .minion,
        maxHealth: 16, moveSpeed: 3.2, radius: 0.26,
        attackDamage: 9, attackReach: 0.3, attackWindup: 0.5, attackCooldown: 1.5,
        knockbackResistance: 0, damageType: .fire,
        behavior: .ranged(range: 6, projectileSpeed: 9, sprite: .projectileBolt),
        experience: 2, spawnWeight: 0.8, earliestWave: 1,
        spriteVariants: [.enemyImpling]
    )

    static let hornedFiend = EnemyDefinition(
        id: "enemy.hornedFiend", name: "Horned Fiend", family: .demon, rank: .soldier,
        maxHealth: 58, moveSpeed: 2.5, radius: 0.38,
        attackDamage: 17, attackReach: 0.45, attackWindup: 0.5, attackCooldown: 1.4,
        knockbackResistance: 0.4, damageType: .fire, behavior: .melee,
        experience: 3, spawnWeight: 0.45, earliestWave: 2,
        spriteVariants: [.enemyHornedFiend]
    )

    static let emberHound = EnemyDefinition(
        id: "enemy.emberHound", name: "Ember Hound", family: .demon, rank: .soldier,
        maxHealth: 32, moveSpeed: 3.8, radius: 0.34,
        attackDamage: 13, attackReach: 0.32, attackWindup: 0.28, attackCooldown: 1,
        knockbackResistance: 0.15, damageType: .fire,
        behavior: .charger(range: 5.5, speed: 15, distance: 5),
        experience: 3, spawnWeight: 0.35, earliestWave: 3,
        spriteVariants: [.enemyEmberHound]
    )

    static let brimstoneBrute = EnemyDefinition(
        id: "enemy.brimstoneBrute", name: "Brimstone Brute", family: .demon, rank: .elite,
        maxHealth: 230, moveSpeed: 1.6, radius: 0.6,
        attackDamage: 30, attackReach: 0.6, attackWindup: 0.8, attackCooldown: 2.1,
        knockbackResistance: 0.9, damageType: .fire, behavior: .melee,
        experience: 8, spawnWeight: 0.06, earliestWave: 6,
        spriteVariants: [.enemyBrimstoneBrute], drawScale: 1.1
    )

    // MARK: - Construct

    static let animatedArmour = EnemyDefinition(
        id: "enemy.animatedArmour", name: "Empty Harness", family: .construct, rank: .soldier,
        maxHealth: 70, moveSpeed: 2, radius: 0.36,
        attackDamage: 16, attackReach: 0.4, attackWindup: 0.5, attackCooldown: 1.4,
        knockbackResistance: 0.6, damageType: .physical, behavior: .melee,
        experience: 3, spawnWeight: 0.8, earliestWave: 1,
        spriteVariants: [.enemyAnimatedArmour]
    )

    static let runeSentinel = EnemyDefinition(
        id: "enemy.runeSentinel", name: "Rune Sentinel", family: .construct, rank: .soldier,
        maxHealth: 62, moveSpeed: 1.9, radius: 0.36,
        attackDamage: 14, attackReach: 0.35, attackWindup: 0.65, attackCooldown: 1.8,
        knockbackResistance: 0.55, damageType: .arcane,
        behavior: .ranged(range: 7, projectileSpeed: 10, sprite: .projectileArcaneBolt),
        experience: 3, spawnWeight: 0.4, earliestWave: 3,
        spriteVariants: [.enemyRuneSentinel]
    )

    static let siegeGolem = EnemyDefinition(
        id: "enemy.siegeGolem", name: "Siege Golem", family: .construct, rank: .elite,
        maxHealth: 300, moveSpeed: 1.4, radius: 0.66,
        attackDamage: 34, attackReach: 0.7, attackWindup: 0.9, attackCooldown: 2.3,
        knockbackResistance: 1, damageType: .physical, behavior: .melee,
        experience: 9, spawnWeight: 0.05, earliestWave: 7,
        spriteVariants: [.enemySiegeGolem], drawScale: 1.15
    )

    // MARK: - Aberration

    static let voidling = EnemyDefinition(
        id: "enemy.voidling", name: "Voidling", family: .aberration, rank: .minion,
        maxHealth: 20, moveSpeed: 4, radius: 0.28,
        attackDamage: 11, attackReach: 0.3, attackWindup: 0.25, attackCooldown: 1,
        knockbackResistance: 0.2, damageType: .arcane, behavior: .melee,
        experience: 2, spawnWeight: 0.9, earliestWave: 1,
        spriteVariants: [.enemyVoidling]
    )

    static let gazer = EnemyDefinition(
        id: "enemy.gazer", name: "Gazer", family: .aberration, rank: .soldier,
        maxHealth: 40, moveSpeed: 2, radius: 0.34,
        attackDamage: 14, attackReach: 0.3, attackWindup: 0.7, attackCooldown: 1.9,
        knockbackResistance: 0.3, damageType: .arcane,
        behavior: .ranged(range: 8, projectileSpeed: 9, sprite: .projectileArcaneBolt),
        experience: 4, spawnWeight: 0.35, earliestWave: 3,
        spriteVariants: [.enemyGazer]
    )

    static let fleshHorror = EnemyDefinition(
        id: "enemy.fleshHorror", name: "Flesh Horror", family: .aberration, rank: .elite,
        maxHealth: 240, moveSpeed: 1.7, radius: 0.6,
        attackDamage: 28, attackReach: 0.6, attackWindup: 0.7, attackCooldown: 1.9,
        knockbackResistance: 0.8, damageType: .shadow, behavior: .melee,
        experience: 8, spawnWeight: 0.06, earliestWave: 6,
        spriteVariants: [.enemyFleshHorror], drawScale: 1.1
    )

    // MARK: - Cultist

    static let cultist = EnemyDefinition(
        id: "enemy.cultist", name: "Cultist", family: .cultist, rank: .minion,
        maxHealth: 26, moveSpeed: 2.7, radius: 0.3,
        attackDamage: 10, attackReach: 0.3, attackWindup: 0.35, attackCooldown: 1.1,
        knockbackResistance: 0, damageType: .shadow, behavior: .melee,
        experience: 1, spawnWeight: 1, earliestWave: 1,
        spriteVariants: [.enemyCultist]
    )

    /// Runs at you with its arms wide and does not stop.
    static let flagellant = EnemyDefinition(
        id: "enemy.flagellant", name: "Flagellant", family: .cultist, rank: .soldier,
        maxHealth: 22, moveSpeed: 3.6, radius: 0.3,
        attackDamage: 28, attackReach: 0.5, attackWindup: 0.85, attackCooldown: 1,
        knockbackResistance: 0.1, damageType: .shadow, behavior: .exploder(radius: 1.8),
        experience: 3, spawnWeight: 0.2, earliestWave: 4,
        spriteVariants: [.enemyFlagellant]
    )

    static let cultLeader = EnemyDefinition(
        id: "enemy.cultLeader", name: "Cult Leader", family: .cultist, rank: .soldier,
        maxHealth: 50, moveSpeed: 2.2, radius: 0.32,
        attackDamage: 13, attackReach: 0.32, attackWindup: 0.55, attackCooldown: 1.6,
        knockbackResistance: 0.15, damageType: .shadow,
        behavior: .summoner(spawns: "enemy.cultist", count: 3, interval: 8.5, range: 7),
        experience: 5, spawnWeight: 0.12, earliestWave: 5,
        spriteVariants: [.enemyCultLeader]
    )

    // MARK: - Elemental

    static let emberWisp = EnemyDefinition(
        id: "enemy.emberWisp", name: "Ember Wisp", family: .elemental, rank: .minion,
        maxHealth: 14, moveSpeed: 4.2, radius: 0.26,
        attackDamage: 9, attackReach: 0.3, attackWindup: 0.25, attackCooldown: 0.9,
        knockbackResistance: 0, damageType: .fire, behavior: .melee,
        experience: 2, spawnWeight: 0.8, earliestWave: 1,
        spriteVariants: [.enemyEmberWisp]
    )

    static let frostShard = EnemyDefinition(
        id: "enemy.frostShard", name: "Frost Shard", family: .elemental, rank: .soldier,
        maxHealth: 30, moveSpeed: 2.2, radius: 0.3,
        attackDamage: 12, attackReach: 0.3, attackWindup: 0.6, attackCooldown: 1.7,
        knockbackResistance: 0.2, damageType: .cold,
        behavior: .ranged(range: 7, projectileSpeed: 10, sprite: .projectileShard),
        experience: 3, spawnWeight: 0.45, earliestWave: 2,
        spriteVariants: [.enemyFrostShard]
    )

    static let iceGolem = EnemyDefinition(
        id: "enemy.iceGolem", name: "Rime Golem", family: .elemental, rank: .elite,
        maxHealth: 260, moveSpeed: 1.5, radius: 0.62,
        attackDamage: 30, attackReach: 0.62, attackWindup: 0.8, attackCooldown: 2.1,
        knockbackResistance: 0.95, damageType: .cold, behavior: .melee,
        experience: 8, spawnWeight: 0.06, earliestWave: 6,
        spriteVariants: [.enemyIceGolem], drawScale: 1.1
    )

    // MARK: - Champions

    /// A champion's numbers are deliberately blunt: a great deal of health, a
    /// slow and very visible strike, and enough knockback resistance that it
    /// cannot be kited into a corner. The fight is about the room it takes up.
    private static func champion(id: String, name: String, epithet: String, family: EnemyFamily,
                                 health: Double, speed: CGFloat, radius: CGFloat, damage: Double,
                                 reach: CGFloat, windup: Double, cooldown: Double, type: DamageType,
                                 behavior: EnemyBehavior, sprite: SpriteID, scale: CGFloat,
                                 experience: Int) -> EnemyDefinition {
        EnemyDefinition(
            id: id, name: name, family: family, rank: .boss,
            maxHealth: health, moveSpeed: speed, radius: radius,
            attackDamage: damage, attackReach: reach, attackWindup: windup, attackCooldown: cooldown,
            knockbackResistance: 1, damageType: type, behavior: behavior,
            experience: experience, spawnWeight: 0, earliestWave: 1,
            spriteVariants: [sprite], drawScale: scale, epithet: epithet
        )
    }

    static let bossWarchief = champion(
        id: "boss.warchief", name: "Grask", epithet: "the Warchief", family: .goblinoid,
        health: 1_600, speed: 2.3, radius: 0.8, damage: 34, reach: 0.7, windup: 1.1, cooldown: 3.2,
        type: .physical, behavior: .charger(range: 8, speed: 17, distance: 8),
        sprite: .enemyBossWarchief, scale: 1.5, experience: 40
    )

    static let bossDrownedKing = champion(
        id: "boss.drownedKing", name: "The Drowned King", epithet: "Crowned in Silt", family: .undead,
        health: 2_400, speed: 1.6, radius: 0.9, damage: 40, reach: 0.8, windup: 0.85, cooldown: 2,
        type: .cold, behavior: .summoner(spawns: "enemy.skeletonWarrior", count: 5, interval: 7, range: 9),
        sprite: .enemyBossDrownedKing, scale: 1.55, experience: 55
    )

    static let bossHollowStag = champion(
        id: "boss.hollowStag", name: "The Hollow Stag", epithet: "Antlered Rot", family: .beast,
        health: 3_100, speed: 3, radius: 0.85, damage: 44, reach: 0.8, windup: 0.9, cooldown: 2.6,
        type: .poison, behavior: .charger(range: 10, speed: 20, distance: 10),
        sprite: .enemyBossHollowStag, scale: 1.5, experience: 70
    )

    static let bossRimeTyrant = champion(
        id: "boss.rimeTyrant", name: "The Rime Tyrant", epithet: "Stiller of Hearts", family: .elemental,
        health: 4_200, speed: 1.5, radius: 0.95, damage: 48, reach: 0.85, windup: 0.9, cooldown: 2.1,
        type: .cold, behavior: .ranged(range: 9, projectileSpeed: 9, sprite: .projectileShard),
        sprite: .enemyBossRimeTyrant, scale: 1.6, experience: 85
    )

    static let bossPlagueMonarch = champion(
        id: "boss.plagueMonarch", name: "The Plague Monarch", epithet: "Court of the Buried", family: .undead,
        health: 5_400, speed: 1.9, radius: 0.85, damage: 52, reach: 0.75, windup: 0.7, cooldown: 1.8,
        type: .poison, behavior: .summoner(spawns: "enemy.wraith", count: 4, interval: 6.5, range: 9),
        sprite: .enemyBossPlagueMonarch, scale: 1.55, experience: 100
    )

    static let bossEmberLord = champion(
        id: "boss.emberLord", name: "Vaskar", epithet: "the Ember Lord", family: .demon,
        health: 6_800, speed: 1.8, radius: 1, damage: 58, reach: 0.9, windup: 0.8, cooldown: 1.9,
        type: .fire, behavior: .melee,
        sprite: .enemyBossEmberLord, scale: 1.65, experience: 120
    )

    static let bossVoidmaw = champion(
        id: "boss.voidmaw", name: "Voidmaw", epithet: "That Which Looks Back", family: .aberration,
        health: 8_200, speed: 2.1, radius: 0.9, damage: 60, reach: 0.8, windup: 0.75, cooldown: 1.7,
        type: .arcane, behavior: .ranged(range: 9.5, projectileSpeed: 11, sprite: .projectileArcaneBolt),
        sprite: .enemyBossVoidmaw, scale: 1.6, experience: 140
    )

    static let bossIronSaint = champion(
        id: "boss.ironSaint", name: "The Iron Saint", epithet: "Keeper of a Broken Vow", family: .construct,
        health: 10_500, speed: 1.6, radius: 1, damage: 66, reach: 0.95, windup: 1.0, cooldown: 2.8,
        type: .holy, behavior: .charger(range: 9, speed: 18, distance: 9),
        sprite: .enemyBossIronSaint, scale: 1.6, experience: 165
    )

    static let bossGraveWarden = champion(
        id: "boss.graveWarden", name: "The Grave Warden", epithet: "Who Keeps the Gate", family: .undead,
        health: 14_000, speed: 1.8, radius: 1.1, damage: 74, reach: 1, windup: 0.85, cooldown: 2,
        type: .shadow, behavior: .summoner(spawns: "enemy.wraith", count: 5, interval: 6, range: 10),
        sprite: .enemyBossGraveWarden, scale: 1.75, experience: 200
    )

    static let bossAbyssalEcho = champion(
        id: "boss.abyssalEcho", name: "The Abyssal Echo", epithet: "Wearing Your Shape", family: .aberration,
        health: 18_000, speed: 2.4, radius: 1, damage: 80, reach: 0.9, windup: 0.7, cooldown: 1.6,
        type: .shadow, behavior: .melee,
        sprite: .enemyBossAbyssalEcho, scale: 1.6, experience: 240
    )

    // MARK: - Lookup

    static let goblinWarband: [EnemyDefinition] = [
        goblin, skulker, goblinArcher, spearman, brute, sapper, goblinShaman, hobgoblin,
    ]

    static let undeadHost: [EnemyDefinition] = [
        skeletonWarrior, skeletonArcher, boneHound, wraith, necromancer, rotHulk,
    ]

    static let wildBeasts: [EnemyDefinition] = [direWolf, giantSpider, corruptedStag]

    static let demonLegion: [EnemyDefinition] = [impling, hornedFiend, emberHound, brimstoneBrute]

    static let citadelConstructs: [EnemyDefinition] = [animatedArmour, runeSentinel, siegeGolem]

    static let aberrations: [EnemyDefinition] = [voidling, gazer, fleshHorror]

    static let cultists: [EnemyDefinition] = [cultist, flagellant, cultLeader]

    static let elementals: [EnemyDefinition] = [emberWisp, frostShard, iceGolem]

    static let champions: [EnemyDefinition] = [
        bossWarchief, bossDrownedKing, bossHollowStag, bossRimeTyrant, bossPlagueMonarch,
        bossEmberLord, bossVoidmaw, bossIronSaint, bossGraveWarden, bossAbyssalEcho,
    ]

    static let all: [EnemyDefinition] = goblinWarband + undeadHost + wildBeasts + demonLegion
        + citadelConstructs + aberrations + cultists + elementals + champions

    static func definition(for id: EnemyKindID) -> EnemyDefinition? {
        all.first { $0.id == id }
    }

    /// Everything that walks a realm's ground.
    ///
    /// Each roster mixes two or three families so a realm has a face of its
    /// own, and the later realms fold in what came before: by the Gate of
    /// Ruin everything you have already learned to beat is there at once.
    static func roster(for realm: RealmID) -> [EnemyDefinition] {
        switch realm {
        case .ashenWilds:
            return goblinWarband
        case .drownedFen:
            return undeadHost + [giantSpider, flagellant]
        case .hollowForest:
            return wildBeasts + [goblin, skulker, goblinArcher, goblinShaman, wraith]
        case .frozenWastes:
            return elementals + [direWolf, animatedArmour, skeletonWarrior, boneHound]
        case .blightedKingdom:
            return cultists + undeadHost
        case .burningDepths:
            return demonLegion + [emberWisp, cultist, flagellant]
        case .shatteredRealm:
            return aberrations + [voidling, wraith, runeSentinel, impling, frostShard]
        case .fallenCitadel:
            return citadelConstructs + cultists + [skeletonWarrior, skeletonArcher, hobgoblin]
        case .gateOfRuin, .abyss:
            return all.filter { $0.rank != .boss }
        }
    }

    /// The champions a realm sends, in order.
    static func bosses(for realm: RealmID) -> [EnemyKindID] {
        switch realm {
        case .ashenWilds: return [bossWarchief.id]
        case .drownedFen: return [bossWarchief.id, bossDrownedKing.id]
        case .hollowForest: return [bossDrownedKing.id, bossHollowStag.id]
        case .frozenWastes: return [bossHollowStag.id, bossRimeTyrant.id]
        case .blightedKingdom: return [bossRimeTyrant.id, bossPlagueMonarch.id]
        case .burningDepths: return [bossPlagueMonarch.id, bossEmberLord.id]
        case .shatteredRealm: return [bossEmberLord.id, bossVoidmaw.id]
        case .fallenCitadel: return [bossVoidmaw.id, bossIronSaint.id]
        case .gateOfRuin: return [bossIronSaint.id, bossGraveWarden.id]
        case .abyss: return champions.map(\.id)
        }
    }
}
