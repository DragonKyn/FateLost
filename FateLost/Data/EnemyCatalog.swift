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

    // MARK: - Night hunters (from the Frozen Wastes on)

    /// The bite cuts health regeneration to a tenth for a few seconds, so a build
    /// that leans on regenerating its way out of trouble has to kill bats first.
    static let vampireBat = EnemyDefinition(
        id: "enemy.vampireBat", name: "Vampire Bat", family: .beast, rank: .minion,
        maxHealth: 15, moveSpeed: 3.9, radius: 0.26,
        attackDamage: 6, attackReach: 0.3, attackWindup: 0.3, attackCooldown: 1.3,
        knockbackResistance: 0, damageType: .physical, behavior: .melee,
        experience: 2, spawnWeight: 0.4, earliestWave: 2,
        spriteVariants: [.enemyVampireBat], drawScale: 0.9,
        onHit: .witherRegen(seconds: 6), flutters: true
    )

    /// Almost invisible until it moves to strike: a short lunge from the shadows
    /// that hamstrings (30% slower for a few seconds).
    static let duskStalker = EnemyDefinition(
        id: "enemy.duskStalker", name: "Dusk Stalker", family: .cultist, rank: .soldier,
        maxHealth: 40, moveSpeed: 2.9, radius: 0.34,
        attackDamage: 15, attackReach: 0.4, attackWindup: 0.5, attackCooldown: 2.8,
        knockbackResistance: 0.1, damageType: .shadow,
        behavior: .charger(range: 5, speed: 13, distance: 5),
        experience: 4, spawnWeight: 0.3, earliestWave: 3,
        spriteVariants: [.enemyDuskStalker],
        onHit: .hamstring(seconds: 4, slow: 0.3), isShrouded: true
    )

    static let nightHunters: [EnemyDefinition] = [vampireBat, duskStalker]

    // MARK: - Champions

    /// A champion's numbers are deliberately blunt: a great deal of health, a
    /// slow and very visible strike, and enough knockback resistance that it
    /// cannot be kited into a corner. The fight is about the room it takes up.
    private static func champion(id: String, name: String, epithet: String, family: EnemyFamily,
                                 health: Double, speed: CGFloat, radius: CGFloat, damage: Double,
                                 reach: CGFloat, windup: Double, cooldown: Double, type: DamageType,
                                 behavior: EnemyBehavior, sprite: SpriteID, scale: CGFloat,
                                 experience: Int, kit: BossKit) -> EnemyDefinition {
        EnemyDefinition(
            id: id, name: name, family: family, rank: .boss,
            maxHealth: health, moveSpeed: speed, radius: radius,
            attackDamage: damage, attackReach: reach, attackWindup: windup, attackCooldown: cooldown,
            knockbackResistance: 1, damageType: type, behavior: behavior,
            experience: experience, spawnWeight: 0, earliestWave: 1,
            spriteVariants: [sprite], drawScale: scale, epithet: epithet, kit: kit
        )
    }

    static let bossWarchief = champion(
        id: "boss.warchief", name: "Grask", epithet: "the Warchief", family: .goblinoid,
        health: 1_600, speed: 2.3, radius: 0.8, damage: 34, reach: 0.7, windup: 1.1, cooldown: 3.2,
        type: .physical, behavior: .charger(range: 8, speed: 17, distance: 8),
        sprite: .enemyBossWarchief, scale: 1.5, experience: 40,
        kit: BossKit(moves: [.slam, .fan, .summon], intensity: 1, tempo: 5.7, adds: "enemy.goblin", signature: .slam)
    )

    static let bossDrownedKing = champion(
        id: "boss.drownedKing", name: "The Drowned King", epithet: "Crowned in Silt", family: .undead,
        health: 2_400, speed: 1.6, radius: 0.9, damage: 40, reach: 0.8, windup: 0.85, cooldown: 2,
        type: .cold, behavior: .summoner(spawns: "enemy.skeletonWarrior", count: 5, interval: 7, range: 9),
        sprite: .enemyBossDrownedKing, scale: 1.55, experience: 55,
        kit: BossKit(moves: [.meteors, .ring, .pools, .slam], intensity: 2, tempo: 5.5, signature: .pools)
    )

    static let bossHollowStag = champion(
        id: "boss.hollowStag", name: "The Hollow Stag", epithet: "Antlered Rot", family: .beast,
        health: 3_100, speed: 3, radius: 0.85, damage: 44, reach: 0.8, windup: 0.9, cooldown: 2.6,
        type: .poison, behavior: .charger(range: 10, speed: 20, distance: 10),
        sprite: .enemyBossHollowStag, scale: 1.5, experience: 70,
        kit: BossKit(moves: [.slam, .lanes, .fan, .blink], intensity: 3, tempo: 5.3, signature: .blink)
    )

    static let bossRimeTyrant = champion(
        id: "boss.rimeTyrant", name: "The Rime Tyrant", epithet: "Stiller of Hearts", family: .elemental,
        health: 4_200, speed: 1.5, radius: 0.95, damage: 48, reach: 0.85, windup: 0.9, cooldown: 2.1,
        type: .cold, behavior: .ranged(range: 9, projectileSpeed: 9, sprite: .projectileShard),
        sprite: .enemyBossRimeTyrant, scale: 1.6, experience: 85,
        kit: BossKit(moves: [.ring, .cleave, .lanes, .meteors, .sweep], intensity: 4, tempo: 5.1, signature: .sweep)
    )

    static let bossPlagueMonarch = champion(
        id: "boss.plagueMonarch", name: "The Plague Monarch", epithet: "Court of the Buried", family: .undead,
        health: 5_400, speed: 1.9, radius: 0.85, damage: 52, reach: 0.75, windup: 0.7, cooldown: 1.8,
        type: .poison, behavior: .summoner(spawns: "enemy.wraith", count: 4, interval: 6.5, range: 9),
        sprite: .enemyBossPlagueMonarch, scale: 1.55, experience: 100,
        kit: BossKit(moves: [.meteors, .ring, .cleave, .spiral, .summon, .hunt], intensity: 5, tempo: 4.8, adds: "enemy.wraith", signature: .hunt)
    )

    static let bossEmberLord = champion(
        id: "boss.emberLord", name: "Vaskar", epithet: "the Ember Lord", family: .demon,
        health: 6_800, speed: 1.8, radius: 1, damage: 58, reach: 0.9, windup: 0.8, cooldown: 1.9,
        type: .fire, behavior: .melee,
        sprite: .enemyBossEmberLord, scale: 1.65, experience: 120,
        kit: BossKit(moves: [.cleave, .meteors, .lanes, .slam, .pools, .sweep], intensity: 6, tempo: 4.5, signature: .meteors)
    )

    static let bossVoidmaw = champion(
        id: "boss.voidmaw", name: "Voidmaw", epithet: "That Which Looks Back", family: .aberration,
        health: 8_200, speed: 2.1, radius: 0.9, damage: 60, reach: 0.8, windup: 0.75, cooldown: 1.7,
        type: .arcane, behavior: .ranged(range: 9.5, projectileSpeed: 11, sprite: .projectileArcaneBolt),
        sprite: .enemyBossVoidmaw, scale: 1.6, experience: 140,
        kit: BossKit(moves: [.ring, .spiral, .meteors, .lanes, .sweep, .hunt], intensity: 8, tempo: 4.2, signature: .spiral)
    )

    static let bossIronSaint = champion(
        id: "boss.ironSaint", name: "The Iron Saint", epithet: "Keeper of a Broken Vow", family: .construct,
        health: 10_500, speed: 1.6, radius: 1, damage: 66, reach: 0.95, windup: 1.0, cooldown: 2.8,
        type: .holy, behavior: .charger(range: 9, speed: 18, distance: 9),
        sprite: .enemyBossIronSaint, scale: 1.6, experience: 165,
        kit: BossKit(moves: [.lanes, .cleave, .slam, .fan, .spiral, .sweep], intensity: 10, tempo: 3.9, signature: .lanes)
    )

    static let bossGraveWarden = champion(
        id: "boss.graveWarden", name: "The Grave Warden", epithet: "Who Keeps the Gate", family: .undead,
        health: 14_000, speed: 1.8, radius: 1.1, damage: 74, reach: 1, windup: 0.85, cooldown: 2,
        type: .shadow, behavior: .summoner(spawns: "enemy.wraith", count: 5, interval: 6, range: 10),
        sprite: .enemyBossGraveWarden, scale: 1.75, experience: 200,
        kit: BossKit(moves: [.meteors, .spiral, .lanes, .ring, .slam, .summon, .hunt], intensity: 10, tempo: 3.8, adds: "enemy.wraith", signature: .hunt)
    )

    static let bossAbyssalEcho = champion(
        id: "boss.abyssalEcho", name: "The Abyssal Echo", epithet: "Wearing Your Shape", family: .aberration,
        health: 18_000, speed: 2.4, radius: 1, damage: 80, reach: 0.9, windup: 0.7, cooldown: 1.6,
        type: .shadow, behavior: .melee,
        sprite: .enemyBossAbyssalEcho, scale: 1.6, experience: 240,
        kit: BossKit(moves: [.spiral, .lanes, .meteors, .cleave, .ring, .slam, .blink, .sweep, .hunt], intensity: 10, tempo: 3.6, signature: .blink)
    )

    /// A champion between the realm's great ones. Its numbers follow its tier (1 is the
    /// first champion anyone meets, 27 the last), so a realm's list rises steadily.
    private static func warlord(id: String, name: String, epithet: String, family: EnemyFamily, tier: Int,
                                speed: CGFloat, radius: CGFloat, type: DamageType, behavior: EnemyBehavior,
                                sprite: SpriteID, scale: CGFloat, kit: BossKit) -> EnemyDefinition {
        let step = Double(tier - 1)
        return champion(id: id, name: name, epithet: epithet, family: family,
                        health: (1400 * pow(1.1, step)).rounded(), speed: speed, radius: radius,
                        damage: (30 + 1.75 * step).rounded(), reach: 0.7 + 0.01 * CGFloat(tier),
                        windup: max(0.95, 1.15 - 0.01 * step), cooldown: max(1.6, 3.2 - 0.06 * step),
                        type: type, behavior: behavior, sprite: sprite, scale: scale,
                        experience: 40 + tier * 8, kit: kit)
    }

    static let bossPitBrute = warlord(
        id: "boss.pitBrute", name: "Rukh", epithet: "the Pit-Brute", family: .goblinoid, tier: 1,
        speed: 2.2, radius: 0.85, type: .physical, behavior: .melee, sprite: .enemyBossPitBrute, scale: 1.4,
        kit: BossKit(moves: [.slam, .fan], intensity: 1, tempo: 5.8, signature: .slam))

    static let bossBogmother = warlord(
        id: "boss.bogmother", name: "Vesk", epithet: "the Bogmother", family: .beast, tier: 3,
        speed: 1.8, radius: 1.0, type: .poison,
        behavior: .ranged(range: 8, projectileSpeed: 8, sprite: .projectileBolt),
        sprite: .enemyBossBogmother, scale: 1.5,
        kit: BossKit(moves: [.pools, .fan, .summon], intensity: 2, tempo: 5.6, adds: "enemy.giantSpider",
                     signature: .pools))

    static let bossThornmaw = warlord(
        id: "boss.thornmaw", name: "Old Thornmaw", epithet: "the Root-King", family: .beast, tier: 5,
        speed: 1.5, radius: 1.0, type: .poison, behavior: .melee, sprite: .enemyBossThornmaw, scale: 1.5,
        kit: BossKit(moves: [.lanes, .slam, .pools, .hunt], intensity: 2, tempo: 5.4, signature: .lanes))

    static let bossFrostfang = warlord(
        id: "boss.frostfang", name: "Frostfang", epithet: "Alpha of the Long Winter", family: .beast, tier: 7,
        speed: 3.2, radius: 0.9, type: .cold, behavior: .charger(range: 9, speed: 18, distance: 9),
        sprite: .enemyBossFrostfang, scale: 1.3,
        kit: BossKit(moves: [.blink, .cleave, .fan, .lanes], intensity: 3, tempo: 5.2, signature: .blink))

    static let bossRimewitch = warlord(
        id: "boss.rimewitch", name: "Yrsa", epithet: "the Rimewitch", family: .cultist, tier: 8,
        speed: 1.7, radius: 0.8, type: .cold,
        behavior: .ranged(range: 9, projectileSpeed: 9, sprite: .projectileShard),
        sprite: .enemyBossRimewitch, scale: 1.5,
        kit: BossKit(moves: [.ring, .meteors, .pools, .sweep], intensity: 3, tempo: 5.1, signature: .pools))

    static let bossPlagueKnight = warlord(
        id: "boss.plagueKnight", name: "Sir Rotgrave", epithet: "Oathbound to the Rot", family: .undead, tier: 10,
        speed: 2.0, radius: 0.9, type: .poison, behavior: .melee, sprite: .enemyBossPlagueKnight, scale: 1.5,
        kit: BossKit(moves: [.cleave, .slam, .pools, .hunt], intensity: 4, tempo: 4.9, signature: .cleave))

    static let bossBloated = warlord(
        id: "boss.bloated", name: "The Bloated One", epithet: "What the Graves Left", family: .undead, tier: 11,
        speed: 1.4, radius: 1.2, type: .poison, behavior: .melee, sprite: .enemyBossBloated, scale: 1.6,
        kit: BossKit(moves: [.pools, .slam, .summon, .ring], intensity: 5, tempo: 4.8,
                     adds: "enemy.skeletonWarrior", signature: .pools))

    static let bossCinderjaw = warlord(
        id: "boss.cinderjaw", name: "Cinderjaw", epithet: "Oldest Hound of the Depths", family: .demon, tier: 13,
        speed: 3.1, radius: 1.0, type: .fire, behavior: .charger(range: 10, speed: 19, distance: 10),
        sprite: .enemyBossCinderjaw, scale: 1.4,
        kit: BossKit(moves: [.blink, .fan, .cleave, .pools], intensity: 5, tempo: 4.7, signature: .blink))

    static let bossMagma = warlord(
        id: "boss.magma", name: "The Magma Colossus", epithet: "Cooling from the Outside", family: .elemental, tier: 14,
        speed: 1.3, radius: 1.3, type: .fire, behavior: .melee, sprite: .enemyBossMagma, scale: 1.7,
        kit: BossKit(moves: [.slam, .meteors, .pools, .sweep], intensity: 6, tempo: 4.6, signature: .pools))

    static let bossPitDuke = warlord(
        id: "boss.pitDuke", name: "Azreth", epithet: "Duke of the Pit", family: .demon, tier: 15,
        speed: 2.2, radius: 1.0, type: .fire, behavior: .melee, sprite: .enemyBossPitDuke, scale: 1.55,
        kit: BossKit(moves: [.cleave, .blink, .hunt, .meteors], intensity: 6, tempo: 4.5, signature: .hunt))

    static let bossFracturedEye = warlord(
        id: "boss.fracturedEye", name: "The Fractured Eye", epithet: "Looking from Every Piece", family: .aberration,
        tier: 17, speed: 1.8, radius: 1.0, type: .arcane,
        behavior: .ranged(range: 9.5, projectileSpeed: 10, sprite: .projectileArcaneBolt),
        sprite: .enemyBossFracturedEye, scale: 1.5,
        kit: BossKit(moves: [.sweep, .ring, .hunt, .spiral], intensity: 7, tempo: 4.4, signature: .sweep))

    static let bossRiftweaver = warlord(
        id: "boss.riftweaver", name: "The Riftweaver", epithet: "Who Stitches the Sky Shut", family: .aberration,
        tier: 18, speed: 1.8, radius: 0.9, type: .arcane,
        behavior: .ranged(range: 9, projectileSpeed: 10, sprite: .projectileArcaneBolt),
        sprite: .enemyBossRiftweaver, scale: 1.5,
        kit: BossKit(moves: [.blink, .meteors, .hunt, .lanes, .summon], intensity: 7, tempo: 4.3,
                     adds: "enemy.voidling", signature: .blink))

    static let bossWarpedKnight = warlord(
        id: "boss.warpedKnight", name: "The Warped Knight", epithet: "Folded and Unfolded Wrong", family: .aberration,
        tier: 19, speed: 2.6, radius: 0.95, type: .arcane, behavior: .charger(range: 9, speed: 17, distance: 9),
        sprite: .enemyBossWarpedKnight, scale: 1.5,
        kit: BossKit(moves: [.blink, .cleave, .lanes, .slam], intensity: 8, tempo: 4.2, signature: .cleave))

    static let bossOathbreaker = warlord(
        id: "boss.oathbreaker", name: "The Oathbreaker", epithet: "Who Opened the Gate", family: .construct, tier: 21,
        speed: 2.1, radius: 1.0, type: .physical, behavior: .melee, sprite: .enemyBossOathbreaker, scale: 1.55,
        kit: BossKit(moves: [.cleave, .lanes, .blink, .slam, .hunt], intensity: 8, tempo: 4.1, signature: .lanes))

    static let bossSiegeTitan = warlord(
        id: "boss.siegeTitan", name: "The Siege Titan", epithet: "A Wall Told to Advance", family: .construct, tier: 22,
        speed: 1.4, radius: 1.3, type: .physical, behavior: .melee, sprite: .enemyBossSiegeTitan, scale: 1.7,
        kit: BossKit(moves: [.slam, .meteors, .sweep, .lanes, .pools], intensity: 9, tempo: 4.0, signature: .slam))

    static let bossBellkeeper = warlord(
        id: "boss.bellkeeper", name: "The Bellkeeper", epithet: "Who Rings for the Dead", family: .cultist, tier: 23,
        speed: 1.7, radius: 0.85, type: .holy,
        behavior: .ranged(range: 9, projectileSpeed: 9, sprite: .projectileBolt),
        sprite: .enemyBossBellkeeper, scale: 1.55,
        kit: BossKit(moves: [.ring, .meteors, .summon, .hunt, .spiral], intensity: 9, tempo: 3.95,
                     adds: "enemy.flagellant", signature: .ring))

    static let bossGildedRegent = warlord(
        id: "boss.gildedRegent", name: "The Gilded Regent", epithet: "Answering to No One", family: .construct, tier: 24,
        speed: 1.9, radius: 1.2, type: .holy, behavior: .melee, sprite: .enemyBossGildedRegent, scale: 1.7,
        kit: BossKit(moves: [.sweep, .cleave, .meteors, .lanes, .slam, .blink], intensity: 9, tempo: 3.9,
                     signature: .sweep))

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

    /// Every champion, easiest first.
    static let champions: [EnemyDefinition] = [
        bossPitBrute, bossWarchief, bossBogmother, bossDrownedKing, bossThornmaw, bossHollowStag, bossFrostfang,
        bossRimewitch, bossRimeTyrant, bossPlagueKnight, bossBloated, bossPlagueMonarch, bossCinderjaw, bossMagma,
        bossPitDuke, bossEmberLord, bossFracturedEye, bossRiftweaver, bossWarpedKnight, bossVoidmaw,
        bossOathbreaker, bossSiegeTitan, bossBellkeeper, bossGildedRegent, bossIronSaint, bossGraveWarden,
        bossAbyssalEcho,
    ]

    static let all: [EnemyDefinition] = goblinWarband + undeadHost + wildBeasts + demonLegion
        + citadelConstructs + aberrations + cultists + elementals + nightHunters + champions

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
            return elementals + [direWolf, animatedArmour, skeletonWarrior, boneHound] + nightHunters
        case .blightedKingdom:
            return cultists + undeadHost + nightHunters
        case .burningDepths:
            return demonLegion + [emberWisp, cultist, flagellant] + nightHunters
        case .shatteredRealm:
            return aberrations + [voidling, wraith, runeSentinel, impling, frostShard] + nightHunters
        case .fallenCitadel:
            return citadelConstructs + cultists + [skeletonWarrior, skeletonArcher, hobgoblin] + nightHunters
        case .gateOfRuin, .abyss:
            return all.filter { $0.rank != .boss }
        }
    }

    /// The champions a realm sends, in order: one for each boss wave, none twice, each a step up from the
    /// last, and the realm's own great champion at the end. (The Abyss has no end and sends them all.)
    static func bosses(for realm: RealmID) -> [EnemyKindID] {
        let list: [EnemyDefinition]
        switch realm {
        case .ashenWilds: list = [bossPitBrute, bossWarchief]
        case .drownedFen: list = [bossWarchief, bossBogmother, bossDrownedKing]
        case .hollowForest: list = [bossDrownedKing, bossThornmaw, bossHollowStag]
        case .frozenWastes: list = [bossHollowStag, bossFrostfang, bossRimewitch, bossRimeTyrant]
        case .blightedKingdom: list = [bossRimeTyrant, bossPlagueKnight, bossBloated, bossPlagueMonarch]
        case .burningDepths: list = [bossPlagueMonarch, bossCinderjaw, bossMagma, bossPitDuke, bossEmberLord]
        case .shatteredRealm: list = [bossEmberLord, bossFracturedEye, bossRiftweaver, bossWarpedKnight, bossVoidmaw]
        case .fallenCitadel:
            list = [bossVoidmaw, bossOathbreaker, bossSiegeTitan, bossBellkeeper, bossGildedRegent, bossIronSaint]
        case .gateOfRuin:
            list = [bossRimeTyrant, bossPlagueMonarch, bossEmberLord, bossVoidmaw, bossIronSaint, bossGraveWarden]
        case .abyss: list = champions
        }
        return list.map(\.id)
    }
}
