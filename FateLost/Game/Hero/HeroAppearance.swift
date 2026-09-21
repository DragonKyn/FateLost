import CoreGraphics
import Foundation

/// How the hero is built. It changes how they look and where the weapon
/// sits in the hand, and nothing else: no build is stronger, faster or
/// tougher than another. A body is a choice about who you are, not a stat,
/// so every build is free.
enum BodyBuild: String, Codable, CaseIterable, Identifiable {
    case lithe
    case standard
    case broad
    case stout
    case towering

    var id: String { rawValue }

    var name: String {
        switch self {
        case .lithe: return "Lithe"
        case .standard: return "Wanderer"
        case .broad: return "Broad"
        case .stout: return "Stout"
        case .towering: return "Towering"
        }
    }

    var blurb: String {
        switch self {
        case .lithe: return "Tall, narrow, quick to vanish."
        case .standard: return "Nothing remarkable. Yet."
        case .broad: return "Shoulders made for carrying things."
        case .stout: return "Low to the ground and hard to move."
        case .towering: return "Ducks under most doorways."
        }
    }

    /// Where the weapon is held, from the feet up.
    var hand: CGPoint {
        switch self {
        case .lithe: return CGPoint(x: 10, y: 21)
        case .standard: return CGPoint(x: 11.5, y: 20)
        case .broad: return CGPoint(x: 14.5, y: 19)
        case .stout: return CGPoint(x: 13.5, y: 17)
        case .towering: return CGPoint(x: 13, y: 24)
        }
    }
}

enum CloakStyle: String, Codable, CaseIterable, Identifiable {
    case hooded
    case mantle
    case longCoat
    case shroud
    case pilgrim
    case druid
    case ninja
    case wizard
    case samurai
    case paladin
    case vampire
    case angelic
    case demonic

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hooded: return "Wayfarer's Cloak"
        case .mantle: return "Short Mantle"
        case .longCoat: return "Long Coat"
        case .shroud: return "Tattered Shroud"
        case .pilgrim: return "Pilgrim's Cape"
        case .druid: return "Druid's Mantle"
        case .ninja: return "Shadow Garb"
        case .wizard: return "Star Robes"
        case .samurai: return "Ronin's Kimono"
        case .paladin: return "Paladin's Tabard"
        case .vampire: return "Vampire's Cloak"
        case .angelic: return "Seraph's Vestments"
        case .demonic: return "Infernal Mantle"
        }
    }

    var blurb: String {
        switch self {
        case .hooded: return "Hangs straight, and has seen weather."
        case .mantle: return "Over the shoulders, out of the way."
        case .longCoat: return "Buttoned to the knee."
        case .shroud: return "Torn by things that did not let go."
        case .pilgrim: return "A high collar and a long road."
        case .druid: return "Leaves that have not yet noticed autumn."
        case .ninja: return "Wrapped tight, with a scarf that will not sit still."
        case .wizard: return "Wide sleeves, and stars sewn in."
        case .samurai: return "Winged shoulders, and a master long gone."
        case .paladin: return "Steel under a sworn colour."
        case .vampire: return "A collar to hide behind, and a lining to be seen."
        case .angelic: return "A mantle of white feathers, gilded at the hem."
        case .demonic: return "Spiked at the shoulder, and burning at the hem."
        }
    }
}

enum HeadStyle: String, Codable, CaseIterable, Identifiable {
    case hood
    case cowl
    case bare
    case helm
    case greatHelm
    case wizardHat
    case eyeless
    case horned
    case plague
    case skull

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hood: return "Deep Hood"
        case .cowl: return "Veiled Cowl"
        case .bare: return "Bare Head"
        case .helm: return "Iron Helm"
        case .greatHelm: return "Great Helm"
        case .wizardHat: return "Wizard's Hat"
        case .eyeless: return "Eyeless Hood"
        case .horned: return "Horned Helm"
        case .plague: return "Plague Mask"
        case .skull: return "Bone Mask"
        }
    }

    var blurb: String {
        switch self {
        case .hood: return "A face left to the dark."
        case .cowl: return "Cloth across the mouth."
        case .bare: return "Nothing to hide. Nothing to hide behind."
        case .helm: return "Dented, and still on."
        case .greatHelm: return "Shut tight, with a plume for show."
        case .wizardHat: return "A beard that has earned its own chapter."
        case .eyeless: return "No face. Nothing looking out."
        case .horned: return "Loud from across a field."
        case .plague: return "It has seen worse than you."
        case .skull: return "What is left, worn on purpose."
        }
    }
}

