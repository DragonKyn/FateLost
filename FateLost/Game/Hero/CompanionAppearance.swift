import Foundation

/// The six companions a player can restyle: the druid's two forms, and the
/// necromancer's, and the warlock's, standout summons. Purely cosmetic, the
/// same way the hero's own look is — nothing here is a stat.
enum CompanionTarget: String, Codable, CaseIterable, Identifiable {
    case bearForm
    case wolfForm
    case skeleton
    case boneColossus
    case hellhound
    case fiend

    var id: String { rawValue }

    var name: String {
        switch self {
        case .bearForm: return "Ursine Form"
        case .wolfForm: return "Lupine Form"
        case .skeleton: return "Risen Skeleton"
        case .boneColossus: return "Bone Colossus"
        case .hellhound: return "Hellhound"
        case .fiend: return "Pit Fiend"
        }
    }

    var blurb: String {
        switch self {
        case .bearForm: return "The druid's own claws and bulk."
        case .wolfForm: return "The druid, fast and low to the ground."
        case .skeleton: return "Risen from whatever was lying around."
        case .boneColossus: return "A tower of borrowed bone."
        case .hellhound: return "Fast, and always a little on fire."
        case .fiend: return "The heaviest thing the pact allows."
        }
    }

    /// The sprite it draws with, so a preview can show the real thing.
    var sprite: SpriteID {
        switch self {
        case .bearForm: return FormCatalog.bear.sprite
        case .wolfForm: return FormCatalog.wolf.sprite
        case .skeleton: return SummonCatalog.skeleton.sprite
        case .boneColossus: return SummonCatalog.boneColossus.sprite
        case .hellhound: return SummonCatalog.hellhound.sprite
        case .fiend: return SummonCatalog.fiend.sprite
        }
    }

    /// The tint it already carries in the catalogue, if any — kept as the
    /// look's own default rather than overwritten by an unmade choice.
    var catalogueTint: RGBA? {
        switch self {
        case .bearForm: return FormCatalog.bear.tint
        case .wolfForm: return FormCatalog.wolf.tint
        case .skeleton: return SummonCatalog.skeleton.tint
        case .boneColossus: return SummonCatalog.boneColossus.tint
        case .hellhound: return SummonCatalog.hellhound.tint
        case .fiend: return SummonCatalog.fiend.tint
        }
    }

    /// The scale the catalogue already gives it, before a size choice
    /// multiplies it: "Standard" always means the creature's own default.
    var catalogueScale: Double {
        switch self {
        case .bearForm: return Double(FormCatalog.bear.scale)
        case .wolfForm: return Double(FormCatalog.wolf.scale)
        case .skeleton: return Double(SummonCatalog.skeleton.scale)
        case .boneColossus: return Double(SummonCatalog.boneColossus.scale)
        case .hellhound: return Double(SummonCatalog.hellhound.scale)
        case .fiend: return Double(SummonCatalog.fiend.scale)
        }
    }
}

/// A discrete size choice, a multiple of whatever the creature's own base
/// scale already is.
enum CompanionScale: String, Codable, CaseIterable, Identifiable {
    case runt
    case standard
    case massive

    var id: String { rawValue }

    var name: String {
        switch self {
        case .runt: return "Runt"
        case .standard: return "Standard"
        case .massive: return "Massive"
        }
    }

    var multiplier: Double {
        switch self {
        case .runt: return 0.75
        case .standard: return 1.0
        case .massive: return 1.3
        }
    }
}

/// A prop shown beside a companion rather than worn on it, so one drawing
/// fits a skeleton, a hellhound and a bone colossus alike without needing
/// to match three different silhouettes.
enum CompanionExtra: String, Codable, CaseIterable, Identifiable {
    case none
    case banner
    case charm

    var id: String { rawValue }

    var name: String {
        switch self {
        case .none: return "No Extra"
        case .banner: return "Battle Standard"
        case .charm: return "Bone Charm"
        }
    }

    var blurb: String {
        switch self {
        case .none: return "Nothing extra."
        case .banner: return "A small banner, planted beside it."
        case .charm: return "A trophy, strung up and swaying."
        }
    }
}

/// One target's chosen look. A `nil` tint keeps whatever the catalogue
/// already gives it — some summons come pre-tinted on purpose, like the
/// spirit wolf's chill blue — so never having made a choice can't look wrong.
struct CompanionLook: Codable, Equatable, Hashable {
    var tint: String?
    var scale: CompanionScale = .standard
    var extra: CompanionExtra = .none
}

/// Every companion's chosen look, keyed by target. Saved alongside the
/// hero's own look, and restricted to what is owned the same way.
struct CompanionCustomization: Codable, Equatable, Hashable {
    private var looks: [String: CompanionLook] = [:]

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        looks = (try? container.decode([String: CompanionLook].self)) ?? [:]
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(looks)
    }

    subscript(target: CompanionTarget) -> CompanionLook {
        get { looks[target.rawValue] ?? CompanionLook() }
        set { looks[target.rawValue] = newValue }
    }

    /// This customisation with anything not owned swapped back to default,
    /// the same rule `HeroAppearance.restricted(to:)` holds the hero's own
    /// look to.
    func restricted(to owns: (CompanionOption) -> Bool) -> CompanionCustomization {
        var result = self
        for target in CompanionTarget.allCases {
            var look = self[target]
            if !owns(.customize(target)) {
                look.tint = nil
                look.scale = .standard
            }
            if look.extra != .none, !owns(.extra(target, look.extra)) {
                look.extra = .none
            }
            result[target] = look
        }
        return result
    }
}

extension CompanionTarget {
    /// The target a druid form restyles, if it is one of the two that do.
    init?(formID: FormID) {
        switch formID {
        case FormCatalog.bear.id: self = .bearForm
        case FormCatalog.wolf.id: self = .wolfForm
        default: return nil
        }
    }

    /// The target a summon restyles, if it is one of the four that do.
    init?(summonKey: String) {
        switch summonKey {
        case SummonCatalog.skeleton.key: self = .skeleton
        case SummonCatalog.boneColossus.key: self = .boneColossus
        case SummonCatalog.hellhound.key: self = .hellhound
        case SummonCatalog.fiend.key: self = .fiend
        default: return nil
        }
    }
}

extension FormDefinition {
    /// This form with a player's chosen colour and size applied, if they
    /// have restyled it; unchanged otherwise, including forms with no
    /// target at all (Iron Fist belongs to the monk, not the druid).
    func customized(with companions: CompanionCustomization) -> FormDefinition {
        guard let target = CompanionTarget(formID: id) else { return self }
        let look = companions[target]
        let tint = look.tint.map { RGBA(hex: HeroPalette.swatch($0, in: HeroPalette.trim).hex) } ?? tint
        let scale = CGFloat(target.catalogueScale * look.scale.multiplier)
        return FormDefinition(id: id, name: name, weapon: weapon, modifiers: modifiers, sprite: sprite, tint: tint,
                              scale: scale, hidesWeapon: hidesWeapon)
    }
}
