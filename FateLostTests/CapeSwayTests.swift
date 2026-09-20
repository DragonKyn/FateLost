import CoreGraphics
import XCTest
@testable import FateLost

/// The cloak lags, swings and settles; it never stretches, spins or folds over,
/// and armour and the head, which are not cloth, are not part of it.
final class CapeSwayTests: XCTestCase {
    private let frame: CGFloat = 1.0 / 60

    private func run(_ sway: inout CapeSway, seconds: Double, velocity: CGPoint, from start: Double = 0) {
        var time = start
        for _ in 0..<Int(seconds * 60) {
            sway.step(dt: frame, velocity: velocity, time: time)
            time += Double(frame)
        }
    }

    func testAStandingHeroHasOnlyABreathOfMovement() {
        var sway = CapeSway()
        run(&sway, seconds: 4, velocity: .zero)
        XCTAssertLessThan(abs(sway.offset.x), 0.6, "idle sway must be barely there")
        XCTAssertLessThan(abs(sway.offset.y), 0.05)
    }

    func testTheCloakTrailsBehindAWalkingHero() {
        var sway = CapeSway()
        // Walking the way the hero faces at full speed: the hem hangs behind.
        run(&sway, seconds: 1, velocity: CGPoint(x: 120, y: 0))
        XCTAssertLessThan(sway.offset.x, -2.5)
        XCTAssertGreaterThan(sway.offset.x, -CapeSway.maxHorizontal * 1.16)
    }

    func testTurningSwingsTheCloakAcrossAndItSettles() {
        var sway = CapeSway()
        run(&sway, seconds: 1, velocity: CGPoint(x: 120, y: 0))
        let before = sway.offset.x
        var peak: CGFloat = 0
        var time = 1.0
        for _ in 0..<90 {
            sway.step(dt: frame, velocity: CGPoint(x: -120, y: 0), time: time)
            time += Double(frame)
            peak = max(peak, abs(sway.offset.x))
        }
        XCTAssertLessThan(before, 0)
        XCTAssertGreaterThan(sway.offset.x, 2.5, "it swung to the other side")
        XCTAssertLessThanOrEqual(peak, CapeSway.maxHorizontal * 1.16, "an overshoot must stay inside the limit")
    }

    func testItSettlesOnceTheHeroStops() {
        var sway = CapeSway()
        run(&sway, seconds: 1, velocity: CGPoint(x: 120, y: 60))
        run(&sway, seconds: 1.6, velocity: .zero, from: 1)
        XCTAssertLessThan(abs(sway.offset.x), 0.7)
        XCTAssertLessThan(abs(sway.offset.y), 0.1)
    }

    func testNoInputCanStretchOrFlingIt() {
        var sway = CapeSway()
        // Absurd speeds, wild reversals and a stalled frame of several seconds.
        for index in 0..<600 {
            let sign: CGFloat = index % 7 < 3 ? 1 : -1
            sway.step(dt: index % 90 == 0 ? 5 : frame, velocity: CGPoint(x: sign * 50_000, y: -sign * 50_000),
                      time: Double(index) / 60)
            XCTAssertTrue(sway.offset.x.isFinite && sway.offset.y.isFinite)
            XCTAssertLessThanOrEqual(abs(sway.offset.x), CapeSway.maxHorizontal * 1.15 + 0.0001)
            XCTAssertLessThanOrEqual(abs(sway.offset.y), CapeSway.maxVertical * 1.15 + 0.0001)
        }
        sway.reset()
        XCTAssertEqual(sway.offset, .zero)
    }

