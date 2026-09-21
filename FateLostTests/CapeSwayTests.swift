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

    func testTheCloakTurnsAboutTheShouldersTowardWhereTheHemTrails() {
        var sway = CapeSway()
        run(&sway, seconds: 1, velocity: CGPoint(x: 120, y: 0))
        // Walking the way the hero faces: the hem trails behind, so the cloak turns clockwise (negative).
        let angle = sway.angle(cloth: 1)
        XCTAssertLessThan(angle, -0.08)
        XCTAssertGreaterThanOrEqual(angle, -CapeSway.maxAngle)
    }

    func testTheCloakNeverTurnsFurtherThanASmallAngle() {
        var sway = CapeSway()
        for index in 0..<600 {
            let sign: CGFloat = index % 7 < 3 ? 1 : -1
            sway.step(dt: frame, velocity: CGPoint(x: sign * 50_000, y: 0), time: Double(index) / 60)
            XCTAssertLessThanOrEqual(abs(sway.angle(cloth: 1)), CapeSway.maxAngle + 0.0001)
        }
        XCTAssertLessThan(CapeSway.maxAngle, 0.15, "about eight degrees at the very most: it cannot turn sideways")
    }

    func testRigidThingsDoNotTurn() {
        var sway = CapeSway()
        run(&sway, seconds: 1, velocity: CGPoint(x: 120, y: 0))
        XCTAssertEqual(sway.angle(cloth: 0), 0)
        XCTAssertLessThan(abs(sway.angle(cloth: 0.3)), abs(sway.angle(cloth: 1)) * 0.4)
    }

    func testAStillCloakHangsStraight() {
        var sway = CapeSway()
        run(&sway, seconds: 3, velocity: .zero)
        XCTAssertLessThan(abs(sway.angle(cloth: 1)), 0.03)
    }

    func testTurningAboutTheShouldersKeepsThemWhereTheyAre() {
        for angle in stride(from: -CapeSway.maxAngle, through: CapeSway.maxAngle, by: 0.02) {
            for height in [26, 32, 39].map(CGFloat.init) {
                let shift = CapeSway.anchorShift(angle: angle, pivotHeight: height)
                // The point `height` above the feet, turned by `angle` about the feet and moved by `shift`.
                let x = -height * sin(angle) + shift.x
                let y = height * cos(angle) + shift.y
                XCTAssertEqual(x, 0, accuracy: 0.0001)
                XCTAssertEqual(y, height, accuracy: 0.0001)
            }
        }
    }

    func testEveryBuildHasShouldersWhereTheArtPutsThem() {
        // The art tool's shoulder line: 76 (the feet) minus the build's hem rise and torso.
        let expected: [BodyBuild: CGFloat] = [.lithe: 76 - 10 - 25, .standard: 76 - 9 - 23, .broad: 76 - 9 - 22,
                                              .stout: 76 - 7 - 19, .towering: 76 - 12 - 27]
        for build in BodyBuild.allCases {
            let shoulderLine = 76 - build.shoulderHeight
            XCTAssertEqual(shoulderLine, expected[build] ?? -1, accuracy: 0.001, "\(build)")
        }
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
