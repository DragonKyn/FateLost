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

    /// The tint it already carries in the catalogue — kept as the base
    /// appearance's own look rather than overwritten by an unmade choice.
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

    /// Roughly how much heavier or flashier this target is, for pricing:
    /// the druid's own forms and the two biggest summons cost the most to
    /// restyle.
    enum Weight { case light, medium, heavy }
    var weight: Weight {
        switch self {
        case .skeleton, .hellhound: return .light
        case .bearForm, .wolfForm: return .medium
        case .boneColossus, .fiend: return .heavy
        }
    }
}

/// One named appearance a target can wear. Every target has exactly one
/// free "Base" appearance (its catalogue look, id `"base"`) plus a handful
/// of themed recolours, priced and owned individually — buying one never
/// buys another.
struct CompanionAppearanceOption: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    /// A swatch id from `HeroPalette.trim`, or nil for the untouched
    /// catalogue look.
    let tint: String?

    var isBase: Bool { tint == nil }
}

enum CompanionAppearanceCatalog {
    /// Every appearance a target can wear, base first.
    static func options(for target: CompanionTarget) -> [CompanionAppearanceOption] {
        let base = CompanionAppearanceOption(id: "base", name: "Base", blurb: "However it already looks.", tint: nil)
        return [base] + themed(for: target)
    }

    static func option(_ id: String, for target: CompanionTarget) -> CompanionAppearanceOption {
        options(for: target).first { $0.id == id } ?? options(for: target)[0]
    }

    /// The themed recolours, skipping whichever theme would be redundant
    /// with a target that is already that colour by nature (a hellhound
    /// hardly needs an "ember" variant when it is already on fire).
    private static func themed(for target: CompanionTarget) -> [CompanionAppearanceOption] {
        switch target {
        case .bearForm:
            return [
                variant("ember", "Ember Bear", "Fur gone the colour of coals.", "ember"),
                variant("frost", "Frost Bear", "Breath that fogs in the summer.", "sapphire"),
                variant("shadow", "Shadow Bear", "Barely there until it isn't.", "black"),
            ]
        case .wolfForm:
            return [
                variant("ember", "Ember Wolf", "A coat that smoulders at a run.", "ember"),
                variant("frost", "Frost Wolf", "Leaves frost on the grass behind it.", "sapphire"),
                variant("void", "Void Wolf", "Eyes like something looked back.", "amethyst"),
            ]
        case .skeleton:
            return [
                variant("ember", "Flaming Skeleton", "Bones that never quite stopped burning.", "ember"),
                variant("frost", "Frost Skeleton", "Rimed over, and colder for it.", "sapphire"),
                variant("plague", "Plague Skeleton", "Whatever it died of, it's catching.", "verdigris"),
            ]
        case .boneColossus:
            return [
                variant("ember", "Cinder Colossus", "A furnace wearing borrowed bone.", "ember"),
                variant("frost", "Glacial Colossus", "Bone gone the blue of old ice.", "sapphire"),
                variant("void", "Hollow Colossus", "Empty in a way that shows.", "amethyst"),
            ]
        case .hellhound:
            return [
                variant("frost", "Frost Hellhound", "Cold enough to put itself out.", "sapphire"),
                variant("plague", "Plague Hellhound", "A different way to be dangerous.", "verdigris"),
                variant("void", "Void Hellhound", "Its bark left with the rest of it.", "amethyst"),
            ]
        case .fiend:
            return [
                variant("frost", "Frost Fiend", "The pact, paid in a colder coin.", "sapphire"),
                variant("plague", "Plague Fiend", "The pact, paid in rot instead.", "verdigris"),
                variant("void", "Void Fiend", "The pact's fine print.", "amethyst"),
            ]
        }
    }

    private static func variant(_ suffix: String, _ name: String, _ blurb: String,
                                _ tint: String) -> CompanionAppearanceOption {
        CompanionAppearanceOption(id: suffix, name: name, blurb: blurb, tint: tint)
    }
}

/// A discrete size choice, a multiple of whatever the creature's own base
/// scale already is. "Standard" is always free and is never bought — it is
/// simply the absence of a size choice.
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
/// to match three different silhouettes. Independent of appearance: a
/// player combines whichever look they bought with whichever charm they bought.
enum CompanionExtra: String, Codable, CaseIterable, Identifiable {
    case none
    case banner

    var id: String { rawValue }

    var name: String {
        switch self {
        case .none: return "No Extra"
        case .banner: return "Battle Standard"
        }
    }

    var blurb: String {
        switch self {
        case .none: return "Nothing extra."
        case .banner: return "A small banner, planted beside it."
        }
    }
}

/// One target's chosen look: which of its bought appearances is worn,
/// which of its bought sizes, and which extra, if any.
struct CompanionLook: Codable, Equatable, Hashable {
    var appearanceID: String?
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
    /// look to. Each axis is checked on its own, since each is its own purchase.
    func restricted(to owns: (CompanionOption) -> Bool) -> CompanionCustomization {
        var result = self
        for target in CompanionTarget.allCases {
            var look = self[target]
            if let id = look.appearanceID, id != "base", !owns(.appearance(target, id)) {
                look.appearanceID = nil
            }
            if look.scale != .standard, !owns(.scale(target, look.scale)) {
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
    /// This form with a player's chosen appearance and size applied, if
    /// they have restyled it; unchanged otherwise, including forms with no
    /// target at all (Iron Fist belongs to the monk, not the druid).
    func customized(with companions: CompanionCustomization) -> FormDefinition {
        guard let target = CompanionTarget(formID: id) else { return self }
        let look = companions[target]
        let chosen = CompanionAppearanceCatalog.option(look.appearanceID ?? "base", for: target)
        let tint = chosen.tint.map { RGBA(hex: HeroPalette.swatch($0, in: HeroPalette.trim).hex) } ?? tint
        let scale = CGFloat(target.catalogueScale * look.scale.multiplier)
        return FormDefinition(id: id, name: name, weapon: weapon, modifiers: modifiers, sprite: sprite, tint: tint,
                              scale: scale, hidesWeapon: hidesWeapon)
    }
}
