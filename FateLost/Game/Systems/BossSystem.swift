import CoreGraphics
import Foundation

/// What a champion can do besides its ordinary attack.
///
/// Every move is something the player can see coming and step out of: ground
/// that is marked before it hurts (`Hazard`), or shots slow enough to weave
/// through, fired in patterns with gaps. Nothing here lands without a warning.
enum BossMove: UInt8, CaseIterable {
    /// A disc around the boss, and at higher intensity a ring of shards after it.
    case slam
    /// A wedge toward the nearest hero (and, later, a second behind the boss).
    case cleave
    /// A fan of shots aimed at the nearest hero.
    case fan
    /// Rings of shots, each offset from the last so the gap moves.
    case ring
    /// A rotating stream of shots.
    case spiral
    /// Marked discs on every hero and around them, landing together.
    case meteors
    /// Parallel strips of ground across the hero's position, with gaps between.
    case lanes
    /// Discs that land and then keep burning: ground to stay out of.
    case pools
    /// Vanishes and lands somewhere else with a slam: the landing is marked first.
    case blink
    /// Calls its own kind in around it.
    case summon
    /// A beam that sweeps across a marked wedge.
    case sweep
    /// A mark on every hero that follows them, then locks and lands.
    case hunt
    /// Darkness spreads over the whole arena but for one small marked
    /// circle: standing outside it costs health every second once the
    /// warning passes. See `BossSystem.advanceDarkness`.
    case eclipse

    var name: String {
        switch self {
        case .slam: return "Slam"
        case .cleave: return "Cleave"
        case .fan: return "Volley"
        case .ring: return "Ring"
        case .spiral: return "Spiral"
        case .meteors: return "Meteors"
        case .lanes: return "Lanes"
        case .pools: return "Pools"
        case .blink: return "Blink"
        case .summon: return "Summon"
        case .sweep: return "Sweep"
        case .hunt: return "Hunt"
        case .eclipse: return "Eclipse"
        }
    }
}

/// A champion's repertoire.
///
/// The realm's champions are met in order, so each kit is a step up from the
/// last: more moves to learn, more of them at once, and shorter warnings (never
/// shorter than `BossSystem.minimumWarning`). `intensity` (1...10) is how hard
/// the numbers push; the moves listed are opened up as the fight goes on.
struct BossKit: Equatable {
    var moves: [BossMove]
    /// 1...10: how many shots, how big the ground, how short the warning.
    var intensity: Int
    /// Seconds between moves at full health.
    var tempo: Double
    /// What it calls when it summons, and at each phase shift.
    var adds: EnemyKindID?
    /// The move it favours (twice as likely to be chosen); the last in `moves` if not set.
    var signature: BossMove?
    /// A shield over its health, as a share of it, that must be broken
    /// before health itself starts moving (see `EnemyStore.barrier`). Zero
    /// for every ordinary champion; only Fate starts a fight this way.
    var barrierFraction: Double = 0
    /// Multiplies the reach of `.cleave`, `.lanes` and `.sweep`, for a boss
    /// whose attacks should threaten more of the arena than intensity alone
    /// would give it.
    var reachScale: Double = 1
    /// What `.summon` calls from, weighted, instead of always `adds`: a mix
    /// of elites and (rarely) a returning boss. Empty means `.summon` falls
    /// back to `adds` as normal.
    var summonPool: [(kind: EnemyKindID, weight: Double)] = []
    /// The most of `summonPool`'s kinds allowed alive at once, so summons
    /// never crowd the fight past reading.
    var maxSimultaneousSummons: Int = 2
    /// `.meteors` falls as the Powder Fiend's firebombs instead: one after
    /// another rather than all at once, so there is always a way through,
    /// and each leaving the Powder Fiend's own burn on whoever it catches.
    var firebombs = false

    init(moves: [BossMove], intensity: Int, tempo: Double, adds: EnemyKindID? = nil, signature: BossMove? = nil,
        barrierFraction: Double = 0, reachScale: Double = 1, summonPool: [(kind: EnemyKindID, weight: Double)] = [],
        maxSimultaneousSummons: Int = 2, firebombs: Bool = false) {
        self.moves = moves
        self.intensity = intensity
        self.tempo = tempo
        self.adds = adds
        self.signature = signature
        self.barrierFraction = barrierFraction
        self.reachScale = reachScale
        self.summonPool = summonPool
        self.maxSimultaneousSummons = maxSimultaneousSummons
        self.firebombs = firebombs
    }

    /// Tuple arrays aren't `Equatable` for free; compared by kind and weight.
    static func == (lhs: BossKit, rhs: BossKit) -> Bool {
        lhs.moves == rhs.moves && lhs.intensity == rhs.intensity && lhs.tempo == rhs.tempo && lhs.adds == rhs.adds
            && lhs.signature == rhs.signature && lhs.barrierFraction == rhs.barrierFraction
            && lhs.reachScale == rhs.reachScale && lhs.maxSimultaneousSummons == rhs.maxSimultaneousSummons
            && lhs.firebombs == rhs.firebombs
            && lhs.summonPool.count == rhs.summonPool.count
            && zip(lhs.summonPool, rhs.summonPool).allSatisfy { $0.kind == $1.kind && $0.weight == $1.weight }
    }
}

