import SwiftUI
import UIKit

/// The colour each seat in a party is known by. It is the same on every phone
/// (a seat never changes during a run), so "the blue one is hurt" means the
/// same thing to everyone, and it is the colour of that hero's arrow at the
/// edge of the screen and of their row in the corner list.
///
/// Soft rather than saturated: an arrow should be easy to find, not shout over
/// the fight.
enum PartyColor {
    static let hexes: [UInt32] = [0xE07A7C, 0x74A9E8, 0x82CC8E, 0xF0D06C]
    static let names = ["Red", "Blue", "Green", "Yellow"]

    private static func index(_ slot: Int) -> Int {
        let count = hexes.count
        return ((slot % count) + count) % count
    }

    static func hex(slot: Int) -> UInt32 { hexes[index(slot)] }
    static func name(slot: Int) -> String { names[index(slot)] }
    static func uiColor(slot: Int) -> UIColor { UIColor(rgb: hex(slot: slot)) }
    static func color(slot: Int) -> Color { Color(uiColor: uiColor(slot: slot)) }
}
