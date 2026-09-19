import UIKit

/// How each effect style and damage type looks and sounds.
extension VisualStyle {
    var color: UIColor {
        switch self {
        case .physical: return UIColor(rgb: 0xE8E2D6)
        case .fire: return UIColor(rgb: 0xFF7A2A)
        case .frost: return UIColor(rgb: 0x8FD8FF)
        case .lightning: return UIColor(rgb: 0xC8D4FF)
        case .arcane: return UIColor(rgb: 0xA070FF)
        case .holy: return UIColor(rgb: 0xFFE08A)
        case .shadow: return UIColor(rgb: 0x9A5AE0)
        case .nature: return UIColor(rgb: 0x7FCB4A)
        case .poison: return UIColor(rgb: 0xA8E040)
        case .sonic: return UIColor(rgb: 0x5FE0C8)
        case .blood: return UIColor(rgb: 0xC0222A)
        case .fate: return UIColor(rgb: 0xFFC24A)
        }
    }

    /// Whether the effect glows (additive blending) rather than tints.
    var glows: Bool {
        switch self {
        case .physical, .blood: return false
        default: return true
        }
    }

    var sound: SoundCue {
        switch self {
        case .physical: return .abilityImpact
        case .fire: return .abilityFire
        case .frost: return .abilityFrost
        case .lightning: return .abilityLightning
        case .arcane: return .arcaneBurst
        case .holy: return .abilityHoly
        case .shadow, .blood: return .abilityShadow
        case .nature, .poison: return .abilityNature
        case .sonic: return .abilitySonic
        case .fate: return .abilityBuff
        }
    }
}

extension DamageType {
    /// Colour of damage numbers for this type.
    var numberColor: UIColor {
        switch self {
        case .physical: return UIColor(rgb: 0xF3E9D8)
        case .fire: return UIColor(rgb: 0xFF9A4A)
        case .cold: return UIColor(rgb: 0xA8E2FF)
        case .lightning: return UIColor(rgb: 0xD8E0FF)
        case .arcane: return UIColor(rgb: 0xC8A8FF)
        case .holy: return UIColor(rgb: 0xFFE8A0)
        case .shadow: return UIColor(rgb: 0xC8A0F0)
        case .poison: return UIColor(rgb: 0xB8F060)
        }
    }
}

extension StatusKind {
    /// Tint an afflicted enemy takes on, strongest first.
    var tint: UIColor? {
        switch self {
        case .freeze: return UIColor(rgb: 0x9AE0FF)
        case .burn: return UIColor(rgb: 0xFF7A2A)
        case .poison: return UIColor(rgb: 0x9AE040)
        case .chill: return UIColor(rgb: 0x8FC8FF)
        case .shock: return UIColor(rgb: 0xD8E0FF)
        case .curse: return UIColor(rgb: 0x8A3AB0)
        case .confuse: return UIColor(rgb: 0xFF8AD8)
        case .fear: return UIColor(rgb: 0x5A5A7A)
        case .stun: return UIColor(rgb: 0xFFF0A0)
        case .root: return UIColor(rgb: 0x6A8A3A)
        case .bleed: return UIColor(rgb: 0xC0222A)
        case .weaken: return UIColor(rgb: 0x6A6A6A)
        case .mark: return nil
        }
    }

    /// Order in which tints win when several statuses are active.
    static let tintPriority: [StatusKind] = [.freeze, .stun, .confuse, .fear, .burn, .poison, .curse, .shock,
                                             .chill, .root, .bleed, .weaken]
}