/// What one champion is doing right now. Kept by enemy id in `CombatState`.
struct BossBrain {
    /// A shot pattern still to fire, `delay` seconds from now.
    struct Beat {
        enum Action {
            case ring(count: Int, offset: Double)
            case fan(count: Int, spread: Double)
            case stream(angle: Double, arms: Int)
        }
        var delay: Double
        var action: Action
        var damage: Double
        var speed: CGFloat
        /// How far from the champion's centre the shots appear. Always past
        /// melee range, so a hero standing at its feet is inside the pattern
        /// rather than caught by it.
        var spawn: CGFloat
    }

    /// Seconds until the next move may begin.
    var cooldown: Double
    /// Seconds the champion stands still for: the move, then a breath after
    /// it in which it can be hit and does nothing.
    var lock: Double = 0
    var last: BossMove?
    var beats: [Beat] = []
    /// How far into the fight it is: 0, 1 or 2 (see `BossSystem.phase`).
    var phase = 0
    /// Whether this champion has been seen carrying a barrier: set the
    /// instant `EnemyStore.barrier` first reads positive, so its later
    /// falling to zero can be told apart from simply never having had one.
    var hadBarrier = false
    /// Set the moment a barrier breaks, and carried until the champion is
    /// next free to answer it with its own `shift` burst — a dramatic beat
    /// of its own, independent of and never consuming a later health-based
    /// phase change.
    var pendingBarrierBreak = false

    var isBusy: Bool { lock > 0 }
}

/// Decides and carries out a champion's moves, and lands its marked ground.
enum BossSystem {
    /// No marked ground lands sooner than this after it appears, at any intensity.
    static let minimumWarning: Double = 0.7
    /// No shot a champion fires is faster than this, in tiles a second.
    static let fastestShot: CGFloat = 8
    /// A champion only starts a move with a hero this close.
    static let engagementRange: CGFloat = 15
    /// How long a champion stands, hittable, after finishing a move.
    static let recovery: Double = 0.8
    /// The most enemies a champion's calls may leave standing.
    static let crowdLimit = 700

    /// How far into the fight a champion is at a health fraction: two thirds
    /// gone is the second phase change, a third the first.
    static func phase(healthFraction: Double) -> Int {
        healthFraction > 2.0 / 3 ? 0 : (healthFraction > 1.0 / 3 ? 1 : 2)
    }

    /// Which of a kit's moves are open in a phase: the first two at the start,
    /// then more in each phase until all are.
    static func availableMoves(_ kit: BossKit, phase: Int) -> [BossMove] {
        let count = kit.moves.count
        guard count > 2 else { return kit.moves }
        let step = Int((Double(count - 2) / 2).rounded(.up))
        return Array(kit.moves.prefix(min(count, 2 + phase * step)))
    }

    static func warning(_ base: Double, kit: BossKit) -> Double {
        max(minimumWarning, base - 0.05 * Double(kit.intensity))
    }

    // MARK: Each step

    static func step(_ combat: inout CombatState, targets: [AITarget], dt: TimeInterval) {
        advanceHazards(&combat, targets: targets, dt: dt)
        advanceDarkness(&combat, targets: targets, dt: dt)
        guard combat.enemies.count > 0 else {
            combat.bossBrains.removeAll()
            return
        }
        var live: [Int] = []
        let count = combat.enemies.count
        for index in 0..<count {
            let definition = combat.enemies.definition(at: index)
            guard let kit = definition.kit, !kit.moves.isEmpty else { continue }
            let id = combat.enemies.ids[index]
            live.append(id)
            var brain = combat.bossBrains[id] ?? BossBrain(cooldown: kit.tempo * 0.6)
            run(&brain, at: index, definition: definition, kit: kit, combat: &combat, targets: targets, dt: dt)
            combat.bossBrains[id] = brain
        }
        if combat.bossBrains.count > live.count {
            let alive = Set(live)
            combat.bossBrains = combat.bossBrains.filter { alive.contains($0.key) }
        }
    }

