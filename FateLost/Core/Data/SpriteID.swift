import Foundation

/// Stable, art-agnostic name for a visual.
///
/// Gameplay and content data refer to sprites only through these ids.
/// `SpriteCatalog` resolves an id to a texture: a bundled asset of the same
/// name when one exists, otherwise generated placeholder art. Swapping in
/// final artwork is therefore an asset-catalog change, never a code change.
struct SpriteID: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}

extension SpriteID {
    // Player
    static let playerAdventurer: SpriteID = "player.adventurer"
    static let shadow: SpriteID = "fx.shadow"

    // Enemies
    static let enemyGoblin: SpriteID = "enemy.goblin"
    static let enemyGoblinHooded: SpriteID = "enemy.goblin.hooded"
    static let enemyGoblinHelmed: SpriteID = "enemy.goblin.helmed"
    static let enemyGoblinSkulker: SpriteID = "enemy.goblinSkulker"
    static let enemyGoblinSkulkerPale: SpriteID = "enemy.goblinSkulker.pale"
    static let enemyGoblinSpearman: SpriteID = "enemy.goblinSpearman"
    static let enemyGoblinSpearmanRed: SpriteID = "enemy.goblinSpearman.red"
    static let enemyGoblinBrute: SpriteID = "enemy.goblinBrute"
    static let enemyGoblinBruteScarred: SpriteID = "enemy.goblinBrute.scarred"
    static let enemyGoblinSapper: SpriteID = "enemy.goblinSapper"

    // The wider bestiary, drawn by tools/art/bestiary.py.
    static let enemyGoblinArcher: SpriteID = "enemy.goblinArcher"
    static let enemyGoblinShaman: SpriteID = "enemy.goblinShaman"
    static let enemyHobgoblin: SpriteID = "enemy.hobgoblin"
    static let enemySkeletonWarrior: SpriteID = "enemy.skeletonWarrior"
    static let enemySkeletonArcherFoe: SpriteID = "enemy.skeletonArcherFoe"
    static let enemyBoneHound: SpriteID = "enemy.boneHound"
    static let enemyWraith: SpriteID = "enemy.wraith"
    static let enemyNecromancer: SpriteID = "enemy.necromancer"
    static let enemyRotHulk: SpriteID = "enemy.rotHulk"
    static let enemyDireWolf: SpriteID = "enemy.direWolf"
    static let enemyGiantSpider: SpriteID = "enemy.giantSpider"
    static let enemyCorruptedStag: SpriteID = "enemy.corruptedStag"
    static let enemyImpling: SpriteID = "enemy.impling"
    static let enemyHornedFiend: SpriteID = "enemy.hornedFiend"
    static let enemyEmberHound: SpriteID = "enemy.emberHound"
    static let enemyBrimstoneBrute: SpriteID = "enemy.brimstoneBrute"
    static let enemyAnimatedArmour: SpriteID = "enemy.animatedArmour"
    static let enemyRuneSentinel: SpriteID = "enemy.runeSentinel"
    static let enemySiegeGolem: SpriteID = "enemy.siegeGolem"
    static let enemyVoidling: SpriteID = "enemy.voidling"
    static let enemyGazer: SpriteID = "enemy.gazer"
    static let enemyFleshHorror: SpriteID = "enemy.fleshHorror"
    static let enemyCultist: SpriteID = "enemy.cultist"
    static let enemyFlagellant: SpriteID = "enemy.flagellant"
    static let enemyCultLeader: SpriteID = "enemy.cultLeader"
    static let enemyFrostShard: SpriteID = "enemy.frostShard"
    static let enemyEmberWisp: SpriteID = "enemy.emberWisp"
    static let enemyIceGolem: SpriteID = "enemy.iceGolem"
    static let enemyBossWarchief: SpriteID = "enemy.bossWarchief"
    static let enemyBossDrownedKing: SpriteID = "enemy.bossDrownedKing"
    static let enemyBossHollowStag: SpriteID = "enemy.bossHollowStag"
    static let enemyBossRimeTyrant: SpriteID = "enemy.bossRimeTyrant"
    static let enemyBossPlagueMonarch: SpriteID = "enemy.bossPlagueMonarch"
    static let enemyBossEmberLord: SpriteID = "enemy.bossEmberLord"
    static let enemyBossVoidmaw: SpriteID = "enemy.bossVoidmaw"
    static let enemyBossIronSaint: SpriteID = "enemy.bossIronSaint"
    static let enemyBossGraveWarden: SpriteID = "enemy.bossGraveWarden"
    static let enemyBossAbyssalEcho: SpriteID = "enemy.bossAbyssalEcho"

