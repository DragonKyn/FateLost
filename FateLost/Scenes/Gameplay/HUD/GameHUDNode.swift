import SpriteKit

/// Screen-space controls drawn by SpriteKit: the joystick and ability sockets.
///
/// These live in SpriteKit rather than SwiftUI because they must respond to
/// multi-touch with no latency. Informational HUD (health, XP, wave) is drawn
/// by SwiftUI over the game view instead, where text and layout are cheaper
/// to build and restyle.
@MainActor
final class GameHUDNode: SKNode {
    let joystick = VirtualJoystickNode()
    private let beacons = BeaconLayer()
    private let abilityButtons = (0..<3).map { _ in AbilityButtonNode(isUltimate: false) }
    private let ultimateButton = AbilityButtonNode(isUltimate: true)

    private(set) var layout: HUDLayout?

    override init() {
        super.init()
        zPosition = DepthSorting.Band.hud
        addChild(beacons)
        addChild(joystick)
        for button in abilityButtons {
            addChild(button)
        }
        addChild(ultimateButton)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("GameHUDNode is created in code")
    }

    func apply(_ layout: HUDLayout) {
        self.layout = layout
        joystick.configure(radius: layout.joystickRadius)
        for (button, center) in zip(abilityButtons, layout.abilitySlots) {
            button.configure(diameter: layout.abilityButtonSize)
            button.position = center
        }
        ultimateButton.configure(diameter: layout.ultimateButtonSize)
        ultimateButton.position = layout.ultimateSlot
    }

    /// Points at anything worth walking to that is off the edge of the screen.
    func showBeacons(_ marks: [BeaconMark], screenSize: CGSize, time: TimeInterval) {
        beacons.show(marks, screenSize: screenSize, time: time)
    }

    /// Animates a press on slot 0–2, or 3 for the ultimate.
    func pulseAbility(_ slot: Int) {
        if slot < abilityButtons.count {
            abilityButtons[slot].pulse()
        } else {
            ultimateButton.pulse()
        }
    }

    /// - Parameter slots: Display state for slots 0–2 followed by the ultimate.
    func showAbilities(_ slots: [AbilitySlotDisplay]) {
        for (index, button) in abilityButtons.enumerated() {
            button.render(index < slots.count ? slots[index] : .empty)
        }
        ultimateButton.render(slots.count > 3 ? slots[3] : .empty)
    }
}
