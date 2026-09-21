import CoreGraphics
import XCTest
@testable import FateLost

/// Other players' movement, drawn from a stream that arrives late, unevenly,
/// out of order and sometimes not at all. The stream is simulated here with
/// seeded latency, jitter and loss; what is measured is what would be drawn.
@MainActor
final class MovementSmoothingTests: XCTestCase {
    private let world = ToroidalWorld(width: 128, height: 128)
    private let frame = 1.0 / 60
    private let snapshotInterval = 1.0 / 15

    // MARK: A hero's true motion, and a bad network to carry it

    /// Where a hero really is at time `t`, as a function the tests choose.
    private typealias Truth = (Double) -> (position: CGPoint, velocity: CGPoint)

    private func walking(speed: Double = 4.2) -> Truth {
        { (t: Double) -> (position: CGPoint, velocity: CGPoint) in
            let x: Double = 20 + speed * t
            return (CGPoint(x: x, y: 30), CGPoint(x: speed, y: 0))
        }
    }

    /// Reverses direction every `period` seconds, at full speed.
    private func zigzag(period: Double, speed: Double = 4.2) -> Truth {
        { (t: Double) -> (position: CGPoint, velocity: CGPoint) in
            let phase: Double = t / period
            let whole = Int(floor(phase))
            let within: Double = (phase - Double(whole)) * period
            let forward = whole % 2 == 0
            let travelled: Double = forward ? speed * within : speed * (period - within)
            let heading: Double = forward ? speed : -speed
            return (CGPoint(x: 20 + travelled, y: 30), CGPoint(x: heading, y: 0))
        }
    }

    private struct Packet {
        var sentAt: Double
        var arrivesAt: Double
        var tick: UInt32
        var position: CGPoint
        var velocity: CGPoint
    }

    /// The stream a host would send, through a link with the given behaviour.
    private func stream(of truth: Truth, seconds: Double, latency: Double, jitter: Double, loss: Double = 0,
                        dropWindow: ClosedRange<Double>? = nil, seed: UInt64 = 1) -> [Packet] {
        var random = SeededRandom(seed: seed)
        var packets: [Packet] = []
        var t = 0.0
        while t < seconds {
            let state = truth(t)
            let lost = random.unit() < loss || (dropWindow?.contains(t) ?? false)
            if !lost {
                let delay = latency + (random.unit() * 2 - 1) * jitter
                packets.append(Packet(sentAt: t, arrivesAt: t + max(0.001, delay), tick: UInt32(t * 1000),
                                      position: state.position, velocity: state.velocity))
            }
            t += snapshotInterval
        }
        return packets.sorted { $0.arrivesAt < $1.arrivesAt }
    }

    private func snapshot(_ packet: Packet, slot: UInt8 = 2) -> NetSnapshot {
        var snapshot = NetSnapshot()
        snapshot.tickMilliseconds = packet.tick
        snapshot.heroes = [NetHero(slot: slot, flags: NetHero.connected, position: packet.position,
                                   velocity: packet.velocity, facing: CGPoint(x: 1, y: 0), health: 100,
                                   maxHealth: 100, barrier: 0, level: 1, weaponSprite: nil, form: nil)]
        return snapshot
    }

    struct Drawn {
        var time: Double
        var position: CGPoint
        var truth: CGPoint
        var kind: MovementReading.Kind
    }

    /// Draws the stream at 60 frames a second and reports what was drawn.
    private func draw(_ packets: [Packet], truth: Truth, from start: Double = 0.6, until end: Double,
                      playback: inout RemotePlayback) -> [Drawn] {
        var drawn: [Drawn] = []
        var next = 0
        var now = 0.0
        while now < end {
            while next < packets.count, packets[next].arrivesAt <= now {
                playback.receive(snapshot(packets[next]), at: packets[next].arrivesAt, mySlot: 1, world: world)
                next += 1
            }
            if now >= start, let reading = playback.reading(slot: 2, at: now, world: world) {
                drawn.append(Drawn(time: now, position: reading.position, truth: truth(now).position, kind: reading.kind))
            }
            now += frame
        }
        return drawn
    }