    // Allies and forms
    static let allySkeleton: SpriteID = "ally.skeleton"
    static let allySkeletonArcher: SpriteID = "ally.skeleton.archer"
    static let allySkeletonBrute: SpriteID = "ally.skeleton.brute"
    static let allyBoneColossus: SpriteID = "ally.boneColossus"
    static let allyTigerWhite: SpriteID = "ally.tiger.white"
    static let allyWolfBlack: SpriteID = "ally.wolf.black"
    static let allyHellhound: SpriteID = "ally.hellhound"
    static let allyPitFiend: SpriteID = "ally.pitFiend"
    static let formWarBear: SpriteID = "form.warBear"
    static let formDireWolf: SpriteID = "form.direWolf"
    static let allyBear: SpriteID = "ally.bear"
    static let allyTiger: SpriteID = "ally.tiger"
    static let allyOwl: SpriteID = "ally.owl"
    static let allyImp: SpriteID = "ally.imp"
    static let allyWolf: SpriteID = "ally.wolf"
    static let allyTreant: SpriteID = "ally.treant"
    static let allyBlade: SpriteID = "ally.blade"
    /// A glowing mote, tinted per use.
    static let allyWisp: SpriteID = "ally.wisp"

    // Weapons (held and icon)
    static let weaponSword: SpriteID = "weapon.sword"
    static let weaponBow: SpriteID = "weapon.bow"
    static let weaponStaff: SpriteID = "weapon.staff"
    static let weaponSai: SpriteID = "weapon.sai"
    static let weaponKatana: SpriteID = "weapon.katana"
    static let weaponDualDaggers: SpriteID = "weapon.dualDaggers"
    static let weaponBoStaff: SpriteID = "weapon.boStaff"
    static let weaponFlail: SpriteID = "weapon.flail"
    static let weaponWarHammer: SpriteID = "weapon.warHammer"
    static let weaponBoomerang: SpriteID = "weapon.boomerang"
    static let weaponEmberWand: SpriteID = "weapon.emberWand"
    static let weaponRimeWand: SpriteID = "weapon.rimeWand"
    static let weaponStormWand: SpriteID = "weapon.stormWand"
    static let projectileBoomerang: SpriteID = "projectile.boomerang"
    static let projectileEmberBolt: SpriteID = "projectile.emberBolt"
    static let projectileFrostBolt: SpriteID = "projectile.frostBolt"
    static let projectileStormBolt: SpriteID = "projectile.stormBolt"

    // Projectiles
    static let projectileArrow: SpriteID = "projectile.arrow"
    static let projectileArcaneBolt: SpriteID = "projectile.arcaneBolt"
    static let projectileKnife: SpriteID = "projectile.knife"
    static let projectileShard: SpriteID = "projectile.shard"
    /// A white bolt of energy, tinted by its effect's style.
    static let projectileBolt: SpriteID = "projectile.bolt"

