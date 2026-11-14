import XCTest
import CoreGraphics
@testable import FateLost

/// Every family of melee weapon has a trail of its own.
final class SwingStyleTests: XCTestCase {
    func testEachMeleeWeaponSwingsInItsFamilysStyle() {
        let expected: [(WeaponDefinition, SwingStyle)] = [
            (StarterWeapons.sword, .blade),
            (StarterWeapons.claymore, .heavy), (StarterWeapons.warHammer, .heavy), (StarterWeapons.heavyAxe, .heavy),
            (StarterWeapons.katana, .quick),
            (StarterWeapons.dualDaggers, .twin),
            (StarterWeapons.handClaws, .claw), (StarterWeapons.sai, .claw),
            (StarterWeapons.spear, .thrust), (StarterWeapons.lance, .thrust),
            (StarterWeapons.scythe, .reap), (StarterWeapons.halberd, .reap),
            (StarterWeapons.whip, .lash), (StarterWeapons.flail, .lash), (StarterWeapons.nunchaku, .lash),
            (StarterWeapons.boStaff, .spin),
        ]
        for (weapon, style) in expected {
            XCTAssertEqual(SwingStyle.of(weapon.spriteID, arcDegrees: 120), style, weapon.name)
        }
        // Something new with no style of its own still reads sensibly from its arc.
        XCTAssertEqual(SwingStyle.of(.weaponBow, arcDegrees: 20), .thrust)
        XCTAssertEqual(SwingStyle.of(.weaponBow, arcDegrees: 120), .blade)
    }

    func testEveryStyleHasItsArt() {
        for id: SpriteID in [.fxSwingHeavy, .fxSwingThin, .fxSwingReap, .fxSwingClaw, .fxSwingLash, .fxSwingRing] {
            XCTAssertNotNil(PlaceholderArt.sprite(for: id), id.rawValue)
            XCTAssertTrue(SpriteCatalog.gameplaySprites.contains(id), "\(id.rawValue) is preloaded")
        }
    }

    func testASwingKeepsItsStyleOverTheWire() {
        for style in SwingStyle.allCases {
            let event = CombatEvent.meleeSwing(origin: CGPoint(x: 4, y: 9), direction: CGPoint(x: 1, y: 0),
                                               range: 2, arcDegrees: 120, style: style)
            let decoded = NetEventCodec.decode(NetEventCodec.encode([event], slotOf: { UInt8($0) })) ?? []
            guard case let .meleeSwing(_, _, _, _, back)? = decoded.first else {
                return XCTFail("\(style) did not survive the wire")
            }
            XCTAssertEqual(back, style)
        }
    }
}
