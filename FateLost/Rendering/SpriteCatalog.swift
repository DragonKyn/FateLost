import SpriteKit
import UIKit

/// Resolves `SpriteID`s to textures for one scene.
///
/// Resolution order: an image in the asset catalogue named exactly like the
/// id (e.g. "decor.deadTree"), then generated placeholder art. All resolved
/// images are packed into a single runtime texture atlas so SpriteKit can
/// batch sprites that share it into few draw calls — important once hundreds
/// of enemies are on screen.
///
/// Sprites are always created at the image's *point* size, so a final asset
/// only needs the right dimensions and anchor to drop in.
@MainActor
final class SpriteCatalog {
    private struct Entry {
        let texture: SKTexture
        let size: CGSize
        let anchor: CGPoint
    }

    private var entries: [SpriteID: Entry] = [:]
    private let fallbackAnchor = CGPoint(x: 0.5, y: 0.1)

    init(preloading ids: [SpriteID]) {
        var images: [String: UIImage] = [:]
        var meta: [SpriteID: (size: CGSize, anchor: CGPoint)] = [:]

        for id in ids {
            if let asset = UIImage(named: id.rawValue) {
                images[id.rawValue] = asset
                meta[id] = (asset.size, fallbackAnchor)
            } else if let placeholder = PlaceholderArt.sprite(for: id) {
                images[id.rawValue] = placeholder.image
                meta[id] = (placeholder.image.size, placeholder.anchor)
            }
        }

        let atlas = SKTextureAtlas(dictionary: images)
        for (id, info) in meta {
            let texture = atlas.textureNamed(id.rawValue)
            entries[id] = Entry(texture: texture, size: info.size, anchor: info.anchor)
        }
    }

    func texture(_ id: SpriteID) -> SKTexture? {
        entries[id]?.texture
    }

    func size(_ id: SpriteID) -> CGSize {
        entries[id]?.size ?? CGSize(width: 16, height: 16)
    }

    func anchor(_ id: SpriteID) -> CGPoint {
        entries[id]?.anchor ?? fallbackAnchor
    }

    /// A new sprite with the id's texture, point size and anchor. Missing ids
    /// produce a magenta square so they are obvious during development.
    func makeSprite(_ id: SpriteID) -> SKSpriteNode {
        guard let entry = entries[id] else {
            return SKSpriteNode(color: .magenta, size: CGSize(width: 16, height: 16))
        }
        let sprite = SKSpriteNode(texture: entry.texture, size: entry.size)
        sprite.anchorPoint = entry.anchor
        return sprite
    }

    /// Every sprite the gameplay scene may use, preloaded up front so no
    /// texture is generated mid-run.
    static let gameplaySprites: [SpriteID] = [
        .playerAdventurer, .shadow,
        .enemyGoblin, .enemyGoblinHooded, .enemyGoblinHelmed, .enemyGoblinSkulker, .enemyGoblinSkulkerPale,
        .enemyGoblinSpearman, .enemyGoblinSpearmanRed, .enemyGoblinBrute, .enemyGoblinBruteScarred,
        .enemyGoblinSapper,
        .enemyGoblinArcher, .enemyGoblinShaman, .enemyHobgoblin, .enemySkeletonWarrior, .enemySkeletonArcherFoe,
        .enemyBoneHound, .enemyWraith, .enemyNecromancer, .enemyRotHulk, .enemyDireWolf, .enemyGiantSpider,
        .enemyCorruptedStag, .enemyImpling, .enemyHornedFiend, .enemyEmberHound, .enemyBrimstoneBrute,
        .enemyAnimatedArmour, .enemyRuneSentinel, .enemySiegeGolem, .enemyVoidling, .enemyGazer, .enemyFleshHorror,
        .enemyCultist, .enemyFlagellant, .enemyCultLeader, .enemyFrostShard, .enemyEmberWisp, .enemyIceGolem,
        .enemyBossWarchief, .enemyBossDrownedKing, .enemyBossHollowStag, .enemyBossRimeTyrant,
        .enemyBossPlagueMonarch, .enemyBossEmberLord, .enemyBossVoidmaw, .enemyBossIronSaint,
        .enemyBossGraveWarden, .enemyBossAbyssalEcho,
        .allySkeleton, .allyBear, .allyTiger, .allyOwl, .allyImp, .allyWolf, .allyTreant, .allyBlade, .allyWisp,
        .allySkeletonArcher, .allySkeletonBrute, .allyBoneColossus, .allyTigerWhite, .allyWolfBlack, .allyHellhound,
        .allyPitFiend, .formWarBear, .formDireWolf,
        .weaponSword, .weaponBow, .weaponStaff,
        .projectileArrow, .projectileArcaneBolt, .projectileKnife, .projectileShard, .projectileBolt,
        .fxEmber, .fxCone, .fxDisc, .fxPillar,
        .decorDeadTree, .decorDeadTreeSmall, .decorGravestone, .decorGraveCross,
        .decorRuinedPillar, .decorRuinedWall, .decorBrokenCart, .decorCampfire,
        .decorOldShrine, .decorRock, .decorGrassTuft, .decorBones,
        .decorReeds, .decorStandingWater, .decorBogStump, .decorPineTree, .decorForestStump, .decorMushrooms,
        .decorIceSpire, .decorFrozenCorpse, .decorGibbet, .decorWarBanner, .decorLavaVent, .decorObsidianShard,
        .decorVoidRift, .decorFloatingStone, .decorBrokenStatue, .decorBarricade, .decorSkullPile,
        .decorBlackObelisk,
        .fxGlow, .fxFlame, .fxAshFlake, .fxSlash, .fxSpark, .fxRing, .fxSplat,
    ]
}
