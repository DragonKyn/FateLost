import CoreGraphics
import Foundation

// How other players' movement is drawn smoothly from a stream that is not.
//
// The host sends a picture of the world 15 times a second. Drawn as it
// arrives, a remote hero would step 15 times a second, and step unevenly:
// networks deliver those pictures late, in bunches and now and then not at
// all. Nothing here changes what the game *is* (the host's simulation stays
// the truth for collisions, damage, death and revival); it only decides where
// a remote hero is *drawn* between pictures.
//
//   * RemoteTrack   keeps the last few pictures of one hero and answers "where
//                   were they at time t?" by interpolating between two of them,
//                   or, when the stream is late, by carrying on along their
//                   velocity for a short, clamped while.
//   * StreamClock   learns how host time maps onto this phone's clock, and how
//                   jittery the stream is, and so how far behind "now" to draw.
//   * VisualFollower  eases the host's own drawing of a guest, whose position
//                   is nudged by the guest's reports, onto a steady path.
//   * MovementStats aggregate counters (never one line per packet).

/// One picture of a hero.
struct MovementSample: Equatable {
    /// When it was true, on the host's clock, in seconds.
    var time: Double
    var position: CGPoint
    /// Tiles per second.
    var velocity: CGPoint
    var facing: CGPoint
    /// The hero jumped (a teleport, a recall, a revival elsewhere): never
    /// draw a slide from the picture before this one.
    var isDiscontinuity = false
}

/// Where a track says a hero is at a moment.
struct MovementReading: Equatable {
    enum Kind: Equatable {
        /// Between two pictures: the usual case.
        case interpolated
        /// Past the newest picture: carried along the last velocity, briefly.
        case extrapolated
        /// Past the newest picture by too long: held where the extrapolation ended.
        case held
        /// Before the oldest picture kept (a stream that has only just begun).
        case early
    }

    var position: CGPoint
    var velocity: CGPoint
    var facing: CGPoint
    var kind: Kind
}

/// The last few pictures of one remote hero.
struct RemoteTrack {
    /// How many pictures are kept. About half a second at 15 a second: far more
    /// than the delay ever reaches back.
    static let capacity = 8
    /// The longest a hero is carried along their velocity past the newest picture.
    static let maxExtrapolation: Double = 0.25
    /// A gap this big between consecutive pictures, beyond what the velocity
    /// explains, is a jump and is never slid across.
    static let teleportDistance: CGFloat = 6
    /// A hero cannot plausibly move faster than this (tiles per second).
    static let maxPlausibleSpeed: CGFloat = 40

    enum Push: Equatable {
        case accepted
        /// Older than, or the same age as, a picture already held: dropped.
        case stale
    }

    private(set) var samples: [MovementSample] = []

    var latestTime: Double? { samples.last?.time }
    var isEmpty: Bool { samples.isEmpty }

    mutating func removeAll() {
        samples.removeAll(keepingCapacity: true)
    }

    /// Adds a picture. One that is out of order or repeated is ignored.
    @discardableResult
    mutating func push(_ incoming: MovementSample, world: ToroidalWorld, forceDiscontinuity: Bool = false) -> Push {
        var sample = incoming
        if let last = samples.last {
            guard sample.time > last.time else { return .stale }
            let elapsed = CGFloat(sample.time - last.time)
            let jump = world.distance(last.position, sample.position)
            // How far the last velocity explains, with generous slack for a turn.
            let explained = last.velocity.length * elapsed + 1.5
            if forceDiscontinuity || jump > max(Self.teleportDistance, explained * 1.5)
                || jump / max(elapsed, 0.001) > Self.maxPlausibleSpeed {
                sample.isDiscontinuity = true
            }
        }
        samples.append(sample)
        if samples.count > Self.capacity {
            samples.removeFirst(samples.count - Self.capacity)
        }
        return .accepted
    }

