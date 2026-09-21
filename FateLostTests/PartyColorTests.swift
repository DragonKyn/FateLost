import XCTest
@testable import FateLost

final class PartyColorTests: XCTestCase {
    func testEverySeatHasItsOwnColourAndTheyAreTheFourAsked() {
        XCTAssertEqual(PartyColor.hexes.count, PartyProtocol.maxPlayers)
        XCTAssertEqual(Set(PartyColor.hexes).count, PartyColor.hexes.count, "two seats share a colour")
        XCTAssertEqual(PartyColor.names, ["Red", "Blue", "Green", "Yellow"])
    }

    func testAColourBelongsToASeatOnEveryPhone() {
        // Seats are fixed for a run, so the colour is a plain function of the seat.
        XCTAssertEqual(PartyColor.hex(slot: 0), PartyColor.hex(slot: 0))
        XCTAssertNotEqual(PartyColor.hex(slot: 0), PartyColor.hex(slot: 1))
        XCTAssertEqual(PartyColor.name(slot: 2), "Green")
    }

    func testAnOutOfRangeSeatStillGetsAColourInsteadOfCrashing() {
        XCTAssertEqual(PartyColor.hex(slot: 4), PartyColor.hex(slot: 0))
        XCTAssertEqual(PartyColor.hex(slot: -1), PartyColor.hex(slot: 3))
    }

    func testTheColoursAreSoftNotSaturated() {
        for hex in PartyColor.hexes {
            let channels = [(hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF].map(Double.init)
            let spread = (channels.max() ?? 0) - (channels.min() ?? 0)
            XCTAssertGreaterThan(channels.max() ?? 0, 180, "bright enough to see over the ground")
            XCTAssertLessThan(spread, 175, "soft: not a pure primary")
        }
    }
}
