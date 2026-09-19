import Foundation

enum ItemRarity: Int, Codable, CaseIterable, Comparable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    static func < (lhs: ItemRarity, rhs: ItemRarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }

    var color: RGBA {
        switch self {
        case .common: return RGBA(hex: 0xC8C2B4)
        case .uncommon: return RGBA(hex: 0x6FBF5A)
        case .rare: return RGBA(hex: 0x4A8FE0)
        case .epic: return RGBA(hex: 0xA65BE0)
        case .legendary: return RGBA(hex: 0xE89B2E)
        }
    }
}
