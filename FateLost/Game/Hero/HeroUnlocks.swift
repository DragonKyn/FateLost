import Foundation

/// One thing the hero can be given: a build, a style, a colour or an extra.
///
/// A look is made of these, and the more elaborate ones cost echoes. Every
/// option is a pure choice of appearance, so nothing here is gated by
/// strength: the price is only a reason to go back for another run.
enum HeroOption: Hashable, Identifiable {
    case build(BodyBuild)
    case cloak(CloakStyle)
    case head(HeadStyle)
    case cloakColor(String)
    case trimColor(String)
    case eyeColor(String)
    case emblem(EmblemStyle)
    case detail(MetalDetail)
    case wings(WingStyle)

    /// Stable, and the key a purchase is saved under.
    var id: String {
        switch self {
        case .build(let value): return "build.\(value.rawValue)"
        case .cloak(let value): return "cloak.\(value.rawValue)"
        case .head(let value): return "head.\(value.rawValue)"
        case .cloakColor(let id): return "cloakColor.\(id)"
        case .trimColor(let id): return "trimColor.\(id)"
        case .eyeColor(let id): return "eyeColor.\(id)"
        case .emblem(let value): return "emblem.\(value.rawValue)"
        case .detail(let value): return "detail.\(value.rawValue)"
        case .wings(let value): return "wings.\(value.rawValue)"
        }
    }

    /// What the player would call it.
    var title: String {
        switch self {
        case .build(let value): return value.name
        case .cloak(let value): return value.name
        case .head(let value): return value.name
        case .cloakColor(let id): return "\(HeroPalette.swatch(id, in: HeroPalette.cloak).name) cloak"
        case .trimColor(let id): return "\(HeroPalette.swatch(id, in: HeroPalette.trim).name) trim"
        case .eyeColor(let id): return "\(HeroPalette.swatch(id, in: HeroPalette.eyes).name) eyes"
        case .emblem(let value): return value.name
        case .detail(let value): return value.name
        case .wings(let value): return value.name
        }
    }

    /// A line of flavour, for the styles that have one.
    var blurb: String {
        switch self {
        case .build(let value): return value.blurb
        case .cloak(let value): return value.blurb
        case .head(let value): return value.blurb
        case .emblem(let value): return value.blurb
        case .detail(let value): return value.blurb
        case .wings(let value): return value.blurb
        case .cloakColor, .trimColor, .eyeColor: return ""
        }
    }

    /// The look this option produces when worn over another.
    func applying(to look: HeroAppearance) -> HeroAppearance {
        var next = look
        switch self {
        case .build(let value): next.build = value
        case .cloak(let value): next.cloak = value
        case .head(let value): next.head = value
        case .cloakColor(let id): next.cloakColor = id
        case .trimColor(let id): next.trimColor = id
        case .eyeColor(let id): next.eyeColor = id
        case .emblem(let value): next.emblem = value
        case .detail(let value): next.detail = value
        case .wings(let value): next.wings = value
        }
        return next
    }

    func isWorn(by look: HeroAppearance) -> Bool {
        applying(to: look) == look
    }
}

/// What each option costs. Zero is free from the first launch.
///
/// The rule is that cooler costs more. A colour is a few tens of echoes, a
/// cloak or a head a few hundred, and the things that change the whole
/// silhouette, wings above all, are the ones to save toward.
///
/// Builds, skin and hair are always free: they are who a player is, not
/// something to earn.
enum HeroUnlocks {
    static func cost(of option: HeroOption) -> Int {
        switch option {
        case .build:
            return 0
        case .cloak(let style):
            switch style {
            case .hooded, .mantle, .longCoat: return 0
            case .shroud: return 120
            case .pilgrim: return 180
            case .druid: return 200
            case .ninja: return 220
            case .wizard: return 240
            case .samurai: return 260
            case .paladin: return 300
            case .vampire: return 350
            }
        case .head(let style):
            switch style {
            case .hood, .bare: return 0
            case .cowl: return 100
            case .helm: return 150
            case .greatHelm: return 200
            case .wizardHat: return 240
            case .eyeless: return 250
            case .horned: return 260
            case .plague: return 300
            case .skull: return 320
            }
        case .cloakColor(let id):
            return [
                "ivory": 30, "slate": 30, "ochre": 40, "teal": 40, "rust": 40, "sunset": 40, "royal": 50,
                "emerald": 50, "rose": 60, "violet": 70, "black": 70,
            ][id] ?? 0
        case .trimColor(let id):
            return [
                "black": 30, "white": 30, "ember": 40, "verdigris": 40, "blood": 40, "copper": 40,
                "sapphire": 60, "amethyst": 60, "gold": 70,
            ][id] ?? 0
        case .eyeColor(let id):
            return [
                "azure": 30, "jade": 40, "crimson": 40, "gold": 50, "rose": 50, "ember": 70, "violet": 70,
            ][id] ?? 0
        case .emblem(let style):
            switch style {
            case .plain: return 0
            case .skulls: return 150
            case .vines: return 180
            case .runes: return 200
            case .celestial: return 250
            case .dragon: return 350
            }
        case .detail(let style):
            switch style {
            case .plain: return 0
            case .studs: return 100
            case .filigree: return 150
            case .pauldrons: return 220
            case .warPlate: return 380
            }
        case .wings(let style):
            switch style {
            case .plain: return 0
            case .angel, .demon: return 500
            }
        }
    }

