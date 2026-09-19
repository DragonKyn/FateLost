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
    var speedScale: [CGFloat] = []
    /// Last movement direction, for facing.
    var heading: [CGPoint] = []
    /// Seconds until another strike may start.
    var attackCooldown: [Double] = []
    /// Seconds until a strike in progress lands; zero when not striking.
    var windup: [Double] = []
    /// Cached push away from neighbours, refreshed on a staggered schedule.
    var separation: [CGPoint] = []

    var count: Int { ids.count }
    var isEmpty: Bool { ids.isEmpty }

    init(capacity: Int = 0) {
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

    func definition(at index: Int) -> EnemyDefinition {
        definitions[kinds[index]]
    }

    mutating func append(id: Int, kind: Int, position: CGPoint, speedScale scale: CGFloat) {
        let definition = definitions[kind]
        ids.append(id)
        kinds.append(kind)
        positions.append(position)
        knockback.append(.zero)
        health.append(definition.maxHealth)
        speedScale.append(scale)
        heading.append(CGPoint(x: 1, y: 0))
        // A fresh enemy can't strike the instant it arrives.
        attackCooldown.append(definition.attackCooldown * 0.5)
        windup.append(0)
        separation.append(.zero)
    }

    /// Removes the enemy at `index` by moving the last enemy into its slot.
    /// Indices held from before the call are no longer valid.
    mutating func remove(at index: Int) {
        ids.swapRemove(at: index)
        kinds.swapRemove(at: index)
        positions.swapRemove(at: index)
        knockback.swapRemove(at: index)
        health.swapRemove(at: index)
        speedScale.swapRemove(at: index)
        heading.swapRemove(at: index)
        attackCooldown.swapRemove(at: index)
        windup.swapRemove(at: index)
        separation.swapRemove(at: index)
    }

    mutating func removeAll() {
        ids.removeAll(keepingCapacity: true)
        kinds.removeAll(keepingCapacity: true)
        positions.removeAll(keepingCapacity: true)
        knockback.removeAll(keepingCapacity: true)
        health.removeAll(keepingCapacity: true)
        speedScale.removeAll(keepingCapacity: true)
        heading.removeAll(keepingCapacity: true)
        attackCooldown.removeAll(keepingCapacity: true)
        windup.removeAll(keepingCapacity: true)
        separation.removeAll(keepingCapacity: true)
    }

    private mutating func reserveCapacity(_ capacity: Int) {
        guard capacity > 0 else { return }
        ids.reserveCapacity(capacity)
        kinds.reserveCapacity(capacity)
        positions.reserveCapacity(capacity)
        knockback.reserveCapacity(capacity)
        health.reserveCapacity(capacity)
        speedScale.reserveCapacity(capacity)
        heading.reserveCapacity(capacity)
        attackCooldown.reserveCapacity(capacity)
        windup.reserveCapacity(capacity)
        separation.reserveCapacity(capacity)
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