    private static func run(_ brain: inout BossBrain, at index: Int, definition: EnemyDefinition, kit: BossKit,
                            combat: inout CombatState, targets: [AITarget], dt: TimeInterval) {
        // A stunned champion loses its pattern; the ground already marked stays.
        // A barrier (Fate's, at the start of its fight) absorbs every blow
        // before health moves at all; the instant it gives out is its own
        // dramatic beat, and a clear step up in how the fight behaves from
        // here — whether or not health has actually started falling yet.
        if combat.enemies.barrier[index] > 0 {
            brain.hadBarrier = true
        } else if brain.hadBarrier {
            brain.hadBarrier = false
            brain.pendingBarrierBreak = true
            combat.events.append(.shieldBroke(enemyID: combat.enemies.ids[index],
                                              position: combat.enemies.positions[index]))
        }

        if combat.enemies.statusMask[index] & StatusKind.incapacitating != 0 {
            brain.beats.removeAll()
            brain.lock = 0
            return
        }

        brain.lock = max(0, brain.lock - dt)
        brain.cooldown -= dt

        if !brain.beats.isEmpty {
            for slot in brain.beats.indices { brain.beats[slot].delay -= dt }
            let due = brain.beats.filter { $0.delay <= 0 }
            if !due.isEmpty {
                brain.beats.removeAll { $0.delay <= 0 }
                for beat in due { fire(beat, from: index, definition: definition, combat: &combat, targets: targets) }
            }
        }

        let fraction = combat.enemies.maxHealth[index] > 0
            ? combat.enemies.health[index] / combat.enemies.maxHealth[index] : 1
        let currentPhase = phase(healthFraction: fraction)
        let ready = brain.lock <= 0 && brain.beats.isEmpty && combat.enemies.windup[index] <= 0
            && combat.enemies.dash[index] == .zero
        let origin = combat.enemies.positions[index]
        guard ready, let nearest = nearestHero(to: origin, in: targets, world: combat.world),
              combat.world.distance(origin, nearest.position) <= engagementRange else { return }

        let base = definition.attackDamage * combat.enemyDamageScale * combat.enemies.damageScale[index]

        // A broken barrier gets its own burst the moment the champion is
        // next free to answer it, ahead of and separate from any
        // health-based phase change.
        if brain.pendingBarrierBreak {
            brain.pendingBarrierBreak = false
            shift(&brain, at: index, definition: definition, kit: kit, base: base, target: nearest, combat: &combat)
            return
        }

        // Crossing into a new phase is an event: it stops, roars and lays a big
        // marked slam, with reinforcements, before anything else.
        if currentPhase > brain.phase {
            brain.phase = currentPhase
            shift(&brain, at: index, definition: definition, kit: kit, base: base, target: nearest, combat: &combat)
            return
        }

        guard brain.cooldown <= 0 else { return }

        var everything = availableMoves(kit, phase: currentPhase)
        if kit.adds == nil, kit.summonPool.isEmpty { everything.removeAll { $0 == .summon } }
        // The darkness lives on the host alone and is not sent to other
        // phones, so a party's guests would be hurt by a dark they cannot
        // see. Fate keeps it for a lone hero.
        if combat.isParty { everything.removeAll { $0 == .eclipse } }
        // While the dark is up the safe circle is the only safe ground, so
        // nothing may be thrown at it that would leave no answer at all: no
        // second eclipse, no sweeping or wide ground, no hunt chasing a hero
        // out of it. Firebombs (which keep clear of the circle) and a summon only.
        if combat.darkness != nil {
            everything = everything.filter { $0 == .meteors || $0 == .summon }
        }
        guard !everything.isEmpty else { return }
        var pool = everything.filter { $0 != brain.last }
        if pool.isEmpty { pool = everything }
        // The move it is known for comes up twice as often.
        if let signature = kit.signature ?? kit.moves.last, pool.contains(signature) { pool.append(signature) }
        let move = pool[Int(combat.random.unit() * Double(pool.count)) % pool.count]
        brain.last = move

        let committed = perform(move, kit: kit, base: base, boss: index, definition: definition, target: nearest,
                                brain: &brain, combat: &combat, targets: targets)
        brain.lock = committed + recovery
        // Later in the fight the pauses shorten, and sometimes there is none at all.
        let tempo = kit.tempo * (1 - 0.16 * Double(currentPhase)) * combat.random.range(0.9, 1.1)
        let combo = currentPhase >= 2 && combat.random.chance(0.35)
        brain.cooldown = brain.lock + (combo ? 0.4 : max(0.6, tempo - committed))
    }

    /// A phase change: a large marked slam and a ring, and its own kind called in.
    private static func shift(_ brain: inout BossBrain, at index: Int, definition: EnemyDefinition, kit: BossKit,
                              base: Double, target: AITarget, combat: inout CombatState) {
        let origin = combat.enemies.positions[index]
        let toTarget = combat.world.delta(from: origin, to: target.position)
        let aim = toTarget.lengthSquared > 0.0001 ? toTarget.normalized : combat.enemies.heading[index]
        let type = definition.damageType
        let wait = 1.9
        let radius = CGFloat(3.4 + 0.15 * Double(kit.intensity))
        addHazard(&combat, .circle, at: origin, direction: aim, size: radius, width: 0, warning: wait,
                  damage: base * 1.5, type: type, visual: VisualStyle.matching(type))
        brain.beats.append(BossBrain.Beat(delay: wait, action: .ring(count: 12, offset: combat.random.range(0, Double.pi)),
                                          damage: base * 0.55, speed: 5, spawn: radius + 0.8))
        if !kit.summonPool.isEmpty {
            callFromPool(kit.summonPool, limit: kit.maxSimultaneousSummons, around: origin, combat: &combat)
        } else if let adds = kit.adds {
            call(adds, count: min(6, 2 + kit.intensity / 3), around: origin, combat: &combat)
        }
        brain.lock = wait + recovery + 0.4
        brain.cooldown = brain.lock + 1.2
    }

