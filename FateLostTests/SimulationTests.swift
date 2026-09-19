import CoreGraphics
import XCTest
@testable import FateLost

final class FixedTimestepTests: XCTestCase {
    func testExactFrameProducesOneStep() {
        var timestep = FixedTimestep(step: 1.0 / 60.0, maxStepsPerFrame: 5)
        XCTAssertEqual(timestep.advance(by: 1.0 / 60.0), 1)
    }

    func testAccumulatesShortFrames() {
        var timestep = FixedTimestep(step: 0.01, maxStepsPerFrame: 5)
        XCTAssertEqual(timestep.advance(by: 0.006), 0)
        XCTAssertEqual(timestep.advance(by: 0.006), 1)
        XCTAssertEqual(timestep.interpolationAlpha, 0.2, accuracy: 1e-6)
    }

    func testLongHitchIsCapped() {
        var timestep = FixedTimestep(step: 0.01, maxStepsPerFrame: 5)
        XCTAssertEqual(timestep.advance(by: 10), 5)
        XCTAssertEqual(timestep.advance(by: 0), 0)
    }

    func testNegativeDeltaIsIgnored() {
        var timestep = FixedTimestep(step: 0.01, maxStepsPerFrame: 5)
        XCTAssertEqual(timestep.advance(by: -1), 0)
        XCTAssertEqual(timestep.accumulator, 0)
    }
}

final class MovementSystemTests: XCTestCase {
    private let tuning = PlayerTuning()
    private let world = ToroidalWorld(width: 128, height: 128)

    func testReachesButNeverExceedsMaxSpeed() {
        let system = MovementSystem(tuning: tuning)
        var player = PlayerState(position: world.center, maxHealth: 100)
        for _ in 0..<120 {
            system.step(&player, intent: PlayerIntent(move: CGPoint(x: 1, y: 0)), speedMultiplier: 1,
                        world: world, dt: 1.0 / 60.0)
        }
        XCTAssertEqual(player.velocity.length, tuning.baseMoveSpeed, accuracy: 1e-6)
    }

    func testOverlongInputIsClampedToFullSpeed() {
        let system = MovementSystem(tuning: tuning)
        var player = PlayerState(position: world.center, maxHealth: 100)
        for _ in 0..<120 {
            system.step(&player, intent: PlayerIntent(move: CGPoint(x: 5, y: 5)), speedMultiplier: 1,
                        world: world, dt: 1.0 / 60.0)
        }
        XCTAssertEqual(player.velocity.length, tuning.baseMoveSpeed, accuracy: 1e-6)
    }

    func testStopsWhenInputReleased() {
        let system = MovementSystem(tuning: tuning)
        var player = PlayerState(position: world.center, maxHealth: 100)
        player.velocity = CGPoint(x: tuning.baseMoveSpeed, y: 0)
        for _ in 0..<30 {
            system.step(&player, intent: .idle, speedMultiplier: 1, world: world, dt: 1.0 / 60.0)
        }
        XCTAssertEqual(player.velocity, .zero)
    }

    func testPositionWrapsAtArenaEdge() {
        let system = MovementSystem(tuning: tuning)
        var player = PlayerState(position: CGPoint(x: 127.99, y: 10), maxHealth: 100)
        player.velocity = CGPoint(x: tuning.baseMoveSpeed, y: 0)
        system.step(&player, intent: PlayerIntent(move: CGPoint(x: 1, y: 0)), speedMultiplier: 1,
                    world: world, dt: 1.0 / 60.0)
        XCTAssertLessThan(player.position.x, 1)
        XCTAssertGreaterThanOrEqual(player.position.x, 0)
    }

    func testSpeedMultiplierScalesTopSpeed() {
        let system = MovementSystem(tuning: tuning)
        var player = PlayerState(position: world.center, maxHealth: 100)
        for _ in 0..<120 {
            system.step(&player, intent: PlayerIntent(move: CGPoint(x: 0, y: 1)), speedMultiplier: 1.5,
                        world: world, dt: 1.0 / 60.0)
        }
        XCTAssertEqual(player.velocity.length, tuning.baseMoveSpeed * 1.5, accuracy: 1e-6)
    }
}