    /// Where the hero was at `time`, on the host's clock.
    func reading(at time: Double, world: ToroidalWorld) -> MovementReading? {
        guard let first = samples.first, let last = samples.last else { return nil }

        if time <= first.time {
            return MovementReading(position: first.position, velocity: first.velocity, facing: first.facing,
                                   kind: .early)
        }
        if time >= last.time {
            let late = time - last.time
            let carried = min(late, Self.maxExtrapolation)
            // Only carried along a velocity that is believable, and never past the limit.
            var velocity = last.velocity
            if velocity.length > Self.maxPlausibleSpeed { velocity = velocity.normalized * Self.maxPlausibleSpeed }
            let position = world.wrap(last.position + velocity * CGFloat(carried))
            return MovementReading(position: position, velocity: late > Self.maxExtrapolation ? .zero : velocity,
                                   facing: last.facing,
                                   kind: late > Self.maxExtrapolation ? .held : (late > 0 ? .extrapolated : .interpolated))
        }

        // Between two pictures: find the pair around `time`.
        var later = samples.count - 1
        while later > 0 && samples[later - 1].time >= time { later -= 1 }
        let a = samples[later - 1]
        let b = samples[later]
        if b.isDiscontinuity {
            // A jump lies between them: stay with the earlier one until it is
            // the later one's turn, rather than sliding across the gap.
            return MovementReading(position: a.position, velocity: a.velocity, facing: a.facing, kind: .interpolated)
        }
        let span = b.time - a.time
        let t = span > 0.000001 ? CGFloat((time - a.time) / span) : 1
        let offset = world.delta(from: a.position, to: b.position)
        let position = world.wrap(a.position + offset * t)
        let velocity = CGPoint(x: a.velocity.x + (b.velocity.x - a.velocity.x) * t,
                               y: a.velocity.y + (b.velocity.y - a.velocity.y) * t)
        return MovementReading(position: position, velocity: velocity, facing: t < 0.5 ? a.facing : b.facing,
                               kind: .interpolated)
    }
}

/// Maps the host's clock onto this phone's, and measures how uneven the
/// stream is, so the drawing knows how far behind "now" to stay.
struct StreamClock {
    /// The snapshot interval this is tuned for (15 a second).
    static let interval: Double = 1.0 / 15
    /// How far behind the newest news a hero is drawn when the stream is
    /// steady: a picture and a half, so two pictures are nearly always held.
    static let baseDelay: Double = 0.1
    /// The most extra delay jitter can buy.
    static let maxDelay: Double = 0.2
    /// A clock that has moved this far from what a picture says is started over.
    static let resyncThreshold: Double = 0.4

    private(set) var offset: Double?
    private(set) var jitter: Double = 0
    private var lastLocal: Double?
    private var lastHost: Double?

    /// A picture stamped `hostTime` arrived at `localTime`.
    mutating func observe(hostTime: Double, localTime: Double) {
        let sample = localTime - hostTime
        if var current = offset {
            if abs(sample - current) > Self.resyncThreshold {
                current = sample
            } else if sample < current {
                // The earliest arrival is the truest picture of the link; it is
                // moved toward quickly, but not all at once.
                current += (sample - current) * 0.3
            } else {
                current += (sample - current) * 0.02
            }
            offset = current
        } else {
            offset = sample
        }
        if let lastLocal, let lastHost {
            let error = abs((localTime - lastLocal) - (hostTime - lastHost))
            jitter += (error - jitter) * 0.1
        }
        lastLocal = localTime
        lastHost = hostTime
    }

    /// The delay in force: steady streams get the base, jittery ones a little more.
    var delay: Double {
        min(Self.maxDelay, Self.baseDelay + 2 * jitter)
    }

    /// The host time to draw, at local time `now`.
    func renderTime(atLocal now: Double) -> Double? {
        guard let offset else { return nil }
        return now - offset - delay
    }
}

/// Eases where the host draws a guest onto a steady path.
///
/// On the host a guest is moved by that player's stick and, a few times a
/// second, nudged toward where their phone says they are. The nudges are
/// small and correct, but each is a small step. This carries the drawn
/// position along the guest's velocity between frames and blends it onto the
/// simulated one, so the nudges are absorbed instead of seen. The simulation is
/// untouched, and the drawing is never more than a few frames from it.
struct VisualFollower {
    /// Seconds for the drawing to close about two thirds of a gap.
    static let responseTime: CGFloat = 0.07
    /// A gap this big is a jump (a recall, a revival elsewhere): drawn at once.
    static let snapDistance: CGFloat = 3.5

