import UIKit

/// Procedurally drawn stand-in art.
///
/// Every sprite the game needs is drawn here at device resolution so the game
/// is fully playable and readable before final artwork exists. Nothing outside
/// `SpriteCatalog` calls this directly; when a real asset with the same
/// `SpriteID` is added to the asset catalogue, it replaces the placeholder
/// automatically.
///
/// Drawing uses UIKit coordinates (origin top-left, y down).
enum PlaceholderArt {
    struct Sprite {
        let image: UIImage
        /// Normalised anchor, SpriteKit convention (y up). For standing
        /// objects this is the point that touches the ground.
        let anchor: CGPoint
    }

    // MARK: - Lookup

    static func sprite(for id: SpriteID) -> Sprite? {
        switch id {
        case .playerAdventurer: return hero(.standard)
        case .shadow: return shadow()
        case .enemyGoblin: return goblin()
        case .enemyGoblinHooded: return goblin(palette: .moss, headgear: .hood(0x2E2A26))
        case .enemyGoblinHelmed: return goblin(palette: .ochre, headgear: .helmet(0x6E6A62))
        case .enemyGoblinSkulker: return skulker(palette: .moss, hood: 0x1E1C22)
        case .enemyGoblinSkulkerPale: return skulker(palette: .pale, hood: 0x3A2230)
        case .enemyGoblinSpearman: return spearman(palette: .green, crest: 0x8A7A5A)
        case .enemyGoblinSpearmanRed: return spearman(palette: .ochre, crest: 0x8A2A22)
        case .enemyGoblinBrute: return brute(palette: .green, scarred: false)
        case .enemyGoblinBruteScarred: return brute(palette: .moss, scarred: true)
        case .enemyGoblinSapper: return sapper()
        case .enemyGoblinArcher: return goblinArcher()
        case .enemyGoblinShaman: return goblinShaman()
        case .enemyHobgoblin: return hobgoblin()
        case .enemySkeletonWarrior: return skeletonWarrior()
        case .enemySkeletonArcherFoe: return skeletonArcherFoe()
        case .enemyBoneHound: return boneHound()
        case .enemyWraith: return wraith()
        case .enemyNecromancer: return necromancer()
        case .enemyRotHulk: return rotHulk()
        case .enemyDireWolf: return direWolf()
        case .enemyGiantSpider: return giantSpider()
        case .enemyCorruptedStag: return corruptedStag()
        case .enemyImpling: return impling()
        case .enemyHornedFiend: return hornedFiend()
        case .enemyEmberHound: return emberHound()
        case .enemyBrimstoneBrute: return brimstoneBrute()
        case .enemyAnimatedArmour: return animatedArmour()
        case .enemyRuneSentinel: return runeSentinel()
        case .enemySiegeGolem: return siegeGolem()
        case .enemyVoidling: return voidling()
        case .enemyGazer: return gazer()
        case .enemyFleshHorror: return fleshHorror()
        case .enemyCultist: return cultist()
        case .enemyFlagellant: return flagellant()
        case .enemyCultLeader: return cultLeader()
        case .enemyFrostShard: return frostShard()
        case .enemyEmberWisp: return emberWisp()
        case .enemyIceGolem: return iceGolem()
        case .enemyBossWarchief: return bossWarchief()
        case .enemyBossDrownedKing: return bossDrownedKing()
        case .enemyBossHollowStag: return bossHollowStag()
        case .enemyBossRimeTyrant: return bossRimeTyrant()
        case .enemyBossPlagueMonarch: return bossPlagueMonarch()
        case .enemyBossEmberLord: return bossEmberLord()
        case .enemyBossVoidmaw: return bossVoidmaw()
        case .enemyBossIronSaint: return bossIronSaint()
        case .enemyBossGraveWarden: return bossGraveWarden()
        case .enemyBossAbyssalEcho: return bossAbyssalEcho()
        case .allySkeleton: return skeleton()
        case .allySkeletonArcher: return skeletonArcher()
        case .allySkeletonBrute: return skeletonBrute()
        case .allyBoneColossus: return boneColossus()
        case .allyTigerWhite: return tigerWhite()
        case .allyWolfBlack: return wolfBlack()
        case .allyHellhound: return hellhound()
        case .allyPitFiend: return pitFiend()
        case .formWarBear: return warBearForm()
        case .formDireWolf: return direWolfForm()
        case .allyBear: return bear()
        case .allyTiger: return tiger()
        case .allyOwl: return owl()
        case .allyImp: return imp()
        case .allyWolf: return wolf()
        case .allyTreant: return treant()
        case .allyBlade: return orbitingBlade()
        case .allyWisp: return radialDot(size: 26)
        case .projectileKnife: return knife()
        case .projectileShard: return shard()
        case .projectileBolt: return energyBolt()
        case .fxEmber: return ember()
        case .fxCone: return cone()
        case .fxDisc: return disc()
        case .fxPillar: return pillar()
        case .weaponSword: return sword()
        case .weaponBow: return bow()
        case .weaponStaff: return staff()
        case .weaponSai: return sai()
        case .weaponKatana: return katana()
        case .weaponDualDaggers: return dualDaggers()
        case .weaponBoStaff: return boStaff()
        case .weaponFlail: return flail()
        case .weaponWarHammer: return warHammer()
        case .weaponBoomerang: return boomerang()
        case .weaponEmberWand: return emberWand()
        case .weaponRimeWand: return rimeWand()
        case .weaponStormWand: return stormWand()
        case .projectileBoomerang: return projectileBoomerang()
        case .projectileEmberBolt: return projectileEmberBolt()
        case .projectileFrostBolt: return projectileFrostBolt()
        case .projectileStormBolt: return projectileStormBolt()
        case .projectileArrow: return arrow()
        case .projectileArcaneBolt: return arcaneBolt()
        case .decorDeadTree: return deadTree(size: CGSize(width: 84, height: 120), seed: 11, trunk: 8, length: 36)
        case .decorDeadTreeSmall: return deadTree(size: CGSize(width: 54, height: 74), seed: 29, trunk: 5, length: 22)
        case .decorGravestone: return gravestone()
        case .decorGraveCross: return graveCross()
        case .decorRuinedPillar: return ruinedPillar()
        case .decorRuinedWall: return ruinedWall()
        case .decorBrokenCart: return brokenCart()
        case .decorCampfire: return campfire()
        case .decorOldShrine: return oldShrine()
        case .decorRock: return rock()
        case .decorGrassTuft: return grassTuft()
        case .decorBones: return bones()
        case .decorReeds: return reeds()
        case .decorStandingWater: return standingWater()
        case .decorBogStump: return bogStump()
        case .decorPineTree: return pineTree()
        case .decorForestStump: return forestStump()
        case .decorMushrooms: return mushrooms()
        case .decorIceSpire: return iceSpire()
        case .decorFrozenCorpse: return frozenCorpse()
        case .decorGibbet: return gibbet()
        case .decorWarBanner: return warBanner()
        case .decorLavaVent: return lavaVent()
        case .decorObsidianShard: return obsidianShard()
        case .decorVoidRift: return voidRift()
        case .decorFloatingStone: return floatingStone()
        case .decorBrokenStatue: return brokenStatue()
        case .decorBarricade: return barricade()
        case .decorSkullPile: return skullPile()
        case .decorBlackObelisk: return blackObelisk()
        case .dropVial: return dropVial()
        case .dropMagnet: return dropMagnet()
        case .dropChestCache: return dropChestCache()
        case .dropChestChest: return dropChestChest()
        case .dropChestHoard: return dropChestHoard()
        case .shrineBlood: return shrineBlood()
        case .shrineFortune: return shrineFortune()
        case .shrineRuin: return shrineRuin()
        case .decorPlagueBell: return plagueBell()
        case .decorMoltenChain: return moltenChain()
        case .decorBrokenStair: return brokenStair()
        case .decorSiegeRam: return siegeRam()
        case .decorRuinedArch: return ruinedArch()
        case .decorHollowThrone: return hollowThrone()
        case .fxGlow: return radialDot(size: 64)
        case .fxAshFlake: return radialDot(size: 8)
        case .fxFlame: return flame()
        case .fxSlash: return slash()
        case .fxSpark: return spark()
        case .fxRing: return ring()
        case .fxSplat: return splat()
        default: return nil
        }
    }