    /// The same stream drawn the old way: wherever the newest picture says.
    private func drawNaively(_ packets: [Packet], truth: Truth, from start: Double = 0.6, until end: Double) -> [Drawn] {
        var drawn: [Drawn] = []
        var next = 0
        var latest: CGPoint?
        var lastTick: UInt32 = 0
        var now = 0.0
        while now < end {
            while next < packets.count, packets[next].arrivesAt <= now {
                if packets[next].tick > lastTick { latest = packets[next].position; lastTick = packets[next].tick }
                next += 1
            }
            if now >= start, let latest {
                drawn.append(Drawn(time: now, position: latest, truth: truth(now).position, kind: .interpolated))
            }
            now += frame
        }
        return drawn
    }

    /// How uneven the drawn steps are while the hero moves at a steady pace:
    /// the standard deviation of the frame-to-frame step over its mean.
    private func stepUnevenness(_ drawn: [Drawn]) -> Double {
        var steps: [Double] = []
        for index in 1..<drawn.count {
            steps.append(Double(world.distance(drawn[index - 1].position, drawn[index].position)))
        }
        let mean = steps.reduce(0, +) / Double(steps.count)
        let variance = steps.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(steps.count)
        return variance.squareRoot() / max(mean, 0.0001)
    }

    private func largestStep(_ drawn: [Drawn]) -> Double {
        (1..<drawn.count).map { Double(world.distance(drawn[$0 - 1].position, drawn[$0].position)) }.max() ?? 0
    }

    private func worstError(_ drawn: [Drawn]) -> Double {
        drawn.map { Double(world.distance($0.position, $0.truth)) }.max() ?? 0
    }

    // MARK: Interpolation

    func testAnOrdinaryConnectionIsDrawnAsSteadyMotion() {
        var playback = RemotePlayback()
        let truth = walking()
        let packets = stream(of: truth, seconds: 6, latency: 0.03, jitter: 0.01)
        let smooth = draw(packets, truth: truth, until: 6, playback: &playback)
        let naive = drawNaively(packets, truth: truth, until: 6)

        XCTAssertLessThan(stepUnevenness(smooth), 0.12, "movement should be even from frame to frame")
        XCTAssertGreaterThan(stepUnevenness(naive), 0.9, "the old drawing stepped 15 times a second")
        // A 4.2 tiles a second walk is 0.07 tiles a frame: no frame should jump.
        XCTAssertLessThan(largestStep(smooth), 0.07 * 1.3)
        // And it is never far from where the hero is: the delay costs a fraction of a second.
        XCTAssertLessThan(worstError(smooth), 4.2 * 0.3)
        XCTAssertEqual(playback.stats.stale, 0)
        XCTAssertEqual(playback.stats.guessedShare, 0, accuracy: 0.05, "nothing had to be guessed")
    }

    func testModerateLatencyIsSmoothToo() {
        var playback = RemotePlayback()
        let truth = walking()
        let packets = stream(of: truth, seconds: 6, latency: 0.12, jitter: 0.02)
        let smooth = draw(packets, truth: truth, until: 6, playback: &playback)
        XCTAssertLessThan(stepUnevenness(smooth), 0.15)
        XCTAssertLessThan(largestStep(smooth), 0.07 * 1.4)
        XCTAssertLessThan(worstError(smooth), 4.2 * (0.12 + 0.2 + 0.1))
    }

    func testHeavyJitterAndReorderingAreAbsorbed() {
        var playback = RemotePlayback()
        let truth = walking()
        // Packets wander by 80 ms either way: some overtake others.
        let packets = stream(of: truth, seconds: 8, latency: 0.1, jitter: 0.08, seed: 7)
        let smooth = draw(packets, truth: truth, until: 8, playback: &playback)
        let naive = drawNaively(packets, truth: truth, until: 8)
        XCTAssertLessThan(stepUnevenness(smooth), stepUnevenness(naive) * 0.5)
        XCTAssertLessThan(largestStep(smooth), 0.07 * 3, "no lurch worth the name")
        XCTAssertGreaterThan(playback.clock.jitter, 0.005, "the stream's unevenness was measured")
        XCTAssertLessThanOrEqual(playback.clock.delay, StreamClock.maxDelay)
        XCTAssertGreaterThan(playback.clock.delay, StreamClock.baseDelay)
    }