/// A mark worn over the chest of any outfit.
enum EmblemStyle: String, Codable, CaseIterable, Identifiable {
    case plain
    case skulls
    case vines
    case runes
    case celestial
    case dragon

    var id: String { rawValue }

    var name: String {
        switch self {
        case .plain: return "No Emblem"
        case .skulls: return "Skull and Bones"
        case .vines: return "Living Vines"
        case .runes: return "Arcane Runes"
        case .celestial: return "Celestial Markings"
        case .dragon: return "Dragon Crest"
        }
    }

    var blurb: String {
        switch self {
        case .plain: return "Nothing on the chest."
        case .skulls: return "A warning, worn where it can be read."
        case .vines: return "They climb on their own."
        case .runes: return "Lit in the colour of your eyes."
        case .celestial: return "A moon and the stars that follow it."
        case .dragon: return "A wyrm's head, wings swept back."
        }
    }
}

/// Metalwork worn over any outfit.
enum MetalDetail: String, Codable, CaseIterable, Identifiable {
    case plain
    case studs
    case filigree
    case pauldrons
    case warPlate

    var id: String { rawValue }

    var name: String {
        switch self {
        case .plain: return "No Metalwork"
        case .studs: return "Riveted Studs"
        case .filigree: return "Fine Filigree"
        case .pauldrons: return "Steel Pauldrons"
        case .warPlate: return "War Plate"
        }
    }

    var blurb: String {
        switch self {
        case .plain: return "Cloth and leather only."
        case .studs: return "Rows of rivets, and a little swagger."
        case .filigree: return "Curling wire, in your trim colour."
        case .pauldrons: return "Spiked steel on both shoulders."
        case .warPlate: return "Breastplate, gorget, tassets and spikes."
        }
    }
}

/// Wings worn behind any outfit.
enum WingStyle: String, Codable, CaseIterable, Identifiable {
    case plain
    case angel
    case demon

    var id: String { rawValue }

    var name: String {
        switch self {
        case .plain: return "No Wings"
        case .angel: return "Angel Wings"
        case .demon: return "Demon Wings"
        }
    }

    var blurb: String {
        switch self {
        case .plain: return "Grounded."
        case .angel: return "White feathers, and no apology."
        case .demon: return "Leather and bone, with claws."
        }
    }
}

/// A named colour. Held as data so the model has no drawing code in it.
struct HeroSwatch: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let hex: UInt32
}

/// Every colour the hero can be dressed in. Each list opens with the colour
/// the hero has always had, and an unknown id falls back to it, so a saved
/// choice can never point at something that is gone. New colours are only
/// ever added to the end.
enum HeroPalette {
    static let cloak: [HeroSwatch] = [
        HeroSwatch(id: "crimson", name: "Crimson", hex: 0x5B2323),
        HeroSwatch(id: "ash", name: "Ash", hex: 0x5A5651),
        HeroSwatch(id: "midnight", name: "Midnight", hex: 0x26365A),
        HeroSwatch(id: "moss", name: "Moss", hex: 0x40502C),
        HeroSwatch(id: "violet", name: "Violet", hex: 0x4C2C62),
        HeroSwatch(id: "ochre", name: "Ochre", hex: 0x7F5D28),
        HeroSwatch(id: "teal", name: "Deep Teal", hex: 0x1F4F4C),
        HeroSwatch(id: "rust", name: "Rust", hex: 0x7C3B1D),
        HeroSwatch(id: "bone", name: "Bone", hex: 0xA79E8A),
        HeroSwatch(id: "black", name: "Void", hex: 0x1F1C22),
        HeroSwatch(id: "ivory", name: "Ivory", hex: 0xD8D2C4),
        HeroSwatch(id: "royal", name: "Royal Blue", hex: 0x2C4FA0),
        HeroSwatch(id: "emerald", name: "Emerald", hex: 0x1F6B3A),
        HeroSwatch(id: "rose", name: "Rose", hex: 0x9B3A5A),
        HeroSwatch(id: "slate", name: "Slate", hex: 0x38404A),
        HeroSwatch(id: "sunset", name: "Sunset", hex: 0xB8501E),
        HeroSwatch(id: "white", name: "White", hex: 0xF2F0EA),
    ]