    // MARK: Moves

    /// Starts a move. Returns how long the champion is committed to it.
    private static func perform(_ move: BossMove, kit: BossKit, base: Double, boss index: Int,
                                definition: EnemyDefinition, target: AITarget, brain: inout BossBrain,
                                combat: inout CombatState, targets: [AITarget]) -> Double {
        let origin = combat.enemies.positions[index]
        let intensity = kit.intensity
        let level = Double(intensity)
        let toTarget = combat.world.delta(from: origin, to: target.position)
        let aim = toTarget.lengthSquared > 0.0001 ? toTarget.normalized : combat.enemies.heading[index]
        let type = definition.damageType
        let visual = VisualStyle.matching(type)
        let heroes = targets.filter { $0.isAlive }

        switch move {
        case .slam:
            let wait = warning(1.5, kit: kit)
            let radius = CGFloat(2.7 + 0.1 * level)
            addHazard(&combat, .circle, at: origin, direction: aim, size: radius, width: 0,
                      warning: wait, damage: base * 1.3, type: type, visual: visual)
            if intensity >= 4 {
                // Shards fly out from the edge of the slam as it lands.
                let offset = combat.random.range(0, Double.pi)
                brain.beats.append(BossBrain.Beat(delay: wait, action: .ring(count: 8, offset: offset),
                                                  damage: base * 0.5, speed: 5, spawn: radius + 0.8))
            }
            return wait

        case .cleave:
            let wait = warning(1.5, kit: kit)
            let reach = CGFloat((3.8 + 0.08 * level) * kit.reachScale)
            addHazard(&combat, .cone, at: origin, direction: aim, size: reach, width: 0.85, warning: wait,
                      damage: base * 1.2, type: type, visual: visual)
            var committed = wait
            if intensity >= 6 {
                // The second swing is marked from the start, so the whole pattern can be read.
                let after = wait + 0.6
                addHazard(&combat, .cone, at: origin, direction: aim * -1, size: reach, width: 0.85, warning: after,
                          damage: base * 1.2, type: type, visual: visual)
                committed = after
            }
            return committed

        case .fan:
            let volleys = intensity >= 5 ? 2 : 1
            let count = (5 + intensity / 3) | 1
            for volley in 0..<volleys {
                brain.beats.append(BossBrain.Beat(delay: 0.75 + 0.6 * Double(volley),
                                                  action: .fan(count: count, spread: 0.95),
                                                  damage: base * 0.6, speed: 7, spawn: 2))
            }
            return 0.75 + 0.6 * Double(volleys - 1)

        case .ring:
            let rings = intensity >= 7 ? 3 : 2
            let count = 9 + intensity / 4
            let start = combat.random.range(0, Double.pi)
            let half = Double.pi / Double(count)
            for ring in 0..<rings {
                brain.beats.append(BossBrain.Beat(delay: 0.8 + 0.55 * Double(ring),
                                                  action: .ring(count: count, offset: start + (ring % 2 == 1 ? half : 0)),
                                                  damage: base * 0.55, speed: 5, spawn: 3))
            }
            return 0.8 + 0.55 * Double(rings - 1)

        case .spiral:
            let arms = intensity >= 8 ? 3 : 2
            let seconds = 2.4 + 0.15 * level
            let shots = Int(seconds / 0.18)
            let start = combat.random.range(0, 2 * Double.pi)
            let direction = combat.random.chance(0.5) ? 1.0 : -1.0
            for shot in 0..<shots {
                brain.beats.append(BossBrain.Beat(delay: 0.7 + 0.18 * Double(shot),
                                                  action: .stream(angle: start + direction * 0.5 * Double(shot), arms: arms),
                                                  damage: base * 0.45, speed: 5.2, spawn: 2.4))
            }
            return 0.7 + seconds

        case .meteors where kit.firebombs:
            return firebombRain(kit: kit, base: base, aim: aim, heroes: heroes, combat: &combat)

        case .meteors:
            let wait = warning(1.5, kit: kit)
            let count = min(10, max(3, 2 + intensity / 2 + heroes.count))
            var placed = 0
            // From intensity 6 each leaves a smouldering patch behind.
            let smoulders = intensity >= 6
            func meteor(_ combat: inout CombatState, at point: CGPoint) {
                var mark = Hazard(id: combat.makeEntityID(), shape: .circle, position: combat.world.wrap(point),
                                  direction: aim, size: 1.45, width: 0, warning: max(minimumWarning, wait),
                                  damage: base * 1.1, type: type, visual: visual)
                if smoulders {
                    mark.linger = 3
                    mark.tickDamage = base * 0.25
                }
                combat.hazards.append(mark)
            }
            for hero in heroes where placed < count {
                meteor(&combat, at: hero.position)
                placed += 1
            }
            while placed < count, !heroes.isEmpty {
                let pick = Int(combat.random.unit() * Double(heroes.count)) % heroes.count
                meteor(&combat, at: combat.randomPoint(around: heroes[pick].position, within: 5.5))
                placed += 1
            }
            return 0.6

        case .lanes:
            let wait = warning(1.4, kit: kit)
            let count = intensity >= 8 ? 4 : (intensity >= 4 ? 3 : 2)
            let angle = combat.random.range(0, Double.pi)
            let along = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
            let across = CGPoint(x: -along.y, y: along.x)
            let spacing: CGFloat = 3.2
            let length = CGFloat(16 * kit.reachScale)
            for lane in 0..<count {
                let shift = (CGFloat(lane) - CGFloat(count - 1) / 2) * spacing
                let start = target.position + across * shift - along * (length / 2)
                addHazard(&combat, .lane, at: start, direction: along, size: length, width: 0.75, warning: wait,
                          damage: base * 1.15, type: type, visual: visual)
            }
            return 0.9

        case .pools:
            let wait = warning(1.6, kit: kit)
            let count = min(9, 3 + intensity / 3 + heroes.count)
            var placed = 0
            func pool(_ combat: inout CombatState, at point: CGPoint) {
                var mark = Hazard(id: combat.makeEntityID(), shape: .circle, position: combat.world.wrap(point),
                                  direction: aim, size: 1.6, width: 0, warning: max(minimumWarning, wait),
                                  damage: base * 0.8, type: type, visual: visual)
                mark.linger = 5 + 0.3 * level
                mark.tickDamage = base * 0.3
                combat.hazards.append(mark)
            }
            for hero in heroes where placed < count {
                pool(&combat, at: hero.position)
                placed += 1
            }
            while placed < count, !heroes.isEmpty {
                let pick = Int(combat.random.unit() * Double(heroes.count)) % heroes.count
                pool(&combat, at: combat.randomPoint(around: heroes[pick].position, within: 6))
                placed += 1
            }
            return 0.8

        case .blink:
            let wait = warning(1.4, kit: kit)
            guard !heroes.isEmpty else { return 0.4 }
            let victim = heroes[Int(combat.random.unit() * Double(heroes.count)) % heroes.count]
            let bearing = combat.random.range(0, 2 * Double.pi)
            let landing = combat.world.wrap(victim.position + CGPoint(x: CGFloat(cos(bearing)), y: CGFloat(sin(bearing))) * 3.4)
            var mark = Hazard(id: combat.makeEntityID(), shape: .circle, position: landing, direction: aim,
                              size: CGFloat(2.6 + 0.1 * level), width: 0, warning: max(minimumWarning, wait),
                              damage: base * 1.3, type: type, visual: visual)
            mark.carriesBoss = combat.enemies.ids[index]
            combat.hazards.append(mark)
            return wait + 0.2

        case .summon:
            if !kit.summonPool.isEmpty {
                callFromPool(kit.summonPool, limit: kit.maxSimultaneousSummons, around: origin, combat: &combat)
                return 1.2
            }
            guard let adds = kit.adds else { return 0.5 }
            call(adds, count: min(8, 3 + intensity / 2), around: origin, combat: &combat)
            return 1.0

        case .sweep:
            let wait = warning(1.4, kit: kit)
            let arc: CGFloat = 1.9
            let active = 2.2 + 0.05 * level
            let reach = CGFloat((9 + 0.2 * level) * kit.reachScale)
            let clockwise = combat.random.chance(0.5)
            let middle = atan2(aim.y, aim.x)
            let start = middle + (clockwise ? arc / 2 : -arc / 2)
            let startDirection = CGPoint(x: cos(start), y: sin(start))
            // The whole swept wedge is marked from the start; the beam only travels across it.
            var guide = Hazard(id: combat.makeEntityID(), shape: .cone, position: origin, direction: aim, size: reach,
                               width: arc / 2, warning: wait + active, damage: 0, type: type, visual: visual)
            guide.isGuide = true
            combat.hazards.append(guide)
            var beam = Hazard(id: combat.makeEntityID(), shape: .lane, position: origin, direction: startDirection,
                              size: reach, width: 0.7, warning: max(minimumWarning, wait), damage: 0, type: type,
                              visual: visual)
            beam.linger = active
            beam.tickDamage = base * 0.5
            beam.tickEvery = 0.25
            beam.spin = (clockwise ? -1 : 1) * arc / CGFloat(active)
            combat.hazards.append(beam)
            return wait + active

        case .hunt:
            let wait = warning(2.4, kit: kit)
            for hero in heroes {
                var mark = Hazard(id: combat.makeEntityID(), shape: .circle, position: hero.position, direction: aim,
                                  size: 1.5, width: 0, warning: max(minimumWarning, wait), damage: base * 1.2,
                                  type: type, visual: visual)
                mark.follows = hero.hero
                mark.lockTime = 0.7
                combat.hazards.append(mark)
            }
            return 0.6

        case .eclipse:
            // A long warning: the whole arena is about to matter, not just
            // one patch of ground, so the player needs real time to notice
            // and cross to the safe circle before it starts costing health.
            // The circle opens away from Fate, so reaching it never means
            // walking into the scythe; its distance is always well inside
            // what a hero covers in the warning.
            let warningTime = FateTuning.eclipseWarning
            let awayFromFate = combat.world.delta(from: origin, to: target.position)
            let away = awayFromFate.lengthSquared > 0.0001 ? awayFromFate.normalized : aim
            let reach = FateTuning.eclipseSafeDistance * CGFloat(combat.random.range(0.55, 1))
            let wobble = CGFloat(combat.random.range(-0.6, 0.6))
            let bearing = CGPoint(x: away.x * cos(wobble) - away.y * sin(wobble),
                                  y: away.x * sin(wobble) + away.y * cos(wobble))
            let safeCenter = combat.world.wrap(target.position + bearing * reach)
            combat.darkness = DarknessState(safeCenter: safeCenter, safeRadius: FateTuning.eclipseSafeRadius,
                                            warningRemaining: warningTime,
                                            activeRemaining: FateTuning.eclipseDuration,
                                            damagePerSecond: FateTuning.eclipseDamagePerSecond)
            // In its last phase Fate opens the dark with firebombs. They all
            // land inside the warning, before the dark can hurt, and never on
            // the circle — hard, but never without an answer.
            if brain.phase >= 2, kit.firebombs {
                _ = firebombRain(kit: kit, base: base, aim: aim, heroes: heroes, combat: &combat)
            }
            // Fate channels the dark, standing still for all of it: it can
            // never walk into the safe circle and swing at whoever is in it.
            return warningTime + FateTuning.eclipseDuration
        }
    }

