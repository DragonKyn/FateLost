import UIKit

/// Moments important enough to be felt.
enum HapticEvent {
    case uiTap
    case levelUp
    case majorDamage
    case criticalHit
    case bossAppears
    case legendaryItem
    case realmConquered
    case playerDeath
}

@MainActor
protocol HapticsProviding: AnyObject {
    func play(_ event: HapticEvent)
}

/// UIKit feedback generators, gated by the player's settings.
///
/// Generators are created once and reused, as Apple recommends, so triggering
/// feedback during heavy combat allocates nothing.
@MainActor
final class HapticsService: HapticsProviding {
    private let isEnabled: () -> Bool
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
    }

    func play(_ event: HapticEvent) {
        guard isEnabled() else { return }
        switch event {
        case .uiTap:
            light.impactOccurred(intensity: 0.6)
        case .criticalHit:
            rigid.impactOccurred(intensity: 0.7)
        case .majorDamage:
            heavy.impactOccurred(intensity: 0.9)
        case .levelUp, .legendaryItem:
            notification.notificationOccurred(.success)
        case .bossAppears:
            heavy.impactOccurred(intensity: 1)
        case .realmConquered:
            notification.notificationOccurred(.success)
        case .playerDeath:
            notification.notificationOccurred(.error)
        }
    }
}
