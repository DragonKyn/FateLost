import CoreGraphics

/// Bridges wrapped simulation space and the continuous space the camera sees.
///
/// The simulation keeps every position inside the arena rectangle. If the
/// renderer used those positions directly, the camera would snap across the
/// map whenever the player crossed a seam. Instead the frame tracks an
/// *unwrapped* focus that accumulates the player's true motion, and places
/// everything else at `focus + shortestDelta(focus, thing)`. Every object is
/// drawn at the copy of itself nearest the player, the camera never jumps, and
/// there is no teleport flash — the world simply loops.
///
/// The unwrapped focus can drift arbitrarily far during a long run, so
/// `rebaseIfNeeded` periodically pulls it back by whole world periods. That
/// shift is invisible because the camera is moved by exactly the same amount.
struct WrappedRenderFrame {
    let world: ToroidalWorld
    private(set) var focusWrapped: CGPoint
    private(set) var focusUnwrapped: CGPoint

    init(world: ToroidalWorld, focus: CGPoint) {
        self.world = world
        let wrapped = world.wrap(focus)
        focusWrapped = wrapped
        focusUnwrapped = wrapped
    }

    /// Follows the focus to its new wrapped position, accumulating the short
    /// way round so the unwrapped focus moves continuously.
    mutating func moveFocus(toWrapped newFocus: CGPoint) {
        let wrapped = world.wrap(newFocus)
        focusUnwrapped += world.delta(from: focusWrapped, to: wrapped)
        focusWrapped = wrapped
    }

    /// Unwrapped position of the image of `wrappedPoint` nearest the focus.
    func unwrapped(_ wrappedPoint: CGPoint) -> CGPoint {
        focusUnwrapped + world.delta(from: focusWrapped, to: wrappedPoint)
    }

    /// Shifts the unwrapped focus back toward the origin once it has drifted
    /// more than `thresholdPeriods` world sizes away.
    ///
    /// - Returns: The world-space offset that was *subtracted*, or `.zero`.
    ///   Callers must move anything positioned in unwrapped space (the
    ///   camera, cached node positions) by the same amount.
    mutating func rebaseIfNeeded(thresholdPeriods: CGFloat) -> CGPoint {
        let limitX = world.width * thresholdPeriods
        let limitY = world.height * thresholdPeriods
        guard abs(focusUnwrapped.x) > limitX || abs(focusUnwrapped.y) > limitY else {
            return .zero
        }
        let shift = CGPoint(
            x: (focusUnwrapped.x / world.width).rounded(.towardZero) * world.width,
            y: (focusUnwrapped.y / world.height).rounded(.towardZero) * world.height
        )
        focusUnwrapped -= shift
        return shift
    }
}