    // MARK: - Characters

    private static func shadow() -> Sprite {
        let size = CGSize(width: 44, height: 18)
        let image = render(size) { ctx in
            ctx.saveGState()
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: 1, y: size.height / size.width)
            radialGradient(ctx, center: .zero, radius: size.width / 2,
                           inner: UIColor(white: 0, alpha: 0.55), outer: UIColor(white: 0, alpha: 0))
            ctx.restoreGState()
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    // MARK: - Weapons and projectiles

    private static func sword() -> Sprite {
        let size = CGSize(width: 12, height: 38)
        let image = render(size) { ctx in
            fillPolygon(ctx, [CGPoint(x: 4.3, y: 25), CGPoint(x: 6, y: 1.5), CGPoint(x: 7.7, y: 25)],
                        UIColor(rgb: 0xC9CED6))
            stroke(ctx, from: CGPoint(x: 6, y: 4), to: CGPoint(x: 6, y: 24), UIColor(rgb: 0x8E949C), width: 0.8)
            fill(ctx, CGRect(x: 1, y: 24.5, width: 10, height: 2.5), UIColor(rgb: 0x8C7A55))
            fill(ctx, CGRect(x: 5, y: 27, width: 2.2, height: 7.5), UIColor(rgb: 0x4A3322))
            ctx.setFillColor(UIColor(rgb: 0x8C7A55).cgColor)
            ctx.fillEllipse(in: CGRect(x: 4.4, y: 34, width: 3.4, height: 3.4))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.2))
    }