    func testABriefLossIsCarriedOverAndTheHeroIsNotPulledBack() {
        var playback = RemotePlayback()
        let truth = walking()
        // 0.3 s of nothing: four snapshots gone.
        let packets = stream(of: truth, seconds: 6, latency: 0.04, jitter: 0.01, dropWindow: 3.0...3.3)
        let smooth = draw(packets, truth: truth, until: 6, playback: &playback)
        XCTAssertLessThan(largestStep(smooth), 0.07 * 1.5, "a gap must not become a lurch")
        // The hero kept moving forward through the gap: never drawn going back.
        var backwards = 0
        for index in 1..<smooth.count where smooth[index].position.x < smooth[index - 1].position.x - 0.001 { backwards += 1 }
        XCTAssertEqual(backwards, 0)
        XCTAssertGreaterThan(playback.stats.extrapolatedFrames, 0, "it did carry on by extrapolating")
        XCTAssertLessThan(worstError(smooth), 4.2 * 0.7)
    }

    func testAnEndlessOutageIsHeldNotDriftedAway() {
        var playback = RemotePlayback()
        let truth = walking()
        // The stream stops for good at 2 seconds.
        let packets = stream(of: truth, seconds: 2, latency: 0.03, jitter: 0)
        let drawn = draw(packets, truth: truth, until: 8, playback: &playback)
        let last = drawn.last!
        let lastSent = packets.last!.position
        // However long it lasts, the hero is never carried further than the clamp allows.
        let carried = Double(world.distance(last.position, lastSent))
        XCTAssertLessThan(carried, 4.2 * (RemoteTrack.maxExtrapolation + 0.05))
        XCTAssertEqual(last.kind, .held)
        XCTAssertGreaterThan(playback.stats.heldFrames, 100)
    }

    func testRapidDirectionChangesStayClose() {
        var playback = RemotePlayback()
        let truth = zigzag(period: 0.25)
        let packets = stream(of: truth, seconds: 6, latency: 0.06, jitter: 0.02, seed: 3)
        let smooth = draw(packets, truth: truth, until: 6, playback: &playback)
        // Turning every quarter second, the drawing trails by the delay, but never
        // strays further than that from the hero, and never overshoots the path.
        XCTAssertLessThan(worstError(smooth), 4.2 * 0.4)
        let range = 4.2 * 0.25
        for entry in smooth {
            XCTAssertGreaterThanOrEqual(entry.position.x, 20 - 0.5, "drawn past where the hero has been")
            XCTAssertLessThanOrEqual(entry.position.x, 20 + range + 0.5)
        }
    }

    func testADashIsFollowedAtItsOwnSpeed() {
        var playback = RemotePlayback()
        // A walk, then a dash of 6 tiles in 0.2 s, then a walk.
        let walkEnd: Double = 20 + 4.2 * 3
        let dashEnd: Double = walkEnd + 6
        let truth: Truth = { (t: Double) -> (position: CGPoint, velocity: CGPoint) in
            if t < 3 {
                let x: Double = 20 + 4.2 * t
                return (CGPoint(x: x, y: 30), CGPoint(x: 4.2, y: 0))
            }
            if t < 3.2 {
                let x: Double = walkEnd + 30 * (t - 3)
                return (CGPoint(x: x, y: 30), CGPoint(x: 30, y: 0))
            }
            let x: Double = dashEnd + 4.2 * (t - 3.2)
            return (CGPoint(x: x, y: 30), CGPoint(x: 4.2, y: 0))
        }
        let packets = stream(of: truth, seconds: 6, latency: 0.05, jitter: 0.01)
        let smooth = draw(packets, truth: truth, until: 6, playback: &playback)
        XCTAssertLessThan(largestStep(smooth), 0.5 * 1.3, "the dash is drawn as motion (30 tiles a second is half a tile a frame)")
        XCTAssertLessThan(worstError(smooth), 5.6)
        XCTAssertEqual(playback.stats.jumps, 0, "a dash is fast, not a teleport")
        // Afterwards the drawing has caught up.
        XCTAssertLessThan(Double(world.distance(smooth.last!.position, smooth.last!.truth)), 4.2 * 0.4)
    }