    static let trim: [HeroSwatch] = [
        HeroSwatch(id: "brass", name: "Brass", hex: 0xC9A55A),
        HeroSwatch(id: "silver", name: "Silver", hex: 0xB9BEC8),
        HeroSwatch(id: "ember", name: "Ember", hex: 0xE0782A),
        HeroSwatch(id: "bone", name: "Bone", hex: 0xDCD3BF),
        HeroSwatch(id: "verdigris", name: "Verdigris", hex: 0x4FB39A),
        HeroSwatch(id: "blood", name: "Blood", hex: 0xA12222),
        HeroSwatch(id: "gold", name: "Gold", hex: 0xF0C94A),
        HeroSwatch(id: "black", name: "Black", hex: 0x14121A),
        HeroSwatch(id: "copper", name: "Copper", hex: 0xB0703A),
        HeroSwatch(id: "white", name: "White", hex: 0xF4F2EC),
        HeroSwatch(id: "sapphire", name: "Sapphire", hex: 0x4A78D8),
        HeroSwatch(id: "amethyst", name: "Amethyst", hex: 0x9A6AE0),
    ]

    static let eyes: [HeroSwatch] = [
        HeroSwatch(id: "amber", name: "Amber", hex: 0xE8C07A),
        HeroSwatch(id: "ember", name: "Ember", hex: 0xFF6A2A),
        HeroSwatch(id: "frost", name: "Frost", hex: 0x8FD8FF),
        HeroSwatch(id: "jade", name: "Jade", hex: 0x6BE3A0),
        HeroSwatch(id: "violet", name: "Violet", hex: 0xC08CFF),
        HeroSwatch(id: "crimson", name: "Crimson", hex: 0xFF4A4A),
        HeroSwatch(id: "moon", name: "Moon", hex: 0xF2F2F2),
        HeroSwatch(id: "azure", name: "Azure", hex: 0x5A8CFF),
        HeroSwatch(id: "gold", name: "Gold", hex: 0xFFD84A),
        HeroSwatch(id: "rose", name: "Rose", hex: 0xFF7AC0),
    ]

    static let skin: [HeroSwatch] = [
        HeroSwatch(id: "fair", name: "Fair", hex: 0xE3C2A4),
        HeroSwatch(id: "sunlit", name: "Sunlit", hex: 0xD2A17A),
        HeroSwatch(id: "olive", name: "Olive", hex: 0xB98A5E),
        HeroSwatch(id: "brown", name: "Brown", hex: 0x8A5D3B),
        HeroSwatch(id: "deep", name: "Deep", hex: 0x5C3B26),
        HeroSwatch(id: "ashen", name: "Ashen", hex: 0x9C9A98),
        HeroSwatch(id: "verdant", name: "Verdant", hex: 0x7BA35E),
    ]

    static let hair: [HeroSwatch] = [
        HeroSwatch(id: "raven", name: "Raven", hex: 0x1C1719),
        HeroSwatch(id: "chestnut", name: "Chestnut", hex: 0x5A3A26),
        HeroSwatch(id: "auburn", name: "Auburn", hex: 0x8A3A22),
        HeroSwatch(id: "straw", name: "Straw", hex: 0xC9A65C),
        HeroSwatch(id: "silver", name: "Silver", hex: 0xC4C7CE),
        HeroSwatch(id: "snow", name: "Snow", hex: 0xEDEAE2),
        HeroSwatch(id: "midnight", name: "Midnight", hex: 0x2E4A8C),
        HeroSwatch(id: "rose", name: "Rose", hex: 0xD46A9A),
    ]