    /// Fate's firebomb rain: the Powder Fiend's bomb — its marked disc, its
    /// blast and its burn — dropped one after another. Staggered so no
    /// moment has every one of them landing at once, and never on the one
    /// safe circle while the Encroaching Abyss is up.
    @discardableResult
    static func firebombRain(kit: BossKit, base: Double, aim: CGPoint, heroes: [AITarget],
                             combat: inout CombatState) -> Double {
        guard !heroes.isEmpty else { return 0.4 }
        let first = warning(FateTuning.firebombWarning, kit: kit)
        var burn: (damage: Double, ticks: Int, every: Double) = (0, 0, 1)
        if case let .explosive(bomb) = EnemyCatalog.explosiveElite.eliteKit {
            burn = (bomb.burnTickDamage * combat.enemyDamageScale, bomb.burnTicks, bomb.burnTickEvery)
        }
        let clearance = (combat.darkness?.safeRadius ?? 0) + FateTuning.firebombRadius + 0.4
        var placed = 0
        var tries = 0
        while placed < FateTuning.firebombCount, tries < FateTuning.firebombCount * 6 {
            tries += 1
            let hero = heroes[placed % heroes.count]
            // The first falls where the hero stands, so it has to be moved
            // for; the rest scatter around, in the order they will land.
            var point = placed < heroes.count
                ? hero.position
                : combat.randomPoint(around: hero.position, within: FateTuning.firebombSpread)
            if let darkness = combat.darkness {
                // A hero already in the circle is not bombed there; that bomb
                // scatters around them instead.
                if combat.world.distance(point, darkness.safeCenter) < clearance {
                    point = combat.randomPoint(around: hero.position, within: FateTuning.firebombSpread)
                }
                if combat.world.distance(point, darkness.safeCenter) < clearance { continue }
            }
            var bomb = Hazard(id: combat.makeEntityID(), shape: .circle, position: combat.world.wrap(point),
                              direction: aim, size: FateTuning.firebombRadius, width: 0,
                              warning: max(minimumWarning, first + FateTuning.firebombStagger * Double(placed)),
                              damage: base * 1.0, type: .fire, visual: .fire)
            bomb.burnTickDamage = burn.damage
            bomb.burnTicks = burn.ticks
            bomb.burnTickEvery = burn.every
            combat.hazards.append(bomb)
            placed += 1
        }
        return 0.6
    }

