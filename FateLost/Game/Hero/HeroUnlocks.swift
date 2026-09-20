import Foundation

/// One thing the hero can be given: a build, a style or a colour.
///
/// A look is made of these, and the more distinctive ones cost echoes. Every
/// option is a pure choice of appearance, so nothing here is gated by
/// strength: the price is only a reason to go back for another run.
enum HeroOption: Hashable, Identifiable {
    case build(BodyBuild)
    case cloak(CloakStyle)
    case head(HeadStyle)
    case cloakColor(String)
    case trimColor(String)
    case eyeColor(String)

    /// Stable, and the key a purchase is saved under.
    var id: String {
        switch self {
        case .build(let value): return "build.\(value.rawValue)"
        case .cloak(let value): return "cloak.\(value.rawValue)"
        case .head(let value): return "head.\(value.rawValue)"
        case .cloakColor(let id): return "cloakColor.\(id)"
        case .trimColor(let id): return "trimColor.\(id)"
        case .eyeColor(let id): return "eyeColor.\(id)"
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
        }
        return next
    }

    func isWorn(by look: HeroAppearance) -> Bool {
        applying(to: look) == look
    }
}

/// What each option costs. Zero is free from the first launch.
///
/// Builds, skin and hair are always free: they are who a player is, not
/// something to earn. The distinctive cloaks and heads, and the stranger
/// colours, are what echoes can buy.
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
            }
        case .head(let style):
            switch style {
            case .hood, .bare: return 0
            case .cowl: return 120
            case .helm: return 180
            }
        case .cloakColor(let id):
            return colourCost(id, tiers: [
                "violet": 70, "black": 70, "ochre": 40, "teal": 40, "rust": 40,
            ])
        case .trimColor(let id):
            return colourCost(id, tiers: ["gold": 70, "ember": 40, "verdigris": 40, "blood": 40])
        case .eyeColor(let id):
            return colourCost(id, tiers: ["ember": 70, "violet": 70, "jade": 40, "crimson": 40])
        }
    }

    private static func colourCost(_ id: String, tiers: [String: Int]) -> Int {
        tiers[id] ?? 0
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

    /// Every option that costs something.
    static let priced: [HeroOption] = (cloaks + heads + cloakColours + trimColours + eyeColours)
        .filter { !isFree($0) }

    /// The options a look is currently made of, the ones that can be locked.
    static func options(of look: HeroAppearance) -> [HeroOption] {
        [.cloak(look.cloak), .head(look.head), .cloakColor(look.cloakColor), .trimColor(look.trimColor),
         .eyeColor(look.eyeColor)]
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
            case .build: break
            }
        }
        return look
    }

    /// A hero at random from what the player owns.
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
        look.skinTone = HeroPalette.skin.randomElement(using: &generator)?.id ?? look.skinTone
        look.hairColor = HeroPalette.hair.randomElement(using: &generator)?.id ?? look.hairColor
        return look
    }
}
