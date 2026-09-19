import SpriteKit
import SwiftUI

/// Hosts a `GameScene` in SwiftUI.
///
/// Uses a custom `SKView` rather than SwiftUI's `SpriteView` so that
/// multi-touch (move and use abilities at once) and safe-area changes are
/// under our control.
struct GameViewContainer: UIViewRepresentable {
    let scene: GameScene
    let showsDebugStatistics: Bool

    func makeUIView(context: Context) -> GameSKView {
        let view = GameSKView()
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        view.showsFPS = showsDebugStatistics
        view.showsNodeCount = showsDebugStatistics
        view.showsDrawCount = showsDebugStatistics
        view.onSafeAreaChange = { [weak scene] insets in
            scene?.updateSafeArea(insets)
        }
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: GameSKView, context: Context) {
        view.showsFPS = showsDebugStatistics
        view.showsNodeCount = showsDebugStatistics
        view.showsDrawCount = showsDebugStatistics
        if view.scene !== scene {
            view.presentScene(scene)
        }
    }

    static func dismantleUIView(_ view: GameSKView, coordinator: ()) {
        view.presentScene(nil)
    }
}

/// `SKView` that reports safe-area changes (rotation, notch side) to the scene.
final class GameSKView: SKView {
    var onSafeAreaChange: ((UIEdgeInsets) -> Void)?

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onSafeAreaChange?(safeAreaInsets)
    }
}
