import CoreGraphics

/// Every living enemy, stored as parallel arrays (struct of arrays).
///
/// Systems loop over one or two fields at a time across hundreds of enemies,
/// and contiguous arrays of plain values keep those loops cache-friendly and
/// allocation-free. An enemy is an index into these arrays for the duration
/// of a tick; `ids` holds a stable identity for renderers, since removal
/// swaps the last enemy into the freed slot.
struct EnemyStore {
    /// Definitions referenced by `kinds`, so each enemy stores a small index
    /// instead of a copy of its definition.
    private(set) var definitions: [EnemyDefinition] = []
    /// Largest body radius among registered kinds, for padding queries.
    private(set) var largestRadius: CGFloat = 0

    private(set) var ids: [Int] = []
    private(set) var kinds: [Int] = []
    var positions: [CGPoint] = []
    var knockback: [CGPoint] = []
    var health: [Double] = []
    var maxHealth: [Double] = []
    var speedScale: [CGFloat] = []
    /// Per-enemy damage multiplier from its strain.
    var damageScale: [Double] = []
    /// Per-enemy draw size, from its strain and its kind's `drawScale`.
    var sizeScale: [CGFloat] = []
    /// Index into `EnemyStrain.all`: this creature's roll of the dice.
    var strains: [Int] = []
    /// Last movement direction, for facing.
    var heading: [CGPoint] = []
    /// Seconds until another strike may start.
    var attackCooldown: [Double] = []
    /// Seconds until a strike in progress lands; zero when not striking.
    var windup: [Double] = []
    /// Cached push away from neighbours, refreshed on a staggered schedule.
    var separation: [CGPoint] = []
    /// Velocity of a charge in progress; zero when not charging.
    var dash: [CGPoint] = []
    /// Seconds of charge left, or seconds until a summoner calls again.
    var special: [Double] = []

    /// Bit per active `StatusKind`, for quick checks.
    var statusMask: [UInt16] = []
    /// Seconds left per status kind, indexed `[kind][enemy]`.
    var statusTime: [[Float]] = []
    /// Strength per status kind, indexed `[kind][enemy]`.
    var statusPotency: [[Float]] = []
    /// Damage type of the latest hit, for "killed by" triggers.
    var lastHitType: [UInt8] = []
    /// Proc depth of the latest hit, so death triggers can't chain forever.
    var lastHitDepth: [UInt8] = []

    var count: Int { ids.count }
    var isEmpty: Bool { ids.isEmpty }

    init(capacity: Int = 0) {
        statusTime = Array(repeating: [], count: StatusKind.allCases.count)
        statusPotency = Array(repeating: [], count: StatusKind.allCases.count)
        reserveCapacity(capacity)
    }

    /// Index into `definitions` for a definition, registering it if new.
    mutating func kindIndex(for definition: EnemyDefinition) -> Int {
        if let index = definitions.firstIndex(where: { $0.id == definition.id }) {
            return index
        }
        definitions.append(definition)
        largestRadius = max(largestRadius, definition.radius)
        return definitions.count - 1
    }

    /// Index of an already-registered kind, without registering a new one.
    func registeredKind(for id: EnemyKindID) -> Int? {
        definitions.firstIndex { $0.id == id }
    }

    func definition(at index: Int) -> EnemyDefinition {
        definitions[kinds[index]]
    }

    func strain(at index: Int) -> EnemyStrain {
        EnemyStrain.strain(at: strains[index])
    }

    /// The creature's full name, strain and all.
    func title(at index: Int) -> String {
        strain(at: index).title(for: definition(at: index).name)
    }

    func hasStatus(_ kind: StatusKind, at index: Int) -> Bool {
        statusMask[index] & kind.bit != 0
    }

    func potency(_ kind: StatusKind, at index: Int) -> Double {
        statusMask[index] & kind.bit != 0 ? Double(statusPotency[kind.rawValue][index]) : 0
    }