    private static func addHazard(_ combat: inout CombatState, _ shape: Hazard.Shape, at position: CGPoint,
                                  direction: CGPoint, size: CGFloat, width: CGFloat, warning: Double,
                                  damage: Double, type: DamageType, visual: VisualStyle) {
        combat.hazards.append(Hazard(id: combat.makeEntityID(), shape: shape, position: combat.world.wrap(position),
                                     direction: direction, size: size, width: width,
                                     warning: max(minimumWarning, warning), damage: damage, type: type,
                                     visual: visual))
    }

    /// Its own kind, called in around the champion.
    private static func call(_ kind: EnemyKindID, count: Int, around origin: CGPoint, combat: inout CombatState) {
        guard let definition = EnemyCatalog.definition(for: kind), combat.enemies.count + count <= crowdLimit else { return }
        let index = combat.enemies.kindIndex(for: definition)
        combat.events.append(.burst(position: origin, radius: 1.6, visual: .shadow))
        for slot in 0..<count {
            let angle = 2 * Double.pi * Double(slot) / Double(max(count, 1)) + combat.random.range(-0.3, 0.3)
            let offset = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle))) * CGFloat(combat.random.range(2.4, 3.6))
            let position = combat.world.wrap(origin + offset)
            combat.enemies.append(id: combat.makeEntityID(), kind: index, position: position, speedScale: 1,
                                  healthScale: combat.enemyHealthScale)
            combat.events.append(.summoned(position: position, visual: .shadow))
        }
    }

    /// One thing from a weighted pool, called in — a mix of elites and,
    /// rarely, a returning boss — never past `limit` of the pool's own
    /// kinds standing at once, so summons never crowd the fight past reading.
    private static func callFromPool(_ pool: [(kind: EnemyKindID, weight: Double)], limit: Int, around origin: CGPoint,
                                     combat: inout CombatState) {
        guard !pool.isEmpty, combat.enemies.count < crowdLimit else { return }
        let poolIDs = Set(pool.map(\.kind))
        let alreadyAlive = (0..<combat.enemies.count).filter { poolIDs.contains(combat.enemies.definition(at: $0).id) }
            .count
        guard alreadyAlive < limit else { return }
        let totalWeight = pool.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return }
        var roll = combat.random.unit() * totalWeight
        var chosen = pool[0].kind
        for entry in pool {
            if roll <= entry.weight {
                chosen = entry.kind
                break
            }
            roll -= entry.weight
        }
        guard let definition = EnemyCatalog.definition(for: chosen) else { return }
        let index = combat.enemies.kindIndex(for: definition)
        let angle = combat.random.range(0, 2 * Double.pi)
        let offset = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle))) * CGFloat(combat.random.range(3, 4.5))
        let position = combat.world.wrap(origin + offset)
        combat.events.append(.burst(position: origin, radius: 1.6, visual: .shadow))
        combat.enemies.append(id: combat.makeEntityID(), kind: index, position: position, speedScale: 1,
                              healthScale: combat.enemyHealthScale)
        combat.events.append(.summoned(position: position, visual: .shadow))
    }

    // MARK: Ground — Fate's darkness

    /// Ages the Encroaching Abyss and, once its warning passes, costs
    /// health to whoever stands outside its one safe circle — through the
    /// same `strikeHero` incident a hazard's tick uses, so armor, barrier
    /// and invulnerability all apply exactly as they would to a hazard.
    private static func advanceDarkness(_ combat: inout CombatState, targets: [AITarget], dt: TimeInterval) {
        guard var state = combat.darkness else { return }
        // The dark is Fate's own; with nothing left on the field that can
        // cast it, it lifts at once rather than outliving its maker.
        let caster = (0..<combat.enemies.count).contains { index in
            combat.enemies.health[index] > 0
                && (combat.enemies.definition(at: index).kit?.moves.contains(.eclipse) ?? false)
        }
        guard caster else {
            combat.darkness = nil
            return
        }
        if state.warningRemaining > 0 {
            state.warningRemaining -= dt
        } else {
            state.activeRemaining -= dt
            for target in targets where target.isAlive {
                let distance = combat.world.distance(target.position, state.safeCenter)
                guard distance > state.safeRadius else { continue }
                let amount = target.maxHealth * state.damagePerSecond * dt
                guard amount > 0 else { continue }
                let direction = combat.world.delta(from: state.safeCenter, to: target.position)
                let away = direction.lengthSquared > 0.0001 ? direction.normalized : CGPoint(x: 1, y: 0)
                combat.incidents.append(.strikeHero(hero: target.hero, amount: amount, direction: away))
            }
        }
        combat.darkness = state.isFinished ? nil : state
    }

    // MARK: Shots

    private static func fire(_ beat: BossBrain.Beat, from index: Int, definition: EnemyDefinition,
                             combat: inout CombatState, targets: [AITarget]) {
        guard index < combat.enemies.count else { return }
        let origin = combat.enemies.positions[index]
        let type = definition.damageType
        switch beat.action {
        case .ring(let count, let offset):
            for shot in 0..<count {
                let angle = offset + 2 * Double.pi * Double(shot) / Double(count)
                shoot(&combat, from: origin, angle: angle, beat: beat, type: type)
            }
        case .fan(let count, let spread):
            guard let hero = nearestHero(to: origin, in: targets, world: combat.world) else { return }
            let toward = combat.world.delta(from: origin, to: hero.position)
            let centre = Double(atan2(toward.y, toward.x))
            for shot in 0..<count {
                let t = count > 1 ? Double(shot) / Double(count - 1) - 0.5 : 0
                shoot(&combat, from: origin, angle: centre + t * spread, beat: beat, type: type)
            }
        case .stream(let angle, let arms):
            for arm in 0..<arms {
                let armAngle = angle + 2 * Double.pi * Double(arm) / Double(arms)
                shoot(&combat, from: origin, angle: armAngle, beat: beat, type: type)
            }
        }
    }

    static func sprite(for type: DamageType) -> SpriteID {
        switch type {
        case .fire: return .projectileEmberBolt
        case .cold: return .projectileShard
        case .lightning: return .projectileStormBolt
        case .arcane, .shadow: return .projectileArcaneBolt
        case .physical, .poison, .holy: return .projectileBolt
        }
    }

    private static func shoot(_ combat: inout CombatState, from origin: CGPoint, angle: Double,
                              beat: BossBrain.Beat, type: DamageType) {
        let direction = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
        let speed = min(beat.speed, fastestShot)
        let hit = Hit(amount: beat.damage, type: type, tags: [.projectile], direction: direction,
                      knockback: 0.3, canCrit: false, depth: 1, source: .environment)
        combat.hostileProjectiles.append(Projectile(
            id: combat.makeEntityID(), position: combat.world.wrap(origin + direction * beat.spawn),
            velocity: direction * speed, remainingLife: 3.6,
            pierceRemaining: 0, hit: hit, radius: 0.26, splashRadius: 0, spriteID: sprite(for: type),
            visual: VisualStyle.matching(type), isHostile: true))
    }

    // MARK: Ground

    private static func advanceHazards(_ combat: inout CombatState, targets: [AITarget], dt: TimeInterval) {
        guard !combat.hazards.isEmpty else { return }
        let reach = combat.tuning.playerRadius
        for slot in combat.hazards.indices {
            combat.hazards[slot].age += dt
            var hazard = combat.hazards[slot]

            // A hunt follows its hero until the last moments, then holds still.
            if let hero = hazard.follows, !hazard.hasLanded, hazard.age < hazard.warning - hazard.lockTime,
               let target = targets.first(where: { $0.hero == hero && $0.isAlive }) {
                hazard.position = target.position
            }

            if !hazard.hasLanded, hazard.age >= hazard.warning {
                hazard.hasLanded = true
                hazard.tickTimer = hazard.tickEvery
                // Burn is queued first: the strike that follows grants a
                // moment of invulnerability, and a burn queued after it would
                // be refused by a guard meant for an already-invulnerable hero.
                if !hazard.isGuide, hazard.burnTicks > 0 {
                    burn(hazard, targets: targets, reach: reach, combat: &combat)
                }
                if !hazard.isGuide, hazard.damage > 0 {
                    hurt(hazard, amount: hazard.damage, targets: targets, reach: reach, combat: &combat)
                }
                if let boss = hazard.carriesBoss, let index = combat.index(ofEnemy: boss) {
                    combat.enemies.positions[index] = hazard.position
                    combat.enemies.knockback[index] = .zero
                }
            } else if hazard.isActive {
                if hazard.spin != 0 {
                    let angle = hazard.spin * CGFloat(dt)
                    let c = cos(angle)
                    let s = sin(angle)
                    hazard.direction = CGPoint(x: hazard.direction.x * c - hazard.direction.y * s,
                                               y: hazard.direction.x * s + hazard.direction.y * c)
                }
                hazard.tickTimer -= dt
                if hazard.tickTimer <= 0, hazard.tickDamage > 0 {
                    hazard.tickTimer += max(0.1, hazard.tickEvery)
                    hurt(hazard, amount: hazard.tickDamage, targets: targets, reach: reach, combat: &combat)
                }
            }
            combat.hazards[slot] = hazard
        }
        combat.hazards.removeAll { $0.isFinished }
    }

    private static func hurt(_ hazard: Hazard, amount: Double, targets: [AITarget], reach: CGFloat,
                             combat: inout CombatState) {
        for target in targets where target.isAlive {
            guard hazard.covers(target.position, radius: reach, world: combat.world) else { continue }
            let away = combat.world.delta(from: hazard.position, to: target.position)
            let direction = away.lengthSquared > 0.0001 ? away.normalized : hazard.direction
            combat.incidents.append(.strikeHero(hero: target.hero, amount: amount, direction: direction))
        }
    }

    /// A hazard's own fire, left burning on whoever it caught.
    private static func burn(_ hazard: Hazard, targets: [AITarget], reach: CGFloat, combat: inout CombatState) {
        for target in targets where target.isAlive {
            guard hazard.covers(target.position, radius: reach, world: combat.world) else { continue }
            combat.incidents.append(.burnHero(hero: target.hero, tickDamage: hazard.burnTickDamage,
                                              ticks: hazard.burnTicks, tickEvery: hazard.burnTickEvery))
        }
    }

    private static func nearestHero(to point: CGPoint, in targets: [AITarget], world: ToroidalWorld) -> AITarget? {
        var best: AITarget?
        var bestSquared = CGFloat.greatestFiniteMagnitude
        for target in targets where target.isAlive {
            let squared = world.distanceSquared(point, target.position)
            if squared < bestSquared {
                bestSquared = squared
                best = target
            }
        }
        return best
    }
}
