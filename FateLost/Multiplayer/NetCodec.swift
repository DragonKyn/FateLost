import CoreGraphics
import Foundation

/// A little-endian byte writer for gameplay frames.
///
/// Gameplay traffic is binary and small: positions are 1/16 of a tile, angles
/// a single byte, health a fraction. What a value can be is decided here, in
/// one place, and every writer has a reader that agrees (see `NetCodecTests`).
struct ByteWriter {
    private(set) var bytes: [UInt8] = []

    var data: Data { Data(bytes) }
    var count: Int { bytes.count }

    init(reserving capacity: Int = 256) {
        bytes.reserveCapacity(capacity)
    }

    mutating func u8(_ value: UInt8) { bytes.append(value) }

    mutating func u16(_ value: UInt16) {
        bytes.append(UInt8(value & 0xFF))
        bytes.append(UInt8(value >> 8))
    }

    mutating func u32(_ value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) {
            bytes.append(UInt8((value >> UInt32(shift)) & 0xFF))
        }
    }

    mutating func i8(_ value: Int8) { bytes.append(UInt8(bitPattern: value)) }

    mutating func i16(_ value: Int16) { u16(UInt16(bitPattern: value)) }

    mutating func f32(_ value: Float) { u32(value.bitPattern) }

    mutating func bool(_ value: Bool) { u8(value ? 1 : 0) }

    /// A world coordinate, to 1/16 of a tile.
    mutating func coord(_ value: CGFloat) {
        let scaled = (Double(value) * NetScale.coordinate).rounded()
        i16(Int16(clamping: Int(max(-32768, min(32767, scaled)))))
    }

    mutating func point(_ value: CGPoint) {
        coord(value.x)
        coord(value.y)
    }

    /// A direction as a single byte of angle. A zero vector is sent as
    /// pointing along +x.
    mutating func direction(_ value: CGPoint) {
        guard value.lengthSquared > 0.000001 else {
            u8(NetScale.angleByte(of: 0))
            return
        }
        u8(NetScale.angleByte(of: Double(atan2(value.y, value.x))))
    }

    /// A number from 0 to 1, in a byte.
    mutating func fraction(_ value: Double) {
        u8(UInt8(max(0, min(255, (value * 255).rounded()))))
    }

    /// Text up to 60 bytes; longer text is cut.
    mutating func string(_ value: String) {
        var text = Array(value.utf8.prefix(60))
        // Never cut inside a multi-byte character.
        while !text.isEmpty, String(bytes: text, encoding: .utf8) == nil { text.removeLast() }
        u8(UInt8(text.count))
        bytes.append(contentsOf: text)
    }

    mutating func raw(_ value: Data) { bytes.append(contentsOf: value) }
}

/// The reader for `ByteWriter`. It never traps on short or broken input: a
/// read past the end returns zero and marks the reader failed, and callers
/// discard whatever they were building.
struct ByteReader {
    private let bytes: [UInt8]
    private(set) var offset = 0
    private(set) var failed = false

    init(_ data: Data) {
        bytes = Array(data)
    }

    var remaining: Int { bytes.count - offset }
    var isAtEnd: Bool { offset >= bytes.count }

    private mutating func take(_ count: Int) -> ArraySlice<UInt8>? {
        guard !failed, count >= 0, offset + count <= bytes.count else {
            failed = true
            return nil
        }
        defer { offset += count }
        return bytes[offset..<(offset + count)]
    }

    mutating func u8() -> UInt8 { take(1)?.first ?? 0 }

    mutating func u16() -> UInt16 {
        guard let slice = take(2) else { return 0 }
        return UInt16(slice[slice.startIndex]) | UInt16(slice[slice.startIndex + 1]) << 8
    }

    mutating func u32() -> UInt32 {
        guard let slice = take(4) else { return 0 }
        var value: UInt32 = 0
        for (index, byte) in slice.enumerated() {
            value |= UInt32(byte) << UInt32(index * 8)
        }
        return value
    }

    mutating func i8() -> Int8 { Int8(bitPattern: u8()) }
    mutating func i16() -> Int16 { Int16(bitPattern: u16()) }
    mutating func f32() -> Float { Float(bitPattern: u32()) }
    mutating func bool() -> Bool { u8() != 0 }

    mutating func coord() -> CGFloat {
        CGFloat(Double(i16()) / NetScale.coordinate)
    }