    func testATeleportIsNeverSlidAcross() {
        var playback = RemotePlayback()
        let truth: Truth = { (t: Double) -> (position: CGPoint, velocity: CGPoint) in
            if t < 3 {
                let x: Double = 20 + 4.2 * t
                return (CGPoint(x: x, y: 30), CGPoint(x: 4.2, y: 0))
            }
            let x: Double = 80 + 4.2 * (t - 3)
            return (CGPoint(x: x, y: 90), CGPoint(x: 4.2, y: 0))
        }
        let packets = stream(of: truth, seconds: 6, latency: 0.05, jitter: 0.01)
        let smooth = draw(packets, truth: truth, until: 6, playback: &playback)
        XCTAssertEqual(playback.stats.jumps, 1, "one jump was recognised")
        // No frame is drawn in the middle of the gap.
        let before = CGPoint(x: 20 + 4.2 * 3, y: 30)
        let after = CGPoint(x: 80, y: 90)
        for entry in smooth {
            let nearBefore = world.distance(entry.position, before) < 6
            let nearAfter = world.distance(entry.position, after) < 6
            let onEarlyPath = entry.position.y == 30 || abs(entry.position.y - 30) < 0.5
            let onLatePath = abs(entry.position.y - 90) < 0.5
            XCTAssertTrue(nearBefore || nearAfter || onEarlyPath || onLatePath, "drawn sliding across a teleport at \(entry.position)")
        }
        // It is snapped, in one frame, rather than eased.
        XCTAssertGreaterThan(largestStep(smooth), 20)
        var bigSteps = 0
        for index in 1..<smooth.count where world.distance(smooth[index - 1].position, smooth[index].position) > 2 { bigSteps += 1 }
        XCTAssertEqual(bigSteps, 1)
    }

    func testAcrossTheSeamOfTheWorldIsAsSmoothAsAnywhereElse() {
        var playback = RemotePlayback()
        // Walking over the edge where the map wraps round.
        let truth: Truth = { (t: Double) -> (position: CGPoint, velocity: CGPoint) in
            let raw: Double = 120 + 4.2 * t
            let x: Double = raw.truncatingRemainder(dividingBy: 128)
            return (CGPoint(x: x, y: 30), CGPoint(x: 4.2, y: 0))
        }
        let packets = stream(of: truth, seconds: 6, latency: 0.05, jitter: 0.01)
        let smooth = draw(packets, truth: truth, until: 6, playback: &playback)
        XCTAssertLessThan(largestStep(smooth), 0.07 * 1.5, "the seam must not be a jump")
        XCTAssertEqual(playback.stats.jumps, 0)
    }

    // MARK: Order, staleness, the clock

    func testStaleAndRepeatedPicturesAreIgnored() {
        var playback = RemotePlayback()
        let base = Packet(sentAt: 0, arrivesAt: 0, tick: 10_000, position: CGPoint(x: 20, y: 30), velocity: .zero)
        XCTAssertTrue(playback.receive(snapshot(base), at: 1, mySlot: 1, world: world))
        var newer = base
        newer.tick = 10_066
        newer.position = CGPoint(x: 21, y: 30)
        XCTAssertTrue(playback.receive(snapshot(newer), at: 1.07, mySlot: 1, world: world))
        // An older one arriving late, and a repeat of the newer one.
        XCTAssertFalse(playback.receive(snapshot(base), at: 1.08, mySlot: 1, world: world))
        XCTAssertFalse(playback.receive(snapshot(newer), at: 1.09, mySlot: 1, world: world))
        XCTAssertEqual(playback.stats.snapshots, 2)
        XCTAssertEqual(playback.stats.stale, 2)
        XCTAssertEqual(playback.tracks[2]?.samples.count, 2, "the stale pictures never entered the track")
        // A host that started over (its clock far behind) is taken as a new stream.
        var restarted = base
        restarted.tick = 100
        XCTAssertTrue(playback.receive(snapshot(restarted), at: 2, mySlot: 1, world: world))
        XCTAssertEqual(playback.tracks[2]?.samples.count, 1)
    }

