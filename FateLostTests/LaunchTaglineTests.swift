import XCTest
@testable import FateLost

/// The launch screen's tagline is picked at random each time the app opens;
/// these hold that it is always one of the real lines, never empty or stuck.
final class LaunchTaglineTests: XCTestCase {
    func testEveryPromisedTaglineIsThere() {
        let promised = [
            "You begin as nobody.", "Legends often start at zero.", "Your prophecy is not written.",
            "Rise beyond your fate.", "Defy what's written.", "Your story begins where fate ends.",
            "A nobody can change everything.",
        ]
        for line in promised {
            XCTAssertTrue(LaunchTaglines.all.contains(line), "missing tagline: \(line)")
        }
    }

    func testRandomAlwaysReturnsARealTagline() {
        for _ in 0..<50 {
            XCTAssertTrue(LaunchTaglines.all.contains(LaunchTaglines.random()))
        }
    }

    func testNoTaglineIsBlank() {
        for line in LaunchTaglines.all {
            XCTAssertFalse(line.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