    static func swatch(_ id: String, in list: [HeroSwatch]) -> HeroSwatch {
        list.first { $0.id == id } ?? list[0]
    }
}

/// The hero's look: a body, a cloak, a head, five colours and three kinds of
/// extra (an emblem, metalwork and wings).
///
/// Purely cosmetic and saved on its own, apart from the Legacy board, so
/// nothing that happens to a run or a profile can cost a player the
/// character they made. Decoding is tolerant field by field for the same
/// reason the profile's is: adding an option later must not lose a save.
struct HeroAppearance: Codable, Equatable, Hashable {
    var build: BodyBuild = .standard
    var cloak: CloakStyle = .hooded
    var head: HeadStyle = .hood
    var cloakColor = HeroPalette.cloak[0].id
    var trimColor = HeroPalette.trim[0].id
    var eyeColor = HeroPalette.eyes[0].id
    var skinTone = HeroPalette.skin[0].id
    var hairColor = HeroPalette.hair[0].id
    var emblem: EmblemStyle = .plain
    var detail: MetalDetail = .plain
    var wings: WingStyle = .plain

    static let standard = HeroAppearance()

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        build = (try? values.decodeIfPresent(BodyBuild.self, forKey: .build)) ?? .standard
        cloak = (try? values.decodeIfPresent(CloakStyle.self, forKey: .cloak)) ?? .hooded
        head = (try? values.decodeIfPresent(HeadStyle.self, forKey: .head)) ?? .hood
        cloakColor = (try? values.decodeIfPresent(String.self, forKey: .cloakColor)) ?? cloakColor
        trimColor = (try? values.decodeIfPresent(String.self, forKey: .trimColor)) ?? trimColor
        eyeColor = (try? values.decodeIfPresent(String.self, forKey: .eyeColor)) ?? eyeColor
        skinTone = (try? values.decodeIfPresent(String.self, forKey: .skinTone)) ?? skinTone
        hairColor = (try? values.decodeIfPresent(String.self, forKey: .hairColor)) ?? hairColor
        emblem = (try? values.decodeIfPresent(EmblemStyle.self, forKey: .emblem)) ?? .plain
        detail = (try? values.decodeIfPresent(MetalDetail.self, forKey: .detail)) ?? .plain
        wings = (try? values.decodeIfPresent(WingStyle.self, forKey: .wings)) ?? .plain
    }

    var cloakSwatch: HeroSwatch { HeroPalette.swatch(cloakColor, in: HeroPalette.cloak) }
    var trimSwatch: HeroSwatch { HeroPalette.swatch(trimColor, in: HeroPalette.trim) }
    var eyeSwatch: HeroSwatch { HeroPalette.swatch(eyeColor, in: HeroPalette.eyes) }
    var skinSwatch: HeroSwatch { HeroPalette.swatch(skinTone, in: HeroPalette.skin) }
    var hairSwatch: HeroSwatch { HeroPalette.swatch(hairColor, in: HeroPalette.hair) }
}

/// Where the hero's look is kept between launches.
final class HeroStore {
    static let schemaVersion = 1
    private let store: VersionedFileStore<HeroAppearance>

    init(fileURL: URL? = nil) {
        let url = fileURL ?? SaveLocations.directory().appendingPathComponent("hero.json")
        store = VersionedFileStore(fileURL: url, currentVersion: Self.schemaVersion)
    }

    func load() -> HeroAppearance {
        store.load().payload ?? .standard
    }

    func erase() {
        store.erase()
    }

    @discardableResult
    func save(_ look: HeroAppearance) -> Bool {
        do {
            try store.save(look)
            return true
        } catch {
            return false
        }
    }
}