    func testTheBendKeepsTheShouldersStillAndMovesTheHem() {
        var sway = CapeSway()
        run(&sway, seconds: 1, velocity: CGPoint(x: 120, y: 0))
        let warp = sway.warp(imageSize: CGSize(width: 64, height: 80), cloth: 1)
        XCTAssertEqual(warp.source.count, 8)
        XCTAssertEqual(warp.destination.count, 8)
        // Top row: the hood and shoulders do not move.
        XCTAssertEqual(warp.destination[6], warp.source[6])
        XCTAssertEqual(warp.destination[7], warp.source[7])
        // Hem row: moved by the whole sway, both corners alike.
        let hem = warp.destination[0].x - warp.source[0].x
        XCTAssertEqual(hem, Float(sway.offset.x / 64), accuracy: 0.0001)
        XCTAssertEqual(warp.destination[1].x - warp.source[1].x, hem, accuracy: 0.0001)
        // Every row moves less than the one below it: a smooth hang, not a snap.
        let shifts = stride(from: 0, to: 8, by: 2).map { abs(warp.destination[$0].x - warp.source[$0].x) }
        XCTAssertEqual(shifts, shifts.sorted(by: >))
        // Sources are the unit square in order: bottom left to top right.
        XCTAssertEqual(warp.source[0], SIMD2<Float>(0, 0))
        XCTAssertEqual(warp.source[7], SIMD2<Float>(1, 1))
    }

    func testRigidThingsDoNotMove() {
        var sway = CapeSway()
        run(&sway, seconds: 1, velocity: CGPoint(x: 120, y: 0))
        let rigid = sway.warp(imageSize: CGSize(width: 64, height: 80), cloth: 0)
        XCTAssertEqual(rigid.source, rigid.destination)
    }

    func testEveryCloakSaysHowFreelyItHangsAndArmourHangsLeast() {
        for cloak in CloakStyle.allCases {
            XCTAssertGreaterThan(cloak.clothiness, 0, "\(cloak) never moves at all")
            XCTAssertLessThanOrEqual(cloak.clothiness, 1)
        }
        XCTAssertEqual(CloakStyle.hooded.clothiness, 1)
        XCTAssertLessThan(CloakStyle.paladin.clothiness, CloakStyle.hooded.clothiness / 2)
        XCTAssertLessThan(CloakStyle.samurai.clothiness, CloakStyle.mantle.clothiness)
    }

    func testTheCostOfAMinuteOfSwayForAFullPartyIsSmall() {
        var swayers = [CapeSway](repeating: CapeSway(), count: 4)
        measure {
            var time = 0.0
            for _ in 0..<3600 {
                for index in swayers.indices {
                    swayers[index].step(dt: frame, velocity: CGPoint(x: 100 * CGFloat(index), y: 20), time: time)
                }
                time += Double(frame)
            }
        }
    }

    // MARK: The drawing

    func testTheThreePiecesMakeUpTheWholeFigureOnTheSameCanvas() {
        for build in BodyBuild.allCases {
            for cloak in CloakStyle.allCases {
                var look = HeroAppearance()
                look.build = build
                look.cloak = cloak
                look.wings = .angel
                look.detail = .warPlate
                let pieces = PlaceholderArt.heroPieces(look)
                for piece in [pieces.behind, pieces.cloak, pieces.front] {
                    XCTAssertEqual(piece.image.size, PlaceholderArt.heroCanvas, "\(build) \(cloak)")
                }
                XCTAssertEqual(pieces.cloak.anchor, PlaceholderArt.hero(look).anchor)
            }
        }
        XCTAssertNotNil(PlaceholderArt.sprite(for: .playerBehind))
        XCTAssertNotNil(PlaceholderArt.sprite(for: .playerCloak))
        XCTAssertNotNil(PlaceholderArt.sprite(for: .playerFront))
    }

    func testEveryAngelAndDemonWingDrawsOnEveryBuildWithinTheCanvas() {
        for build in BodyBuild.allCases {
            for wings in [WingStyle.angel, WingStyle.demon] {
                var look = HeroAppearance()
                look.build = build
                look.wings = wings
                let behind = PlaceholderArt.heroPieces(look).behind
                XCTAssertEqual(behind.image.size, PlaceholderArt.heroCanvas, "\(build) \(wings)")
                XCTAssertNotNil(behind.image.cgImage)
            }
        }
    }
}
