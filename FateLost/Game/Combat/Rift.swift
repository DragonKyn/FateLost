import CoreGraphics
import Foundation

/// The rare portals that open when a champion falls, and where they lead.
///
/// Each takes the whole party out of the world for a fight against something far
/// bigger than any champion, alone in an empty stretch of the map with nothing
/// else to fight. Win, and a way home opens where the great one fell, with a
/// great deal of experience and a find that is at least epic and may be legendary.
enum RiftKind: Int, CaseIterable, Equatable {
    case cinders
    case tides
    case winter
    case void

    var name: String {
        switch self {
        case .cinders: return "Rift of Cinders"
        case .tides: return "Rift of Tides"
        case .winter: return "Rift of Winter"
        case .void: return "Rift of the Void"
        }
    }

    /// Who waits on the far side.
    var bossID: EnemyKindID {
        switch self {
        case .cinders: return "boss.rift.forge"
        case .tides: return "boss.rift.matriarch"
        case .winter: return "boss.rift.sovereign"
        case .void: return "boss.rift.unblinking"
        }
    }

    /// The colour of the portal, and of the light the rift casts over the screen.
    var tint: UInt32 {
        switch self {
        case .cinders: return 0xFF7A2A
        case .tides: return 0x3ACFC0
        case .winter: return 0x9FD8FF
        case .void: return 0xFF5A8A
        }
    }
}

/// A way through: into a rift, or back out of one.
struct Portal: Equatable {
    var id: Int
    var kind: RiftKind
    var position: CGPoint
    /// The way home from a fight, rather than the way in.
    var isReturn: Bool
    /// Seconds since it opened.
    var age: Double = 0
}

/// A fight in progress on the far side of a rift.
struct RiftFight: Equatable {
    enum Stage: Equatable {
        /// The party has arrived and the great one has not yet.
        case arriving
        case fighting
        /// It has fallen and the way home is open.
        case won
    }

    var kind: RiftKind
    var stage: Stage = .arriving
    /// Seconds left of the arrival, before the boss appears.
    var timer: Double
    var bossID: Int?
    /// Where the party landed, and where each hero stood before, to go back to.
    var centre: CGPoint
    var origins: [Int: CGPoint]
    /// Where the boss last stood, for the way home.
    var lastBossPosition: CGPoint
    /// The wave clock as it was, so the world carries on from where it left off.
    var savedWave: WaveState
}

enum RiftTuning {
    /// Chance that a fallen champion (short of a realm's last) opens a portal.
    static let chance = 0.10
    /// Seconds an unentered portal stays open.
    static let lifetime: Double = 90
    /// How close a hero must come to step through.
    static let touchDistance: CGFloat = 1.4
    /// Seconds between arriving and the great one appearing.
    static let arrivalSeconds: Double = 3.5
    /// Experience for the win, as a multiple of what one level takes.
    static let experienceMultiple = 2.5
    /// Seconds of immunity on stepping through either way.
    static let immunity: Double = 2.5
    /// How far from the middle of the party's landing the great one appears.
    static let bossDistance: CGFloat = 11
}
