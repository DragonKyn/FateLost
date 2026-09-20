import CoreGraphics
import Foundation

/// How the hero is built. It changes how they look and where the weapon
/// sits in the hand, and nothing else: no build is stronger, faster or
/// tougher than another. A body is a choice about who you are, not a stat.
enum BodyBuild: String, Codable, CaseIterable, Identifiable {
    case lithe
    case standard
    case broad

    var id: String { rawValue }

    var name: String {
        switch self {
        case .lithe: return "Lithe"
        case .standard: return "Wanderer"
        case .broad: return "Broad"
        }
    }

    var blurb: String {
        switch self {
        case .lithe: return "Tall, narrow, quick to vanish."
        case .standard: return "Nothing remarkable. Yet."
        case .broad: return "Shoulders made for carrying things."
        }
    }

    /// Where the weapon is held, from the feet up.
    var hand: CGPoint {
        switch self {
        case .lithe: return CGPoint(x: 10, y: 21)
        case .standard: return CGPoint(x: 11.5, y: 20)
        case .broad: return CGPoint(x: 14.5, y: 19)
        }
    }
}

enum CloakStyle: String, Codable, CaseIterable, Identifiable {
    case hooded
    case mantle
    case longCoat
    case shroud
    case pilgrim

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hooded: return "Wayfarer's Cloak"
        case .mantle: return "Short Mantle"
        case .longCoat: return "Long Coat"
        case .shroud: return "Tattered Shroud"
        case .pilgrim: return "Pilgrim's Cape"
        }
    }

    var blurb: String {
        switch self {
        case .hooded: return "Hangs straight, and has seen weather."
        case .mantle: return "Over the shoulders, out of the way."
        case .longCoat: return "Buttoned to the knee."
        case .shroud: return "Torn by things that did not let go."
        case .pilgrim: return "A high collar and a long road."
        }
    }
}

enum HeadStyle: String, Codable, CaseIterable, Identifiable {
    case hood
    case cowl
    case bare
    case helm

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hood: return "Deep Hood"
        case .cowl: return "Veiled Cowl"
        case .bare: return "Bare Head"
        case .helm: return "Iron Helm"
        }
    }

    var blurb: String {
        switch self {
        case .hood: return "A face left to the dark."
        case .cowl: return "Cloth across the mouth."
        case .bare: return "Nothing to hide. Nothing to hide behind."
        case .helm: return "Dented, and still on."
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
/// choice can never point at something that is gone.
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
    ]

    static let trim: [HeroSwatch] = [
        HeroSwatch(id: "brass", name: "Brass", hex: 0xC9A55A),
        HeroSwatch(id: "silver", name: "Silver", hex: 0xB9BEC8),
        HeroSwatch(id: "ember", name: "Ember", hex: 0xE0782A),
        HeroSwatch(id: "bone", name: "Bone", hex: 0xDCD3BF),
        HeroSwatch(id: "verdigris", name: "Verdigris", hex: 0x4FB39A),
        HeroSwatch(id: "blood", name: "Blood", hex: 0xA12222),
        HeroSwatch(id: "gold", name: "Gold", hex: 0xF0C94A),
    ]

    static let eyes: [HeroSwatch] = [
        HeroSwatch(id: "amber", name: "Amber", hex: 0xE8C07A),
        HeroSwatch(id: "ember", name: "Ember", hex: 0xFF6A2A),
        HeroSwatch(id: "frost", name: "Frost", hex: 0x8FD8FF),
        HeroSwatch(id: "jade", name: "Jade", hex: 0x6BE3A0),
        HeroSwatch(id: "violet", name: "Violet", hex: 0xC08CFF),
        HeroSwatch(id: "crimson", name: "Crimson", hex: 0xFF4A4A),
        HeroSwatch(id: "moon", name: "Moon", hex: 0xF2F2F2),
    ]

    static let skin: [HeroSwatch] = [
        HeroSwatch(id: "fair", name: "Fair", hex: 0xE3C2A4),
        HeroSwatch(id: "sunlit", name: "Sunlit", hex: 0xD2A17A),
        HeroSwatch(id: "olive", name: "Olive", hex: 0xB98A5E),
        HeroSwatch(id: "brown", name: "Brown", hex: 0x8A5D3B),
        HeroSwatch(id: "deep", name: "Deep", hex: 0x5C3B26),
        HeroSwatch(id: "ashen", name: "Ashen", hex: 0x9C9A98),
    ]

    static let hair: [HeroSwatch] = [
        HeroSwatch(id: "raven", name: "Raven", hex: 0x1C1719),
        HeroSwatch(id: "chestnut", name: "Chestnut", hex: 0x5A3A26),
        HeroSwatch(id: "auburn", name: "Auburn", hex: 0x8A3A22),
        HeroSwatch(id: "straw", name: "Straw", hex: 0xC9A65C),
        HeroSwatch(id: "silver", name: "Silver", hex: 0xC4C7CE),
        HeroSwatch(id: "snow", name: "Snow", hex: 0xEDEAE2),
    ]

    static func swatch(_ id: String, in list: [HeroSwatch]) -> HeroSwatch {
        list.first { $0.id == id } ?? list[0]
    }
}

/// The hero's look: a body, a cloak, a head and five colours.
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