    private(set) var position: CGPoint?

    mutating func update(target: CGPoint, velocity: CGPoint, dt: CGFloat, world: ToroidalWorld,
                         snap: Bool = false) -> CGPoint {
        guard let current = position, !snap else {
            position = target
            return target
        }
        // Carry on the way they are going, then close what is left of the gap.
        let carried = world.wrap(current + velocity * min(max(dt, 0), 0.1))
        let error = world.delta(from: carried, to: target)
        if error.length > Self.snapDistance {
            position = target
            return target
        }
        let blend = 1 - CGFloat(exp(-Double(max(dt, 0) / Self.responseTime)))
        let next = world.wrap(carried + error * blend)
        position = next
        return next
    }

    mutating func reset() {
        position = nil
    }
}

/// Counters for the whole run, not one line per packet.
struct MovementStats: Equatable {
    var snapshots = 0
    var stale = 0
    var seconds: Double = 0
    /// Frames drawn from each kind of reading.
    var interpolatedFrames = 0
    var extrapolatedFrames = 0
    var heldFrames = 0
    var earlyFrames = 0
    /// Discontinuities: pictures a slide was refused across.
    var jumps = 0
    /// Longest gap between two pictures, in seconds.
    var longestGap: Double = 0
    private var lastArrival: Double?
    /// Sum of arrival gaps, for the mean.
    private var gapTotal: Double = 0

    mutating func noteArrival(at local: Double, accepted: Bool) {
        if accepted { snapshots += 1 } else { stale += 1 }
        if let lastArrival {
            let gap = local - lastArrival
            gapTotal += gap
            longestGap = max(longestGap, gap)
        }
        lastArrival = local
    }

    mutating func note(_ kind: MovementReading.Kind) {
        switch kind {
        case .interpolated: interpolatedFrames += 1
        case .extrapolated: extrapolatedFrames += 1
        case .held: heldFrames += 1
        case .early: earlyFrames += 1
        }
    }

    var meanGap: Double { snapshots > 1 ? gapTotal / Double(snapshots - 1) : 0 }

    /// The share of drawn frames that had to be guessed rather than interpolated.
    var guessedShare: Double {
        let total = interpolatedFrames + extrapolatedFrames + heldFrames + earlyFrames
        return total > 0 ? Double(extrapolatedFrames + heldFrames) / Double(total) : 0
    }
}

/// A guest's view of everyone else: the stream of snapshots, kept as one
/// track per hero, and the clock that says where in them to draw.
struct RemotePlayback {
    /// The render time may run at most this much faster or slower than real
    /// time, so a change in the link's delay is walked into, never jumped.
    static let slew: Double = 0.1
    /// A discrepancy in a hero's drawn path fades over about this long. A jump
    /// bigger than `absorbLimit` is real (a teleport) and is drawn at once.
    static let absorbTime: Double = 0.12
    static let absorbLimit: CGFloat = 3

    private(set) var tracks: [UInt8: RemoteTrack] = [:]
    private(set) var clock = StreamClock()
    private(set) var stats = MovementStats()
    private var lastTick: UInt32?
    private var renderedTime: Double?
    private var renderedAt: Double?

    private struct Drawing {
        var raw: CGPoint
        var velocity: CGPoint
        var at: Double
        /// What is added to the raw reading so the drawn path stays continuous.
        var correction: CGPoint = .zero
    }
    private var drawings: [UInt8: Drawing] = [:]

    /// Takes in a snapshot that arrived at local time `now`. Returns false for
    /// one that is stale or repeated, which the caller should ignore whole.
    @discardableResult
    mutating func receive(_ snapshot: NetSnapshot, at now: Double, mySlot: UInt8, world: ToroidalWorld) -> Bool {
        if let lastTick, snapshot.tickMilliseconds <= lastTick {
            // A tick that went backwards by a long way is a host that started over.
            if lastTick - snapshot.tickMilliseconds < 5_000 {
                stats.noteArrival(at: now, accepted: false)
                return false
            }
            reset()
        }
        lastTick = snapshot.tickMilliseconds
        let hostTime = Double(snapshot.tickMilliseconds) / 1000
        clock.observe(hostTime: hostTime, localTime: now)
        var present = Set<UInt8>()
        for hero in snapshot.heroes where hero.slot != mySlot {
            present.insert(hero.slot)
            var track = tracks[hero.slot] ?? RemoteTrack()
            let sample = MovementSample(time: hostTime, position: hero.position,
                                        velocity: hero.isDefeated ? .zero : hero.velocity, facing: hero.facing)
            if track.push(sample, world: world) == .accepted, track.samples.last?.isDiscontinuity == true {
                stats.jumps += 1
            }
            tracks[hero.slot] = track
        }
        for slot in tracks.keys where !present.contains(slot) {
            tracks[slot] = nil
            drawings[slot] = nil
        }
        stats.noteArrival(at: now, accepted: true)
        return true
    }