    private static func bow() -> Sprite {
        let size = CGSize(width: 18, height: 46)
        let image = render(size) { ctx in
            ctx.setStrokeColor(UIColor(rgb: 0x6B4A2A).cgColor)
            ctx.setLineWidth(3)
            ctx.setLineCap(.round)
            // The limbs bow outward toward the target (+x); the string sits
            // on the archer's side.
            ctx.move(to: CGPoint(x: 6, y: 3))
            ctx.addQuadCurve(to: CGPoint(x: 6, y: 43), control: CGPoint(x: 24, y: 23))
            ctx.strokePath()
            stroke(ctx, from: CGPoint(x: 6, y: 3), to: CGPoint(x: 6, y: 43), UIColor(rgb: 0xD8D0C0), width: 0.8)
            fill(ctx, CGRect(x: 13.2, y: 19.5, width: 3.4, height: 7), UIColor(rgb: 0x3A2818))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    private static func staff() -> Sprite {
        let size = CGSize(width: 16, height: 62)
        let image = render(size) { ctx in
            fill(ctx, CGRect(x: 6.8, y: 12, width: 2.6, height: 49), UIColor(rgb: 0x5A3E26))
            radialGradient(ctx, center: CGPoint(x: 8, y: 8), radius: 8,
                           inner: UIColor(rgb: 0xB07CFF, alpha: 0.7), outer: UIColor(rgb: 0xB07CFF, alpha: 0))
            ctx.setFillColor(UIColor(rgb: 0xD7BFFF).cgColor)
            ctx.fillEllipse(in: CGRect(x: 4.5, y: 4.5, width: 7, height: 7))
            stroke(ctx, from: CGPoint(x: 5, y: 13), to: CGPoint(x: 3.5, y: 6), UIColor(rgb: 0x5A3E26), width: 1.4)
            stroke(ctx, from: CGPoint(x: 11, y: 13), to: CGPoint(x: 12.5, y: 6), UIColor(rgb: 0x5A3E26), width: 1.4)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.2))
    }

    private static func arrow() -> Sprite {
        let size = CGSize(width: 30, height: 8)
        let image = render(size) { ctx in
            stroke(ctx, from: CGPoint(x: 4, y: 4), to: CGPoint(x: 24, y: 4), UIColor(rgb: 0x8A6A44), width: 1.4)
            fillPolygon(ctx, [CGPoint(x: 23, y: 1.2), CGPoint(x: 29.5, y: 4), CGPoint(x: 23, y: 6.8)],
                        UIColor(rgb: 0xB8BEC6))
            fillPolygon(ctx, [CGPoint(x: 1, y: 1), CGPoint(x: 7, y: 4), CGPoint(x: 1, y: 7)],
                        UIColor(rgb: 0xC9C0B0))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    private static func arcaneBolt() -> Sprite {
        let size = CGSize(width: 22, height: 22)
        let image = render(size) { ctx in
            radialGradient(ctx, center: CGPoint(x: 11, y: 11), radius: 11,
                           inner: UIColor(rgb: 0xF4ECFF), outer: UIColor(rgb: 0x8A4CFF, alpha: 0))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    // MARK: - Decorations

    private static func deadTree(size: CGSize, seed: UInt64, trunk: CGFloat, length: CGFloat) -> Sprite {
        let baseY = size.height - 4
        let image = render(size) { ctx in
            var random = SeededRandom(seed: seed)
            let bark = UIColor(rgb: 0x2B231E)
            let highlight = UIColor(rgb: 0x4A3C32)
            ctx.setLineCap(.round)

            // Root flare
            for offset in [-1.0, 1.0] {
                stroke(ctx, from: CGPoint(x: size.width / 2, y: baseY - 4),
                       to: CGPoint(x: size.width / 2 + CGFloat(offset) * trunk * 1.1, y: baseY),
                       bark, width: trunk * 0.6)
            }

            func branch(from start: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, depth: Int) {
                let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
                stroke(ctx, from: start, to: end, bark, width: width)
                stroke(ctx, from: start + CGPoint(x: -width * 0.25, y: 0),
                       to: end + CGPoint(x: -width * 0.25, y: 0), highlight, width: max(0.6, width * 0.25))
                guard depth > 0 else { return }
                let children = depth > 2 ? 2 : Int(random.range(1, 3.99))
                for index in 0..<children {
                    let side: CGFloat = index % 2 == 0 ? -1 : 1
                    let spread = CGFloat(random.range(0.3, 0.75)) * side
                    branch(from: end, angle: angle + spread,
                           length: length * CGFloat(random.range(0.62, 0.8)),
                           width: width * 0.66, depth: depth - 1)
                }
            }
            branch(from: CGPoint(x: size.width / 2, y: baseY), angle: -.pi / 2 + CGFloat(random.range(-0.08, 0.08)),
                   length: length, width: trunk, depth: 4)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - baseY) / size.height))
    }

    private static func gravestone() -> Sprite {
        let size = CGSize(width: 30, height: 40)
        let baseY: CGFloat = 37
        let image = render(size) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 1, y: baseY - 3, width: 28, height: 6))
            let slab = UIBezierPath(roundedRect: CGRect(x: 4, y: 5, width: 22, height: baseY - 5),
                                    byRoundingCorners: [.topLeft, .topRight],
                                    cornerRadii: CGSize(width: 11, height: 11))
            ctx.setFillColor(UIColor(rgb: 0x6C6A70).cgColor)
            ctx.addPath(slab.cgPath)
            ctx.fillPath()
            fill(ctx, CGRect(x: 18, y: 10, width: 8, height: baseY - 10), UIColor(rgb: 0x55535A))
            ctx.setStrokeColor(UIColor(rgb: 0x2A282C).cgColor)
            ctx.setLineWidth(1.1)
            ctx.addPath(slab.cgPath)
            ctx.strokePath()
            stroke(ctx, from: CGPoint(x: 11, y: 12), to: CGPoint(x: 14, y: 19), UIColor(rgb: 0x3A383C), width: 0.9)
            stroke(ctx, from: CGPoint(x: 14, y: 19), to: CGPoint(x: 12, y: 25), UIColor(rgb: 0x3A383C), width: 0.9)
            fill(ctx, CGRect(x: 5, y: baseY - 4, width: 9, height: 3), UIColor(rgb: 0x4D5A36))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - baseY) / size.height))
    }

    private static func graveCross() -> Sprite {
        let size = CGSize(width: 26, height: 44)
        let baseY: CGFloat = 41
        let image = render(size) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 3, y: baseY - 3, width: 20, height: 6))
            let stone = UIColor(rgb: 0x5E5A56)
            let outline = UIColor(rgb: 0x272422)
            let vertical = CGRect(x: 10.5, y: 3, width: 5, height: baseY - 3)
            let horizontal = CGRect(x: 4, y: 11, width: 18, height: 5)
            fill(ctx, vertical, stone)
            fill(ctx, horizontal, stone)
            fill(ctx, CGRect(x: 13.5, y: 3, width: 2, height: baseY - 3), UIColor(rgb: 0x4A4744))
            ctx.setStrokeColor(outline.cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(vertical)
            ctx.stroke(horizontal)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - baseY) / size.height))
    }

    private static func ruinedPillar() -> Sprite {
        let size = CGSize(width: 36, height: 80)
        let baseY: CGFloat = 76
        let image = render(size) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 1, y: baseY - 4, width: 34, height: 8))
            fill(ctx, CGRect(x: 3, y: baseY - 8, width: 30, height: 8), UIColor(rgb: 0x6A645B))
            let shaft = [CGPoint(x: 8, y: baseY - 8), CGPoint(x: 8, y: 17), CGPoint(x: 12, y: 10),
                         CGPoint(x: 16, y: 15), CGPoint(x: 21, y: 6), CGPoint(x: 25, y: 13),
                         CGPoint(x: 28, y: 10), CGPoint(x: 28, y: baseY - 8)]
            fillPolygon(ctx, shaft, UIColor(rgb: 0x7A746A))
            fill(ctx, CGRect(x: 21, y: 13, width: 7, height: baseY - 21), UIColor(rgb: 0x5F5A52))
            for x in [13.0, 18.0, 23.0] {
                stroke(ctx, from: CGPoint(x: x, y: 20), to: CGPoint(x: x, y: baseY - 10),
                       UIColor(rgb: 0x5A554D), width: 0.9)
            }
            strokePolygon(ctx, shaft, UIColor(rgb: 0x2E2A26), width: 1.1)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - baseY) / size.height))
    }

    private static func ruinedWall() -> Sprite {
        let size = CGSize(width: 90, height: 60)
        let baseY: CGFloat = 56
        let image = render(size) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 2, y: baseY - 5, width: 86, height: 10))
            let wall = [CGPoint(x: 5, y: baseY), CGPoint(x: 5, y: 20), CGPoint(x: 14, y: 16),
                        CGPoint(x: 22, y: 24), CGPoint(x: 33, y: 12), CGPoint(x: 44, y: 22),
                        CGPoint(x: 56, y: 30), CGPoint(x: 66, y: 26), CGPoint(x: 76, y: 36),
                        CGPoint(x: 85, y: 34), CGPoint(x: 85, y: baseY)]
            fillPolygon(ctx, wall, UIColor(rgb: 0x6E675E))
            ctx.saveGState()
            ctx.addPath(polygonPath(wall))
            ctx.clip()
            let mortar = UIColor(rgb: 0x4E4841)
            var row = 0
            var y = baseY - 7
            while y > 8 {
                stroke(ctx, from: CGPoint(x: 0, y: y), to: CGPoint(x: size.width, y: y), mortar, width: 0.9)
                var x: CGFloat = row % 2 == 0 ? 10 : 4
                while x < size.width {
                    stroke(ctx, from: CGPoint(x: x, y: y), to: CGPoint(x: x, y: y + 7), mortar, width: 0.9)
                    x += 13
                }
                y -= 7
                row += 1
            }
            ctx.restoreGState()
            strokePolygon(ctx, wall, UIColor(rgb: 0x2E2A26), width: 1.1)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - baseY) / size.height))
    }

    private static func brokenCart() -> Sprite {
        let size = CGSize(width: 80, height: 52)
        let baseY: CGFloat = 48
        let image = render(size) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 4, y: baseY - 6, width: 72, height: 12))
            let wood = UIColor(rgb: 0x5A4128)
            let dark = UIColor(rgb: 0x3A2A1A)
            let bed = [CGPoint(x: 8, y: 30), CGPoint(x: 52, y: 18), CGPoint(x: 58, y: 30), CGPoint(x: 14, y: 42)]
            fillPolygon(ctx, bed, wood)
            for t in [0.25, 0.5, 0.75] {
                let a = bed[0].lerp(to: bed[1], t: CGFloat(t))
                let b = bed[3].lerp(to: bed[2], t: CGFloat(t))
                stroke(ctx, from: a, to: b, dark, width: 1)
            }
            strokePolygon(ctx, bed, UIColor(rgb: 0x21170E), width: 1.2)
            // Standing wheel
            ctx.setStrokeColor(dark.cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: CGRect(x: 12, y: 28, width: 20, height: 20))
            for angle in stride(from: 0.0, to: Double.pi, by: Double.pi / 3) {
                let dx = CGFloat(cos(angle)) * 9
                let dy = CGFloat(sin(angle)) * 9
                stroke(ctx, from: CGPoint(x: 22 - dx, y: 38 - dy), to: CGPoint(x: 22 + dx, y: 38 + dy), dark, width: 1.4)
            }
            // Fallen wheel and broken shaft
            ctx.setLineWidth(2.5)
            ctx.strokeEllipse(in: CGRect(x: 50, y: 38, width: 20, height: 8))
            stroke(ctx, from: CGPoint(x: 56, y: 26), to: CGPoint(x: 76, y: 42), wood, width: 2.5)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - baseY) / size.height))
    }

    private static func campfire() -> Sprite {
        let size = CGSize(width: 38, height: 26)
        let baseY: CGFloat = 19
        let image = render(size) { ctx in
            radialGradient(ctx, center: CGPoint(x: 19, y: baseY), radius: 9,
                           inner: UIColor(rgb: 0xFF9A3A, alpha: 0.9), outer: UIColor(rgb: 0x7A2A0A, alpha: 0))
            stroke(ctx, from: CGPoint(x: 9, y: 22), to: CGPoint(x: 29, y: 15), UIColor(rgb: 0x3A2616), width: 3.5)
            stroke(ctx, from: CGPoint(x: 9, y: 15), to: CGPoint(x: 29, y: 22), UIColor(rgb: 0x2E1E12), width: 3.5)
            let stone = UIColor(rgb: 0x5A5652)
            for index in 0..<9 {
                let angle = Double(index) / 9 * 2 * Double.pi
                let x = 19 + CGFloat(cos(angle)) * 15
                let y = baseY + CGFloat(sin(angle)) * 5.5
                ctx.setFillColor(stone.cgColor)
                ctx.fillEllipse(in: CGRect(x: x - 3, y: y - 2.2, width: 6, height: 4.4))
            }
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - baseY) / size.height))
    }

    private static func flame() -> Sprite {
        let size = CGSize(width: 20, height: 30)
        let image = render(size) { ctx in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 10, y: 1))
            path.addQuadCurve(to: CGPoint(x: 18, y: 22), controlPoint: CGPoint(x: 19, y: 12))
            path.addQuadCurve(to: CGPoint(x: 2, y: 22), controlPoint: CGPoint(x: 10, y: 32))
            path.addQuadCurve(to: CGPoint(x: 10, y: 1), controlPoint: CGPoint(x: 1, y: 12))
            ctx.saveGState()
            ctx.addPath(path.cgPath)
            ctx.clip()
            let colors = [UIColor(rgb: 0xFFF1B0).cgColor, UIColor(rgb: 0xFFA23A).cgColor,
                          UIColor(rgb: 0xC2341A).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                         locations: [0, 0.5, 1]) {
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 10, y: 28), end: CGPoint(x: 10, y: 1), options: [])
            }
            ctx.restoreGState()
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.1))
    }

    private static func oldShrine() -> Sprite {
        let size = CGSize(width: 52, height: 78)
        let baseY: CGFloat = 74
        let image = render(size) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.35).cgColor)
            ctx.fillEllipse(in: CGRect(x: 2, y: baseY - 6, width: 48, height: 12))
            fill(ctx, CGRect(x: 5, y: baseY - 12, width: 42, height: 12), UIColor(rgb: 0x4E4C54))
            fill(ctx, CGRect(x: 10, y: baseY - 20, width: 32, height: 8), UIColor(rgb: 0x5A5860))
            let obelisk = [CGPoint(x: 17, y: baseY - 20), CGPoint(x: 20, y: 14), CGPoint(x: 26, y: 5),
                           CGPoint(x: 32, y: 14), CGPoint(x: 35, y: baseY - 20)]
            fillPolygon(ctx, obelisk, UIColor(rgb: 0x5C5A62))
            fillPolygon(ctx, [CGPoint(x: 26, y: 5), CGPoint(x: 32, y: 14), CGPoint(x: 35, y: baseY - 20),
                              CGPoint(x: 26, y: baseY - 20)], UIColor(rgb: 0x48464E))
            strokePolygon(ctx, obelisk, UIColor(rgb: 0x201E24), width: 1.1)
            let rune = UIColor(rgb: 0xF0B050)
            ctx.setStrokeColor(rune.cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: CGRect(x: 21, y: 28, width: 10, height: 10))
            stroke(ctx, from: CGPoint(x: 26, y: 22), to: CGPoint(x: 26, y: 46), rune, width: 1.5)
            stroke(ctx, from: CGPoint(x: 22, y: 42), to: CGPoint(x: 30, y: 42), rune, width: 1.5)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - baseY) / size.height))
    }

    private static func rock() -> Sprite {
        let size = CGSize(width: 36, height: 24)
        let baseY: CGFloat = 20
        let image = render(size) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 2, y: baseY - 4, width: 32, height: 8))
            let body = [CGPoint(x: 4, y: baseY), CGPoint(x: 7, y: 9), CGPoint(x: 15, y: 4), CGPoint(x: 26, y: 5),
                        CGPoint(x: 32, y: 12), CGPoint(x: 31, y: baseY)]
            fillPolygon(ctx, body, UIColor(rgb: 0x5E5A55))
            fillPolygon(ctx, [CGPoint(x: 7, y: 9), CGPoint(x: 15, y: 4), CGPoint(x: 19, y: 11), CGPoint(x: 9, y: 13)],
                        UIColor(rgb: 0x77726B))
            fillPolygon(ctx, [CGPoint(x: 4, y: baseY), CGPoint(x: 31, y: baseY), CGPoint(x: 30, y: baseY - 4),
                              CGPoint(x: 6, y: baseY - 3)], UIColor(rgb: 0x3E3A36))
            strokePolygon(ctx, body, UIColor(rgb: 0x221F1C), width: 1)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - baseY) / size.height))
    }

    private static func grassTuft() -> Sprite {
        let size = CGSize(width: 26, height: 16)
        let image = render(size) { ctx in
            var random = SeededRandom(seed: 7)
            ctx.setLineCap(.round)
            for index in 0..<9 {
                let x = CGFloat(4 + index * 2) + CGFloat(random.range(-1, 1))
                let lean = CGFloat(random.range(-5, 5))
                let height = CGFloat(random.range(7, 14))
                let color = index % 2 == 0 ? UIColor(rgb: 0x8A7A48) : UIColor(rgb: 0x6E6038)
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(1.2)
                ctx.move(to: CGPoint(x: x, y: 15))
                ctx.addQuadCurve(to: CGPoint(x: x + lean, y: 15 - height), control: CGPoint(x: x, y: 15 - height * 0.6))
                ctx.strokePath()
            }
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.1))
    }

    private static func bones() -> Sprite {
        let size = CGSize(width: 30, height: 16)
        let image = render(size) { ctx in
            let bone = UIColor(rgb: 0xCFC8B8)
            ctx.setLineCap(.round)
            stroke(ctx, from: CGPoint(x: 4, y: 11), to: CGPoint(x: 16, y: 7), bone, width: 2)
            stroke(ctx, from: CGPoint(x: 9, y: 4), to: CGPoint(x: 13, y: 13), bone, width: 1.8)
            ctx.setFillColor(bone.cgColor)
            ctx.fillEllipse(in: CGRect(x: 18, y: 3, width: 9, height: 8))
            ctx.setFillColor(UIColor(rgb: 0x2A2622).cgColor)
            ctx.fillEllipse(in: CGRect(x: 20, y: 5.5, width: 2, height: 2))
            ctx.fillEllipse(in: CGRect(x: 23.5, y: 5.5, width: 2, height: 2))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    // MARK: - Effects

    static func radialDot(size: CGFloat) -> Sprite {
        let image = render(CGSize(width: size, height: size)) { ctx in
            radialGradient(ctx, center: CGPoint(x: size / 2, y: size / 2), radius: size / 2,
                           inner: .white, outer: UIColor(white: 1, alpha: 0))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    /// A 120° crescent pointing along +x, brightest at its leading rim.
    private static func slash() -> Sprite {
        let dimension: CGFloat = 128
        let center = CGPoint(x: dimension / 2, y: dimension / 2)
        let image = render(CGSize(width: dimension, height: dimension)) { ctx in
            let outer = dimension / 2 - 1
            let bands: [(inner: CGFloat, alpha: CGFloat)] = [(0.55, 0.10), (0.68, 0.22), (0.80, 0.45), (0.90, 0.85)]
            for band in bands {
                let path = UIBezierPath()
                path.addArc(withCenter: center, radius: outer, startAngle: -.pi / 3, endAngle: .pi / 3,
                            clockwise: true)
                path.addArc(withCenter: center, radius: outer * band.inner, startAngle: .pi / 3,
                            endAngle: -.pi / 3, clockwise: false)
                path.close()
                ctx.setFillColor(UIColor(rgb: 0xFFF3DC, alpha: band.alpha).cgColor)
                ctx.addPath(path.cgPath)
                ctx.fillPath()
            }
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    private static func spark() -> Sprite {
        let dimension: CGFloat = 24
        let image = render(CGSize(width: dimension, height: dimension)) { ctx in
            let c = dimension / 2
            radialGradient(ctx, center: CGPoint(x: c, y: c), radius: c * 0.6,
                           inner: UIColor(white: 1, alpha: 0.9), outer: UIColor(white: 1, alpha: 0))
            fillPolygon(ctx, [CGPoint(x: c, y: 0), CGPoint(x: c + 2, y: c - 2), CGPoint(x: dimension, y: c),
                              CGPoint(x: c + 2, y: c + 2), CGPoint(x: c, y: dimension), CGPoint(x: c - 2, y: c + 2),
                              CGPoint(x: 0, y: c), CGPoint(x: c - 2, y: c - 2)], .white)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    private static func ring() -> Sprite {
        let dimension: CGFloat = 64
        let image = render(CGSize(width: dimension, height: dimension)) { ctx in
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: CGRect(x: 2, y: 2, width: dimension - 4, height: dimension - 4))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    private static func splat() -> Sprite {
        let size = CGSize(width: 40, height: 20)
        let image = render(size) { ctx in
            var random = SeededRandom(seed: 41)
            ctx.setFillColor(UIColor(white: 1, alpha: 0.85).cgColor)
            ctx.fillEllipse(in: CGRect(x: 10, y: 5, width: 20, height: 10))
            for _ in 0..<7 {
                let x = CGFloat(random.range(3, 33))
                let y = CGFloat(random.range(3, 14))
                let r = CGFloat(random.range(1.5, 4))
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r))
            }
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    /// Screen-edge darkening in a realm's colour. Stretched to fill the screen.
    static func vignette(color: RGBA) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        return render(size) { ctx in
            let colors = [color.withAlpha(0).cgColor, color.withAlpha(color.alpha * 0.35).cgColor,
                          color.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                            locations: [0.45, 0.75, 1]) else { return }
            ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: 128, y: 128), startRadius: 0,
                                   endCenter: CGPoint(x: 128, y: 128), endRadius: 181,
                                   options: [.drawsAfterEndLocation])
        }
    }

    // MARK: - Ground

    /// One isometric ground tile. The diamond is inflated by `bleed` points on
    /// every side so neighbouring tiles overlap slightly and no hairline gaps
    /// appear between them.
    static func groundTile(style: GroundTileStyle, tileSize: CGSize, bleed: CGFloat, variant: Int) -> UIImage {
        let size = CGSize(width: tileSize.width + bleed * 2, height: tileSize.height + bleed * 2)
        return render(size) { ctx in
            let diamond = [CGPoint(x: size.width / 2, y: 0), CGPoint(x: size.width, y: size.height / 2),
                           CGPoint(x: size.width / 2, y: size.height), CGPoint(x: 0, y: size.height / 2)]
            ctx.addPath(polygonPath(diamond))
            ctx.clip()

            let base = style.base.scaled(brightness: 1 + (Double(variant) - 1) * 0.03)
            fill(ctx, CGRect(origin: .zero, size: size), base.uiColor)
            // `hashValue` is randomised per launch, so derive a stable seed instead.
            let patternSeed = style.pattern.rawValue.unicodeScalars.reduce(UInt64(17)) { $0 &* 31 &+ UInt64($1.value) }
            var random = SeededRandom(seed: UInt64(variant) &* 7919 &+ patternSeed)
            let detail = style.detail.uiColor

            switch style.pattern {
            case .speckled:
                for _ in 0..<22 {
                    let x = CGFloat(random.range(0, Double(size.width)))
                    let y = CGFloat(random.range(0, Double(size.height)))
                    let r = CGFloat(random.range(0.6, 1.6))
                    ctx.setFillColor(detail.withAlphaComponent(CGFloat(random.range(0.4, 0.9))).cgColor)
                    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r))
                }
            case .patchy:
                for _ in 0..<4 {
                    let x = CGFloat(random.range(0, Double(size.width)))
                    let y = CGFloat(random.range(0, Double(size.height)))
                    let w = CGFloat(random.range(10, 26))
                    ctx.setFillColor(detail.withAlphaComponent(0.45).cgColor)
                    ctx.fillEllipse(in: CGRect(x: x - w / 2, y: y - w / 4, width: w, height: w / 2))
                }
            case .cracked:
                ctx.setLineCap(.round)
                for _ in 0..<3 {
                    var point = CGPoint(x: random.range(0, Double(size.width)), y: random.range(0, Double(size.height)))
                    for _ in 0..<4 {
                        let next = point + CGPoint(x: random.range(-9, 9), y: random.range(-4, 4))
                        stroke(ctx, from: point, to: next, detail.withAlphaComponent(0.8), width: 0.9)
                        point = next
                    }
                }
            case .cobbled:
                // Mortar background with stones laid along the diamond's axes.
                fill(ctx, CGRect(origin: .zero, size: size), detail)
                let steps = 4
                for i in 0..<steps {
                    for j in 0..<steps {
                        let u = (CGFloat(i) + 0.5) / CGFloat(steps)
                        let v = (CGFloat(j) + 0.5) / CGFloat(steps)
                        let center = CGPoint(x: size.width / 2 + (u - v) * size.width / 2,
                                             y: (u + v) * size.height / 2)
                        let jitter = CGFloat(random.range(0.85, 1.05))
                        let stoneColor = base.scaled(brightness: random.range(0.9, 1.12)).uiColor
                        ctx.setFillColor(stoneColor.cgColor)
                        ctx.fillEllipse(in: CGRect(x: center.x - 8 * jitter, y: center.y - 4 * jitter,
                                                   width: 16 * jitter, height: 8 * jitter))
                    }
                }
            case .smooth:
                radialGradient(ctx, center: CGPoint(x: size.width * 0.4, y: size.height * 0.4),
                               radius: size.width * 0.5, inner: detail.withAlphaComponent(0.25),
                               outer: detail.withAlphaComponent(0))
            }
        }
    }

    // MARK: - Drawing helpers

    static func render(_ size: CGSize, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(context.cgContext)
        }
    }

    static func fill(_ ctx: CGContext, _ rect: CGRect, _ color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
    }

    static func stroke(_ ctx: CGContext, from: CGPoint, to: CGPoint, _ color: UIColor, width: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
    }

    static func polygonPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    static func fillPolygon(_ ctx: CGContext, _ points: [CGPoint], _ color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(polygonPath(points))
        ctx.fillPath()
    }

    static func strokePolygon(_ ctx: CGContext, _ points: [CGPoint], _ color: UIColor, width: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.addPath(polygonPath(points))
        ctx.strokePath()
    }

    static func radialGradient(_ ctx: CGContext, center: CGPoint, radius: CGFloat,
                                       inner: UIColor, outer: UIColor) {
        let colors = [inner.cgColor, outer.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                        locations: [0, 1]) else { return }
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius, options: [])
    }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }
}