    func testTheLocalHeroIsNeverTakenFromTheStream() {
        var playback = RemotePlayback()
        var snapshot = NetSnapshot()
        snapshot.tickMilliseconds = 1000
        let hero = NetHero(slot: 1, flags: NetHero.connected, position: CGPoint(x: 5, y: 5), velocity: .zero,
                           facing: CGPoint(x: 1, y: 0), health: 100, maxHealth: 100, barrier: 0, level: 1,
                           weaponSprite: nil, form: nil)
        snapshot.heroes = [hero]
        playback.receive(snapshot, at: 1, mySlot: 1, world: world)
        XCTAssertNil(playback.tracks[1], "a phone's own hero is drawn from prediction, not from a delayed picture")
    }

    func testTheClockLearnsTheLinkAndResyncsAfterAStall() {
        var clock = StreamClock()
        for step in 0..<40 {
            let host = Double(step) / 15
            clock.observe(hostTime: host, localTime: host + 0.08)
        }
        XCTAssertEqual(clock.offset ?? 0, 0.08, accuracy: 0.002)
        XCTAssertEqual(clock.delay, StreamClock.baseDelay, accuracy: 0.01, "a steady stream is drawn at the base delay")
        // The phone is suspended for a second: the offset is started over, not slowly dragged.
        clock.observe(hostTime: 3, localTime: 4.3)
        XCTAssertEqual(clock.offset ?? 0, 1.3, accuracy: 0.001)
        XCTAssertNotNil(clock.renderTime(atLocal: 5))
    }

    func testAnEmptyTrackAnswersNothingAndAnEarlyOneAnswersItsFirstPicture() {
        var track = RemoteTrack()
        XCTAssertNil(track.reading(at: 1, world: world))
        track.push(MovementSample(time: 2, position: CGPoint(x: 9, y: 9), velocity: .zero, facing: CGPoint(x: 1, y: 0)),
                   world: world)
        let early = track.reading(at: 1, world: world)
        XCTAssertEqual(early?.kind, .early)
        XCTAssertEqual(early?.position, CGPoint(x: 9, y: 9))
    }

    // MARK: The host's own drawing of a guest

    func testTheHostSeesAGuestOnASteadyPathDespiteTheirReportsNudgingThem() {
        // The simulation walks the guest at 4.2 tiles a second and, every 0.14 s,
        // a report moves them a little (as an adopted position does).
        var follower = VisualFollower()
        var simulated = CGPoint(x: 20, y: 30)
        var drawnSteps: [Double] = []
        var simulatedSteps: [Double] = []
        var previousDrawn: CGPoint?
        var previousSimulated = simulated
        var worstGap = 0.0
        var time = 0.0
        var nudge = 1.0
        while time < 5 {
            simulated.x += CGFloat(4.2 * frame)
            if Int(time * 1000) % 140 < 17 { simulated.x += CGFloat(0.18 * nudge); nudge = -nudge }
            let drawn = follower.update(target: simulated, velocity: CGPoint(x: 4.2, y: 0), dt: CGFloat(frame), world: world)
            if let previousDrawn { drawnSteps.append(Double(world.distance(previousDrawn, drawn))) }
            simulatedSteps.append(Double(world.distance(previousSimulated, simulated)))
            previousDrawn = drawn
            previousSimulated = simulated
            worstGap = max(worstGap, Double(world.distance(drawn, simulated)))
            time += frame
        }
        XCTAssertLessThan(drawnSteps.max() ?? 0, (simulatedSteps.max() ?? 1) * 0.7, "the nudges are absorbed")
        XCTAssertLessThan(worstGap, 0.35, "and the drawing is never far from the simulation")
    }