    /// The host time to draw at local time `now`: the clock's answer, slewed so
    /// it never runs much faster or slower than real time.
    private mutating func renderTime(atLocal now: Double) -> Double? {
        guard let target = clock.renderTime(atLocal: now) else { return nil }
        guard let time = renderedTime, let at = renderedAt else {
            renderedTime = target
            renderedAt = now
            return target
        }
        let elapsed = max(0, now - at)
        // A stall or a restart is taken as it comes; everything else is walked into.
        if abs(target - (time + elapsed)) > 0.3 {
            renderedTime = target
        } else {
            renderedTime = min(max(target, time + elapsed * (1 - Self.slew)), time + elapsed * (1 + Self.slew))
        }
        renderedAt = now
        return renderedTime
    }

    /// Where a remote hero should be drawn at local time `now`.
    mutating func reading(slot: UInt8, at now: Double, world: ToroidalWorld) -> MovementReading? {
        guard let time = renderTime(atLocal: now),
              var reading = tracks[slot]?.reading(at: time, world: world) else { return nil }
        stats.note(reading.kind)

        // Whatever the stream did (a late picture, a gap ending), the drawn path
        // stays continuous: a small jump in the raw reading is absorbed and fades.
        var drawing = drawings[slot] ?? Drawing(raw: reading.position, velocity: reading.velocity, at: now)
        let elapsed = now - drawing.at
        if elapsed > 0, elapsed < 0.5 {
            // Where the hero should be by now if they simply carried on at the
            // speed they are at now: the difference is what is absorbed.
            let predicted = world.wrap(drawing.raw + reading.velocity * CGFloat(elapsed))
            let jump = world.delta(from: predicted, to: reading.position)
            if jump.length > Self.absorbLimit {
                drawing.correction = .zero
            } else {
                drawing.correction = drawing.correction - jump
            }
            let fade = CGFloat(exp(-elapsed / Self.absorbTime))
            drawing.correction = drawing.correction * fade
        } else if elapsed >= 0.5 {
            drawing.correction = .zero
        }
        drawing.raw = reading.position
        drawing.velocity = reading.velocity
        drawing.at = now
        drawings[slot] = drawing

        reading.position = world.wrap(reading.position + drawing.correction)
        return reading
    }

    /// Forgets the stream: after a reconnection, or when the host starts a new run.
    mutating func reset() {
        tracks.removeAll()
        clock = StreamClock()
        lastTick = nil
        renderedTime = nil
        renderedAt = nil
        drawings.removeAll()
    }
}

/// What the host draws for its guests: each on a steady path.
struct GuestVisuals {
    private var followers: [Int: VisualFollower] = [:]
    private var wasDefeated: [Int: Bool] = [:]

    /// The position to draw a guest at, given where the simulation has them.
    mutating func position(of slot: Int, simulated: CGPoint, velocity: CGPoint, isDefeated: Bool, dt: CGFloat,
                           world: ToroidalWorld) -> CGPoint {
        var follower = followers[slot] ?? VisualFollower()
        // A fallen hero lies still, and one who has just risen is drawn where they are.
        let changed = wasDefeated[slot] != isDefeated
        wasDefeated[slot] = isDefeated
        let drawn = follower.update(target: simulated, velocity: isDefeated ? .zero : velocity, dt: dt, world: world,
                                    snap: isDefeated || changed)
        followers[slot] = follower
        return drawn
    }

    mutating func forget(_ slot: Int) {
        followers[slot] = nil
        wasDefeated[slot] = nil
    }
}