final class JoystickModelTests: XCTestCase {
    func testDeadZoneProducesNoOutput() {
        var stick = JoystickModel(radius: 50, deadZone: 0.2, followsThumb: false)
        stick.begin(at: .zero)
        stick.move(to: CGPoint(x: 5, y: 0))
        XCTAssertEqual(stick.output, .zero)
    }

    func testFullDeflectionIsUnitLength() {
        var stick = JoystickModel(radius: 50, deadZone: 0.2, followsThumb: false)
        stick.begin(at: .zero)
        stick.move(to: CGPoint(x: 0, y: 200))
        XCTAssertEqual(stick.output.length, 1, accuracy: 1e-9)
        XCTAssertEqual(stick.knobOffset.length, 50, accuracy: 1e-9)
    }

    func testOutputRescalesPastDeadZone() {
        var stick = JoystickModel(radius: 100, deadZone: 0.2, followsThumb: false)
        stick.begin(at: .zero)
        stick.move(to: CGPoint(x: 60, y: 0))
        // (0.6 - 0.2) / (1 - 0.2) = 0.5
        XCTAssertEqual(stick.output.x, 0.5, accuracy: 1e-9)
    }

    func testBaseFollowsThumbPastRim() {
        var stick = JoystickModel(radius: 50, deadZone: 0.1, followsThumb: true)
        stick.begin(at: .zero)
        stick.move(to: CGPoint(x: 80, y: 0))
        XCTAssertEqual(stick.base.x, 30, accuracy: 1e-9)
        // Reversing now needs only a short drag back.
        stick.move(to: CGPoint(x: 20, y: 0))
        XCTAssertLessThan(stick.output.x, 0)
    }

    func testReleaseStopsOutput() {
        var stick = JoystickModel(radius: 50, deadZone: 0.1, followsThumb: false)
        stick.begin(at: .zero)
        stick.move(to: CGPoint(x: 50, y: 0))
        stick.end()
        XCTAssertFalse(stick.isActive)
        XCTAssertEqual(stick.output, .zero)
    }
}

final class HUDLayoutTests: XCTestCase {
    func testControlsStayOnScreenOnPhoneAndPad() {
        let sizes = [CGSize(width: 667, height: 375), CGSize(width: 932, height: 430), CGSize(width: 1366, height: 1024)]
        for size in sizes {
            let layout = HUDLayout(screenSize: size, insets: ScreenInsets(top: 0, left: 59, bottom: 21, right: 59),
                                   tuning: ControlsTuning())
            let halfWidth = size.width / 2
            let halfHeight = size.height / 2
            for slot in layout.abilitySlots + [layout.ultimateSlot, layout.joystickRest] {
                XCTAssertLessThan(abs(slot.x), halfWidth, "slot off-screen horizontally on \(size)")
                XCTAssertLessThan(abs(slot.y), halfHeight, "slot off-screen vertically on \(size)")
            }
        }
    }

    func testControlsScaleUpOnLargerScreensWithinLimit() {
        let tuning = ControlsTuning()
        let phone = HUDLayout(screenSize: CGSize(width: 844, height: 390), insets: .zero, tuning: tuning)
        let pad = HUDLayout(screenSize: CGSize(width: 1366, height: 1024), insets: .zero, tuning: tuning)
        XCTAssertEqual(phone.controlScale, 1, accuracy: 1e-9)
        XCTAssertGreaterThan(pad.controlScale, phone.controlScale)
        XCTAssertLessThanOrEqual(pad.controlScale, tuning.maximumControlScale)
    }

    func testAbilityHitTesting() {
        let layout = HUDLayout(screenSize: CGSize(width: 844, height: 390), insets: .zero, tuning: ControlsTuning())
        XCTAssertEqual(layout.abilitySlot(at: layout.ultimateSlot), 3)
        XCTAssertEqual(layout.abilitySlot(at: layout.abilitySlots[1]), 1)
        XCTAssertNil(layout.abilitySlot(at: .zero))
    }
}