    static func isFree(_ option: HeroOption) -> Bool {
        cost(of: option) == 0
    }

    static let builds: [HeroOption] = BodyBuild.allCases.map { .build($0) }
    static let cloaks: [HeroOption] = CloakStyle.allCases.map { .cloak($0) }
    static let heads: [HeroOption] = HeadStyle.allCases.map { .head($0) }
    static let cloakColours: [HeroOption] = HeroPalette.cloak.map { .cloakColor($0.id) }
    static let trimColours: [HeroOption] = HeroPalette.trim.map { .trimColor($0.id) }
    static let eyeColours: [HeroOption] = HeroPalette.eyes.map { .eyeColor($0.id) }
    static let emblems: [HeroOption] = EmblemStyle.allCases.map { .emblem($0) }
    static let details: [HeroOption] = MetalDetail.allCases.map { .detail($0) }
    static let wings: [HeroOption] = WingStyle.allCases.map { .wings($0) }

    /// Every option there is.
    static let all: [HeroOption] = builds + cloaks + heads + cloakColours + trimColours + eyeColours
        + emblems + details + wings

    /// Every option that costs something.
    static let priced: [HeroOption] = all.filter { !isFree($0) }

    /// The options a look is currently made of, the ones that can be locked.
    static func options(of look: HeroAppearance) -> [HeroOption] {
        [.cloak(look.cloak), .head(look.head), .cloakColor(look.cloakColor), .trimColor(look.trimColor),
         .eyeColor(look.eyeColor), .emblem(look.emblem), .detail(look.detail), .wings(look.wings)]
    }
}

extension HeroAppearance {
    /// This look with anything the player does not own swapped for the plain
    /// choice. A saved look can never wear something that has not been paid
    /// for, whatever happened to the profile since it was saved.
    func restricted(to owns: (HeroOption) -> Bool) -> HeroAppearance {
        var look = self
        for option in HeroUnlocks.options(of: self) where !owns(option) {
            switch option {
            case .cloak: look.cloak = .hooded
            case .head: look.head = .hood
            case .cloakColor: look.cloakColor = HeroPalette.cloak[0].id
            case .trimColor: look.trimColor = HeroPalette.trim[0].id
            case .eyeColor: look.eyeColor = HeroPalette.eyes[0].id
            case .emblem: look.emblem = .plain
            case .detail: look.detail = .plain
            case .wings: look.wings = .plain
            case .build: break
            }
        }
        return look
    }

    /// A hero at random from what the player owns. Extras are added about as
    /// often as they are left off, so a random hero is not always dressed up.
    static func random<G: RandomNumberGenerator>(using generator: inout G,
                                                 owns: (HeroOption) -> Bool) -> HeroAppearance {
        var look = HeroAppearance()
        func pick(_ options: [HeroOption]) -> HeroOption? {
            options.filter(owns).randomElement(using: &generator)
        }
        for options in [HeroUnlocks.builds, HeroUnlocks.cloaks, HeroUnlocks.heads, HeroUnlocks.cloakColours,
                        HeroUnlocks.trimColours, HeroUnlocks.eyeColours] {
            if let chosen = pick(options) {
                look = chosen.applying(to: look)
            }
        }
        for options in [HeroUnlocks.emblems, HeroUnlocks.details, HeroUnlocks.wings] {
            if Bool.random(using: &generator), let chosen = pick(options) {
                look = chosen.applying(to: look)
            }
        }
        look.skinTone = HeroPalette.skin.randomElement(using: &generator)?.id ?? look.skinTone
        look.hairColor = HeroPalette.hair.randomElement(using: &generator)?.id ?? look.hairColor
        return look
    }
}