    mutating func point() -> CGPoint {
        let x = coord()
        let y = coord()
        return CGPoint(x: x, y: y)
    }

    mutating func direction() -> CGPoint {
        NetScale.vector(fromAngleByte: u8())
    }

    mutating func fraction() -> Double {
        Double(u8()) / 255
    }

    mutating func string() -> String {
        let length = Int(u8())
        guard let slice = take(length) else { return "" }
        return String(bytes: slice, encoding: .utf8) ?? ""
    }
}

/// How numbers are squeezed for the wire.
enum NetScale {
    /// Sixteenths of a tile: about a centimetre of a screen, and a range of
    /// plus or minus 2,000 tiles, far larger than any arena.
    static let coordinate: Double = 16

    static func angleByte(of radians: Double) -> UInt8 {
        var normalised = radians + Double.pi
        normalised = normalised.truncatingRemainder(dividingBy: 2 * Double.pi)
        if normalised < 0 { normalised += 2 * Double.pi }
        return UInt8(max(0, min(255, (normalised / (2 * Double.pi) * 255).rounded())))
    }

    static func vector(fromAngleByte byte: UInt8) -> CGPoint {
        let radians = Double(byte) / 255 * 2 * Double.pi - Double.pi
        return CGPoint(x: CGFloat(cos(radians)), y: CGFloat(sin(radians)))
    }

    /// A byte from a velocity component, in eighths of a tile per second, so
    /// speeds up to about 15 tiles per second fit.
    static func velocityByte(_ value: CGFloat) -> Int8 {
        Int8(max(-127, min(127, (Double(value) * 8).rounded())))
    }

    static func velocity(fromByte byte: Int8) -> CGFloat {
        CGFloat(Double(byte) / 8)
    }
}

/// Everything that turns a game thing into a small number and back: sprites,
/// enemy kinds and visual styles.
///
/// Sprites and enemies travel as a 16-bit hash of their name, so the wire
/// format does not depend on the order they are declared in. Everything else
/// is a plain index into a fixed list. `contentVersion` is bumped whenever a
/// list changes in a way an older app would misread, and a snapshot from a
/// different version is refused rather than misdrawn.
enum NetTables {
    static let contentVersion: UInt8 = 4

    static func hash16(_ text: String) -> UInt16 {
        var hash: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return UInt16(truncatingIfNeeded: hash ^ (hash >> 16))
    }

    static let spriteByHash: [UInt16: SpriteID] = {
        var table: [UInt16: SpriteID] = [:]
        for sprite in GameplaySprites.all {
            table[hash16(sprite.rawValue)] = sprite
        }
        return table
    }()

    static let enemyByHash: [UInt16: EnemyDefinition] = {
        var table: [UInt16: EnemyDefinition] = [:]
        for definition in EnemyCatalog.all {
            table[hash16(definition.id)] = definition
        }
        return table
    }()

    static let visuals = VisualStyle.allCases
    static let damageTypes = DamageType.allCases
    static let shrines = ShrineKind.allCases

    static func sprite(_ hash: UInt16) -> SpriteID? { spriteByHash[hash] }
    static func hash(of sprite: SpriteID) -> UInt16 { hash16(sprite.rawValue) }

    static func visualIndex(_ visual: VisualStyle) -> UInt8 {
        UInt8(visuals.firstIndex(of: visual) ?? 0)
    }

    static func visual(_ index: UInt8) -> VisualStyle {
        visuals[min(Int(index), visuals.count - 1)]
    }

    static func shrineIndex(_ kind: ShrineKind) -> UInt8 {
        UInt8(shrines.firstIndex(of: kind) ?? 0)
    }

    static func shrine(_ index: UInt8) -> ShrineKind {
        shrines[min(Int(index), shrines.count - 1)]
    }

    static func dropCode(_ kind: DropKind) -> UInt8 {
        switch kind {
        case .vial: return 0
        case .magnet: return 1
        case .chest(let tier): return 2 + UInt8(tier.rawValue)
        }
    }

    static func drop(_ code: UInt8) -> DropKind {
        switch code {
        case 0: return .vial
        case 1: return .magnet
        default: return .chest(LootTier(rawValue: min(Int(code) - 2, LootTier.allCases.count - 1)) ?? .cache)
        }
    }
}
