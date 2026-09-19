import Foundation

/// Deterministic, seedable random source (SplitMix64).
///
/// Arena layouts, loot rolls and anything else that must be reproducible from
/// a run seed draw from this rather than `SystemRandomNumberGenerator`, so a
/// seed always produces the same world and tests can assert exact results.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `0..<1`.
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / Double(1 << 53))
    }

    mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * unit()
    }

    mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }
}

/// Stateless hashing of integer coordinates into `0..<1`.
///
/// Used where a value must be a pure function of position (ground tile
/// variation, periodic noise lattices) so it is identical however many times,
/// and in whatever order, it is asked for.
enum CoordinateHash {
    static func unit(_ x: Int, _ y: Int, seed: UInt64) -> Double {
        var h = seed &+ UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15
        h ^= UInt64(bitPattern: Int64(y)) &* 0xC2B2_AE3D_27D4_EB4F
        h = (h ^ (h >> 33)) &* 0xFF51_AFD7_ED55_8CCD
        h = (h ^ (h >> 33)) &* 0xC4CE_B9FE_1A85_EC53
        h ^= h >> 33
        return Double(h >> 11) * (1.0 / Double(1 << 53))
    }
}

/// Value noise whose lattice repeats exactly every `period` cells, so noise
/// sampled across a wrapping arena has no seam at the boundary.
struct PeriodicValueNoise {
    let seed: UInt64
    let periodCellsX: Int
    let periodCellsY: Int
    /// Size of one lattice cell, in the same units as the sample coordinates.
    let cellWidth: Double
    let cellHeight: Double

    /// Noise that repeats exactly over a `width` × `height` area, with lattice
    /// cells as close to `approximateCellSize` as divides the area evenly.
    init(seed: UInt64, width: Double, height: Double, approximateCellSize: Double) {
        self.seed = seed
        periodCellsX = max(1, Int((width / approximateCellSize).rounded()))
        periodCellsY = max(1, Int((height / approximateCellSize).rounded()))
        cellWidth = width / Double(periodCellsX)
        cellHeight = height / Double(periodCellsY)
    }

    /// Returns a value in `0...1`.
    func sample(x: Double, y: Double) -> Double {
        let gx = x / cellWidth
        let gy = y / cellHeight
        let x0 = Int(floor(gx))
        let y0 = Int(floor(gy))
        let tx = smooth(gx - Double(x0))
        let ty = smooth(gy - Double(y0))

        let v00 = lattice(x0, y0)
        let v10 = lattice(x0 + 1, y0)
        let v01 = lattice(x0, y0 + 1)
        let v11 = lattice(x0 + 1, y0 + 1)

        let top = v00 + (v10 - v00) * tx
        let bottom = v01 + (v11 - v01) * tx
        return top + (bottom - top) * ty
    }

    private func lattice(_ x: Int, _ y: Int) -> Double {
        CoordinateHash.unit(positiveModulo(x, periodCellsX), positiveModulo(y, periodCellsY), seed: seed)
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}

func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
    let r = value % modulus
    return r < 0 ? r + modulus : r
}
