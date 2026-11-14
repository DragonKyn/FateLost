import Foundation

/// How a melee weapon's attack looks: each family of weapon has its own
/// signature trail, so a katana, a war hammer and a whip never read the
/// same on screen. Purely visual; the hit itself is decided by the weapon.
///
/// Carried on the wire as its raw value, so cases are only ever added.
enum SwingStyle: UInt8, CaseIterable {
    /// A clean crescent: the sword, and anything without a style of its own.
    case blade
    /// A broad, slow arc that cracks the ground: claymore, war hammer, heavy axe.
    case heavy
    /// A hairline cut followed by a flash across it: the katana.
    case quick
    /// Two blades crossing in an X: dual daggers.
    case twin
    /// Three parallel rakes: hand claws, sai.
    case claw
    /// A straight lunge with a wake behind it: spear, lance.
    case thrust
    /// A long dark crescent that trails wisps: scythe, halberd.
    case reap
    /// A cracking curve with a snap at the tip: whip, flail, nunchaku.
    case lash
    /// A full turn around the hero: bo staff.
    case spin

    /// The style a weapon swings with, from its art (so a weapon found in a
    /// run swings like the kind of weapon it is) and, failing that, its arc.
    static func of(_ sprite: SpriteID, arcDegrees: Double) -> SwingStyle {
        switch sprite {
        case .weaponClaymore, .weaponWarHammer, .weaponHeavyAxe: return .heavy
        case .weaponKatana: return .quick
        case .weaponDualDaggers: return .twin
        case .weaponHandClaws, .weaponSai: return .claw
        case .weaponSpear, .weaponLance: return .thrust
        case .weaponScythe, .weaponHalberd: return .reap
        case .weaponWhip, .weaponFlail, .weaponNunchaku: return .lash
        case .weaponBoStaff: return .spin
        default: return arcDegrees <= 25 ? .thrust : .blade
        }
    }
}