    mutating func append(id: Int, kind: Int, position: CGPoint, speedScale scale: CGFloat,
                         healthScale: Double = 1, strain strainIndex: Int = 0) {
        let definition = definitions[kind]
        let strain = EnemyStrain.strain(at: strainIndex)
        ids.append(id)
        kinds.append(kind)
        positions.append(position)
        knockback.append(.zero)
        let life = definition.maxHealth * healthScale * strain.healthScale
        health.append(life)
        maxHealth.append(life)
        speedScale.append(scale * strain.speedScale)
        damageScale.append(strain.damageScale)
        sizeScale.append(definition.drawScale * strain.sizeScale)
        strains.append(strainIndex)
        heading.append(CGPoint(x: 1, y: 0))
        // A fresh enemy can't strike the instant it arrives.
        attackCooldown.append(definition.attackCooldown * 0.5)
        windup.append(0)
        separation.append(.zero)
        dash.append(.zero)
        special.append(0)
        statusMask.append(0)
        for kind in 0..<statusTime.count {
            statusTime[kind].append(0)
            statusPotency[kind].append(0)
        }
        lastHitType.append(0)
        lastHitDepth.append(0)
    }

    /// Removes the enemy at `index` by moving the last enemy into its slot.
    /// Indices held from before the call are no longer valid.
    mutating func remove(at index: Int) {
        ids.swapRemove(at: index)
        kinds.swapRemove(at: index)
        positions.swapRemove(at: index)
        knockback.swapRemove(at: index)
        health.swapRemove(at: index)
        maxHealth.swapRemove(at: index)
        speedScale.swapRemove(at: index)
        damageScale.swapRemove(at: index)
        sizeScale.swapRemove(at: index)
        strains.swapRemove(at: index)
        heading.swapRemove(at: index)
        attackCooldown.swapRemove(at: index)
        windup.swapRemove(at: index)
        separation.swapRemove(at: index)
        dash.swapRemove(at: index)
        special.swapRemove(at: index)
        statusMask.swapRemove(at: index)
        for kind in 0..<statusTime.count {
            statusTime[kind].swapRemove(at: index)
            statusPotency[kind].swapRemove(at: index)
        }
        lastHitType.swapRemove(at: index)
        lastHitDepth.swapRemove(at: index)
    }

    mutating func removeAll() {
        ids.removeAll(keepingCapacity: true)
        kinds.removeAll(keepingCapacity: true)
        positions.removeAll(keepingCapacity: true)
        knockback.removeAll(keepingCapacity: true)
        health.removeAll(keepingCapacity: true)
        maxHealth.removeAll(keepingCapacity: true)
        speedScale.removeAll(keepingCapacity: true)
        damageScale.removeAll(keepingCapacity: true)
        sizeScale.removeAll(keepingCapacity: true)
        strains.removeAll(keepingCapacity: true)
        heading.removeAll(keepingCapacity: true)
        attackCooldown.removeAll(keepingCapacity: true)
        windup.removeAll(keepingCapacity: true)
        separation.removeAll(keepingCapacity: true)
        dash.removeAll(keepingCapacity: true)
        special.removeAll(keepingCapacity: true)
        statusMask.removeAll(keepingCapacity: true)
        for kind in 0..<statusTime.count {
            statusTime[kind].removeAll(keepingCapacity: true)
            statusPotency[kind].removeAll(keepingCapacity: true)
        }
        lastHitType.removeAll(keepingCapacity: true)
        lastHitDepth.removeAll(keepingCapacity: true)
    }

    private mutating func reserveCapacity(_ capacity: Int) {
        guard capacity > 0 else { return }
        ids.reserveCapacity(capacity)
        kinds.reserveCapacity(capacity)
        positions.reserveCapacity(capacity)
        knockback.reserveCapacity(capacity)
        health.reserveCapacity(capacity)
        maxHealth.reserveCapacity(capacity)
        speedScale.reserveCapacity(capacity)
        damageScale.reserveCapacity(capacity)
        sizeScale.reserveCapacity(capacity)
        strains.reserveCapacity(capacity)
        heading.reserveCapacity(capacity)
        attackCooldown.reserveCapacity(capacity)
        windup.reserveCapacity(capacity)
        separation.reserveCapacity(capacity)
        dash.reserveCapacity(capacity)
        special.reserveCapacity(capacity)
        statusMask.reserveCapacity(capacity)
        for kind in 0..<statusTime.count {
            statusTime[kind].reserveCapacity(capacity)
            statusPotency[kind].reserveCapacity(capacity)
        }
        lastHitType.reserveCapacity(capacity)
        lastHitDepth.reserveCapacity(capacity)
    }
}

extension Array {
    /// O(1) removal that does not preserve order: the last element takes the
    /// removed element's place.
    mutating func swapRemove(at index: Int) {
        let last = count - 1
        if index != last {
            swapAt(index, last)
        }
        removeLast()
    }
}