    func testTheHostDrawsAJumpAtOnce() {
        var follower = VisualFollower()
        _ = follower.update(target: CGPoint(x: 20, y: 30), velocity: .zero, dt: 0.016, world: world)
        let drawn = follower.update(target: CGPoint(x: 60, y: 30), velocity: .zero, dt: 0.016, world: world)
        XCTAssertEqual(drawn, CGPoint(x: 60, y: 30), "a recall or a revival is not slid to")
        var guests = GuestVisuals()
        let alive = guests.position(of: 2, simulated: CGPoint(x: 10, y: 10), velocity: CGPoint(x: 4, y: 0), isDefeated: false,
                                    dt: 0.016, world: world)
        XCTAssertEqual(alive, CGPoint(x: 10, y: 10))
        let fallen = guests.position(of: 2, simulated: CGPoint(x: 12, y: 10), velocity: .zero, isDefeated: true, dt: 0.016,
                                     world: world)
        XCTAssertEqual(fallen, CGPoint(x: 12, y: 10), "a fallen hero lies exactly where they fell")
        let risen = guests.position(of: 2, simulated: CGPoint(x: 12, y: 10), velocity: .zero, isDefeated: false, dt: 0.016,
                                    world: world)
        XCTAssertEqual(risen, CGPoint(x: 12, y: 10))
    }

    // MARK: Correctness is untouched, and the cost is small

    func testDrawingNeverChangesWhereAHeroActuallyIs() {
        // The visual layer reads pictures and returns positions; it has no way to write one.
        var track = RemoteTrack()
        for index in 0..<20 {
            track.push(MovementSample(time: Double(index) / 15, position: CGPoint(x: CGFloat(index), y: 3),
                                      velocity: CGPoint(x: 15, y: 0), facing: CGPoint(x: 1, y: 0)), world: world)
        }
        XCTAssertEqual(track.samples.count, RemoteTrack.capacity)
        XCTAssertEqual(track.samples.last?.position, CGPoint(x: 19, y: 3), "the stored truth is what was sent")
    }

    func testTheWholeFeatureCostsLittlePerFrameForAFullParty() {
        var playback = RemotePlayback()
        var snapshot = NetSnapshot()
        for slot in 0..<4 {
            snapshot.heroes.append(NetHero(slot: UInt8(slot), flags: NetHero.connected, position: CGPoint(x: 20 + CGFloat(slot), y: 30),
                                           velocity: CGPoint(x: 4, y: 0), facing: CGPoint(x: 1, y: 0), health: 100,
                                           maxHealth: 100, barrier: 0, level: 1, weaponSprite: nil, form: nil))
        }
        measure {
            var now = 0.0
            for index in 0..<3600 {
                if index % 4 == 0 {
                    snapshot.tickMilliseconds = UInt32(index * 17)
                    for hero in snapshot.heroes.indices { snapshot.heroes[hero].position.x += 0.28 }
                    playback.receive(snapshot, at: now, mySlot: 0, world: world)
                }
                for slot in 1..<4 { _ = playback.reading(slot: UInt8(slot), at: now, world: world) }
                now += frame
            }
        }
    }

    func testTheSnapshotRateAndSizeKeepTheBandwidthSmall() throws {
        var snapshot = NetSnapshot()
        for slot in 0..<4 {
            snapshot.heroes.append(NetHero(slot: UInt8(slot), flags: NetHero.connected, position: CGPoint(x: 20, y: 30),
                                           velocity: CGPoint(x: 4, y: 0), facing: CGPoint(x: 1, y: 0), health: 100,
                                           maxHealth: 100, barrier: 0, level: 1, weaponSprite: nil, form: nil))
        }
        let bytes = snapshot.encoded().count
        // Four heroes and nothing else: what movement alone costs each snapshot.
        XCTAssertLessThan(bytes, 220)
        XCTAssertEqual(PartyRunController.snapshotRate, 15, "smoothing does not raise the send rate")
        // Per guest, per second, for movement alone.
        XCTAssertLessThan(Double(bytes) * PartyRunController.snapshotRate, 3_300)
    }
}