    // Decorations
    static let decorDeadTree: SpriteID = "decor.deadTree"
    static let decorDeadTreeSmall: SpriteID = "decor.deadTreeSmall"
    static let decorGravestone: SpriteID = "decor.gravestone"
    static let decorGraveCross: SpriteID = "decor.graveCross"
    static let decorRuinedPillar: SpriteID = "decor.ruinedPillar"
    static let decorRuinedWall: SpriteID = "decor.ruinedWall"
    static let decorBrokenCart: SpriteID = "decor.brokenCart"
    static let decorCampfire: SpriteID = "decor.campfire"
    static let decorOldShrine: SpriteID = "decor.oldShrine"
    static let decorRock: SpriteID = "decor.rock"
    static let decorGrassTuft: SpriteID = "decor.grassTuft"
    static let decorBones: SpriteID = "decor.bones"

    // Set dressing that belongs to one realm, drawn by tools/art/props.py.
    static let decorReeds: SpriteID = "decor.reeds"
    static let decorStandingWater: SpriteID = "decor.standingWater"
    static let decorBogStump: SpriteID = "decor.bogStump"
    static let decorPineTree: SpriteID = "decor.pineTree"
    static let decorForestStump: SpriteID = "decor.forestStump"
    static let decorMushrooms: SpriteID = "decor.mushrooms"
    static let decorIceSpire: SpriteID = "decor.iceSpire"
    static let decorFrozenCorpse: SpriteID = "decor.frozenCorpse"
    static let decorGibbet: SpriteID = "decor.gibbet"
    static let decorWarBanner: SpriteID = "decor.warBanner"
    static let decorLavaVent: SpriteID = "decor.lavaVent"
    static let decorObsidianShard: SpriteID = "decor.obsidianShard"
    static let decorVoidRift: SpriteID = "decor.voidRift"
    static let decorFloatingStone: SpriteID = "decor.floatingStone"
    static let decorBrokenStatue: SpriteID = "decor.brokenStatue"
    static let decorBarricade: SpriteID = "decor.barricade"
    static let decorSkullPile: SpriteID = "decor.skullPile"
    static let decorBlackObelisk: SpriteID = "decor.blackObelisk"
    static let dropVial: SpriteID = "drop.vial"
    static let dropMagnet: SpriteID = "drop.magnet"
    static let dropChestCache: SpriteID = "drop.chestCache"
    static let dropChestChest: SpriteID = "drop.chestChest"
    static let dropChestHoard: SpriteID = "drop.chestHoard"
    static let shrineBlood: SpriteID = "shrine.blood"
    static let shrineFortune: SpriteID = "shrine.fortune"
    static let shrineRuin: SpriteID = "shrine.ruin"
    static let decorPlagueBell: SpriteID = "decor.plagueBell"
    static let decorMoltenChain: SpriteID = "decor.moltenChain"
    static let decorBrokenStair: SpriteID = "decor.brokenStair"
    static let decorSiegeRam: SpriteID = "decor.siegeRam"
    static let decorRuinedArch: SpriteID = "decor.ruinedArch"
    static let decorHollowThrone: SpriteID = "decor.hollowThrone"

    // Effects
    static let fxGlow: SpriteID = "fx.glow"
    static let fxFlame: SpriteID = "fx.flame"
    static let fxAshFlake: SpriteID = "fx.ashFlake"
    static let fxVignette: SpriteID = "fx.vignette"
    /// Crescent sweep of a melee swing, drawn pointing along +x.
    static let fxSlash: SpriteID = "fx.slash"
    /// Small four-point star for hit sparks.
    static let fxSpark: SpriteID = "fx.spark"
    /// Circle outline, for hitboxes and shockwaves.
    static let fxRing: SpriteID = "fx.ring"
    /// Stain left on the ground where an enemy fell. Drawn white; tinted
    /// per enemy.
    static let fxSplat: SpriteID = "fx.splat"
    /// An ember of experience lying on the ground.
    static let fxEmber: SpriteID = "fx.ember"
    /// A wedge pointing along +x, for cone attacks.
    static let fxCone: SpriteID = "fx.cone"
    /// Soft disc for zones, drawn white and tinted.
    static let fxDisc: SpriteID = "fx.disc"
    /// Tall shaft of light for impacts from above and levelling up.
    static let fxPillar: SpriteID = "fx.pillar"
}
