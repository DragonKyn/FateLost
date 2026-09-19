import Foundation

/// Converts variable frame deltas into a whole number of fixed simulation steps.
///
/// Simulation always advances in identical increments, which keeps movement,
/// cooldowns and (later) combat deterministic and frame-rate independent. The
/// accumulator is capped so a long hitch (backgrounding, a debugger pause)
/// cannot trigger a catch-up spiral.
struct FixedTimestep {
    let step: TimeInterval
    let maxStepsPerFrame: Int

    private(set) var accumulator: TimeInterval = 0

    /// Absorbs floating-point drift so a frame exactly one step long always
    /// produces exactly one step.
    private static let epsilon: TimeInterval = 1e-9

    init(step: TimeInterval, maxStepsPerFrame: Int) {
        precondition(step > 0, "Timestep must be positive")
        precondition(maxStepsPerFrame > 0, "At least one step per frame is required")
        self.step = step
        self.maxStepsPerFrame = maxStepsPerFrame
    }

    /// Adds a frame's elapsed time and returns how many steps to simulate now.
    mutating func advance(by frameDelta: TimeInterval) -> Int {
        accumulator += max(0, frameDelta)
        accumulator = min(accumulator, step * Double(maxStepsPerFrame))

        var steps = 0
        while accumulator + Self.epsilon >= step {
            accumulator = max(0, accumulator - step)
            steps += 1
        }
        return steps
    }

    /// Fraction of a step left over, for render interpolation.
    var interpolationAlpha: Double { accumulator / step }

    mutating func reset() {
        accumulator = 0
    }
}
