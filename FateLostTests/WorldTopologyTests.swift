import CoreGraphics
import XCTest
@testable import FateLost

final class ToroidalWorldTests: XCTestCase {
    private let world = ToroidalWorld(width: 100, height: 50)

    func testWrapKeepsPointsInsideArena() {
        XCTAssertEqual(world.wrap(CGPoint(x: 105, y: -5)), CGPoint(x: 5, y: 45))
        XCTAssertEqual(world.wrap(CGPoint(x: -0.5, y: 50)), CGPoint(x: 99.5, y: 0))
        XCTAssertEqual(world.wrap(CGPoint(x: 250, y: 125)), CGPoint(x: 50, y: 25))
    }

    func testWrapNeverReturnsTheUpperBound() {
        let wrapped = ToroidalWorld.wrap(-1e-17, period: 100)
        XCTAssertLessThan(wrapped, 100)
        XCTAssertGreaterThanOrEqual(wrapped, 0)
    }

    func testDeltaTakesTheShortWayAcrossTheSeam() {
        let delta = world.delta(from: CGPoint(x: 98, y: 2), to: CGPoint(x: 3, y: 48))
        XCTAssertEqual(delta.x, 5, accuracy: 1e-9)
        XCTAssertEqual(delta.y, -4, accuracy: 1e-9)
    }

    func testDeltaWithinArenaIsUnchanged() {
        let delta = world.delta(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 30, y: 20))
        XCTAssertEqual(delta, CGPoint(x: 20, y: 10))
    }

    func testDistanceIsSymmetricAcrossSeam() {
        let a = CGPoint(x: 1, y: 1)
        let b = CGPoint(x: 99, y: 49)
        XCTAssertEqual(world.distance(a, b), world.distance(b, a), accuracy: 1e-9)
        XCTAssertEqual(world.distance(a, b), CGPoint(x: 2, y: 2).length, accuracy: 1e-9)
    }
}

final class IsometricProjectionTests: XCTestCase {
    private let projection = IsometricProjection(tileWidth: 80, tileHeight: 40)

    func testRoundTrip() {
        let points = [CGPoint(x: 3.5, y: -7.25), CGPoint(x: 0, y: 0), CGPoint(x: 120, y: 64)]
        for point in points {
            let back = projection.toWorld(projection.toScreen(point))
            XCTAssertEqual(back.x, point.x, accuracy: 1e-9)
            XCTAssertEqual(back.y, point.y, accuracy: 1e-9)
        }
    }

    func testUnitTileBecomesDiamondOfTileSize() {
        let right = projection.toScreen(CGPoint(x: 1, y: 0))
        let down = projection.toScreen(CGPoint(x: 0, y: 1))
        XCTAssertEqual(right, CGPoint(x: 40, y: -20))
        XCTAssertEqual(down, CGPoint(x: -40, y: -20))
    }

    func testPushingStickRightMovesCharacterRightOnScreen() {
        let world = projection.worldDirection(fromScreen: CGPoint(x: 1, y: 0))
        let screen = projection.toScreen(world)
        XCTAssertGreaterThan(screen.x, 0)
        XCTAssertEqual(screen.y, 0, accuracy: 1e-9)
        XCTAssertEqual(world.length, 1, accuracy: 1e-9)
    }

    func testPushingStickUpMovesCharacterUpOnScreen() {
        let screen = projection.toScreen(projection.worldDirection(fromScreen: CGPoint(x: 0, y: 1)))
        XCTAssertGreaterThan(screen.y, 0)
        XCTAssertEqual(screen.x, 0, accuracy: 1e-9)
    }

    func testWorldDirectionPreservesPartialMagnitude() {
        let world = projection.worldDirection(fromScreen: CGPoint(x: 0.3, y: 0.4))
        XCTAssertEqual(world.length, 0.5, accuracy: 1e-9)
    }
}

final class WrappedRenderFrameTests: XCTestCase {
    private let world = ToroidalWorld(width: 100, height: 100)

    func testFocusStaysContinuousWhenCrossingSeam() {
        var frame = WrappedRenderFrame(world: world, focus: CGPoint(x: 99, y: 50))
        frame.moveFocus(toWrapped: CGPoint(x: 1, y: 50))
        XCTAssertEqual(frame.focusUnwrapped.x, 101, accuracy: 1e-9)
        XCTAssertEqual(frame.focusWrapped.x, 1, accuracy: 1e-9)
    }

    func testObjectsAppearAtTheImageNearestTheFocus() {
        var frame = WrappedRenderFrame(world: world, focus: CGPoint(x: 98, y: 50))
        frame.moveFocus(toWrapped: CGPoint(x: 2, y: 50)) // unwrapped x = 102
        // An object at x = 5 must render just ahead of the player, not 97 behind.
        XCTAssertEqual(frame.unwrapped(CGPoint(x: 5, y: 50)).x, 105, accuracy: 1e-9)
        XCTAssertEqual(frame.unwrapped(CGPoint(x: 95, y: 50)).x, 95, accuracy: 1e-9)
    }

    func testRebaseShiftsByWholePeriodsOnly() {
        var frame = WrappedRenderFrame(world: world, focus: CGPoint(x: 50, y: 50))
        for step in 1...450 {
            frame.moveFocus(toWrapped: CGPoint(x: 50 + CGFloat(step), y: 50))
        }
        let before = frame.focusUnwrapped
        let shift = frame.rebaseIfNeeded(thresholdPeriods: 4)
        XCTAssertEqual(shift.x.truncatingRemainder(dividingBy: 100), 0, accuracy: 1e-9)
        XCTAssertGreaterThan(shift.x, 0)
        XCTAssertEqual(frame.focusUnwrapped.x, before.x - shift.x, accuracy: 1e-9)
        XCTAssertLessThan(abs(frame.focusUnwrapped.x), 100)
    }

    func testNoRebaseBelowThreshold() {
        var frame = WrappedRenderFrame(world: world, focus: CGPoint(x: 50, y: 50))
        XCTAssertEqual(frame.rebaseIfNeeded(thresholdPeriods: 4), .zero)
    }
}

final class ToroidalSpatialGridTests: XCTestCase {
    private let world = ToroidalWorld(width: 64, height: 64)

    func testQueryFindsNeighboursAcrossTheSeam() {
        var grid = ToroidalSpatialGrid(world: world, cellSize: 8)
        grid.insert(1, at: CGPoint(x: 63, y: 63))
        grid.insert(2, at: CGPoint(x: 32, y: 32))
        var results: [Int] = []
        grid.query(around: CGPoint(x: 1, y: 1), radius: 4, into: &results)
        XCTAssertTrue(results.contains(1))
        XCTAssertFalse(results.contains(2))
    }

    func testHugeRadiusVisitsEachBucketOnce() {
        var grid = ToroidalSpatialGrid(world: world, cellSize: 8)
        for id in 0..<50 {
            grid.insert(id, at: CGPoint(x: CGFloat(id), y: CGFloat(id)))
        }
        var results: [Int] = []
        grid.query(around: .zero, radius: 1000, into: &results)
        XCTAssertEqual(results.count, 50)
        XCTAssertEqual(Set(results).count, 50)
    }

    func testRemoveAllEmptiesTheGrid() {
        var grid = ToroidalSpatialGrid(world: world, cellSize: 8)
        grid.insert(7, at: CGPoint(x: 10, y: 10))
        grid.removeAll()
        XCTAssertEqual(grid.count, 0)
    }
}
