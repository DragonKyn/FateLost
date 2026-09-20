import CoreGraphics
import Foundation
import Observation

// MARK: - What the scene asks of a party run

enum PartyRunRole: Equatable {
    /// This phone runs the simulation for everyone.
    case host
    /// This phone shows what the host sends and sends back what its player wants.
    case client
}

/// Who a seat is, for drawing their hero and their name.
struct PartyRosterEntry: Equatable {
    var slot: Int
    var name: String
    var look: HeroAppearance
    var weapon: WeaponID
}

/// A hero in the party as the scene draws them.
struct PartyHeroState: Equatable {
    var slot: Int
    var position: CGPoint
    var velocity: CGPoint
    var facing: CGPoint
    var health: Double
    var maxHealth: Double
    var barrier: Double
    var isDefeated: Bool
    var isInvulnerable: Bool
    var isStealthed: Bool
    var isSheltered: Bool
    var isConnected: Bool
    var weaponSprite: SpriteID?
    var form: FormID?
}

struct PartyMarkerState: Equatable {
    var slot: Int
    var position: CGPoint
    var progress: Double
    var reviverSlot: Int?
}

struct PartyPresentation: Equatable {
    var heroes: [PartyHeroState] = []
    var markers: [PartyMarkerState] = []
}

/// The link between a running scene and the party. The scene calls it at fixed
/// points in its frame; it does everything with the network.
@MainActor
protocol PartyRunDriver: AnyObject {
    var role: PartyRunRole { get }
    var mySlot: Int { get }
    var roster: [Int: PartyRosterEntry] { get }

    /// Host: before the frame's simulation steps, carry out what players asked.
    func hostWillStep(_ simulation: inout GameSimulation, dt: TimeInterval)
    /// Host: after them, with what happened, tagged by hero.
    func hostDidFrame(_ simulation: inout GameSimulation, events: [(hero: Int, event: CombatEvent)], dt: TimeInterval)
    /// Client: advance the mirror, send input, and return what to present.
    func clientFrame(_ simulation: inout GameSimulation, intent: PlayerIntent, dt: TimeInterval) -> [CombatEvent]
    /// Client: ask the host to do something for this player's hero.
    func send(_ command: NetCommand)
    /// A menu (skill tree, a find) opened or closed on this phone.
    func menuChanged(open: Bool)
    /// The party as it should be drawn.
    func presentation(of simulation: GameSimulation) -> PartyPresentation
    /// Host: the run is over. Everyone is told.
    func hostFinished(outcome: RunSummary.Outcome, simulation: inout GameSimulation)
}

/// The end of a run, for the results screen.
struct PartyResults: Equatable {
    var outcome: String
    var headline: String
    var detail: String?
    var summary: RunSummary?
    var echoes = 0
    /// Every hero's numbers and the shared pool, when the host sent them.
    var report: PartyReport?
    /// This phone's seat, to pick this player out of the report.
    var mySlot = 0
}

// MARK: - The controller

/// One multiplayer run as this phone plays it: the host's side (running the
/// simulation, hearing from every player, telling each what they need to
/// see) or a client's (watching, and asking).
///
/// Nothing here draws. The scene owns the simulation and calls in through
/// `PartyRunDriver`; this owns the conversation with the service.
@MainActor
@Observable
final class PartyRunController: PartyRunDriver {
    let info: RunStartInfo
    let role: PartyRunRole
    let mySlot: Int
    private(set) var roster: [Int: PartyRosterEntry] = [:]

    /// Set when the run is over and the results should show.
    private(set) var results: PartyResults?
    /// "Waiting for the host", "Reconnecting", or nil.
    private(set) var statusNote: String?
    /// The content of the host's snapshots does not match this app.
    private(set) var contentMismatch = false

    @ObservationIgnored weak var hub: MultiplayerHub?
    @ObservationIgnored private weak var services: AppServices?
    @ObservationIgnored weak var scene: GameScene?
    @ObservationIgnored var onResults: ((PartyResults) -> Void)?

    // Host state.
    @ObservationIgnored private var inputs: [Int: NetInput] = [:]
    @ObservationIgnored private var lastInputTime: [Int: TimeInterval] = [:]
    @ObservationIgnored private var pendingPresses: [Int: UInt8] = [:]
    @ObservationIgnored private var pendingInteract: Set<Int> = []
    @ObservationIgnored private var commands: [(slot: Int, command: NetCommand)] = []
    @ObservationIgnored private var pendingEvents: [(hero: Int, event: CombatEvent)] = []
    @ObservationIgnored private var lastSelfState: [Int: Data] = [:]
    @ObservationIgnored private var sendClock: TimeInterval = 0
    @ObservationIgnored private var selfClock: TimeInterval = 0
    @ObservationIgnored private var clock: TimeInterval = 0
    @ObservationIgnored private var finished = false
    /// The host has told the service the run is over and is waiting for word back.
    @ObservationIgnored private var closing = false
    @ObservationIgnored private var resyncSlots: Set<Int> = []

    // Client state.
    @ObservationIgnored private var latestSnapshot: NetSnapshot?
    @ObservationIgnored private var pendingClientEvents: [CombatEvent] = []
    @ObservationIgnored private var pendingSelfState: HeroSelfState?
    @ObservationIgnored private var inputSequence: UInt16 = 0
    @ObservationIgnored private var inputClock: TimeInterval = 0
    @ObservationIgnored private var accumulatedPresses: UInt8 = 0
    @ObservationIgnored private var interactPending = false
    @ObservationIgnored private var menuOpen = false
    /// The last input actually sent, and how long ago, so an unchanged stick
    /// is not sent twenty times a second.
    @ObservationIgnored private var lastSentInput: NetInput?
    @ObservationIgnored private var sinceInputSent: TimeInterval = 0

    /// How often the host sends pictures (per second), and how often each player's own state.
    static let snapshotRate: Double = 15
    static let selfStateInterval: TimeInterval = 0.25
    static let inputRate: Double = 20
    /// An unchanged input is repeated this often while moving (well inside the
    /// host's timeout), and this often while standing still.
    static let inputRepeatMoving: TimeInterval = 0.14
    static let inputRepeatIdle: TimeInterval = 0.4
    /// How far from a player the world is sent to them, in tiles.
    static let interestRadius: CGFloat = 26
    /// A silent client's stick is let go after this long.
    static let inputTimeout: TimeInterval = 0.6

    init(info: RunStartInfo, hub: MultiplayerHub, services: AppServices) {
        self.info = info
        self.hub = hub
        self.services = services
        role = info.you == info.hostId ? .host : .client
        mySlot = info.myEntry?.slot ?? 0
        for entry in info.roster {
            roster[entry.slot] = PartyRosterEntry(slot: entry.slot, name: entry.name,
                                                   look: PartyLoadout.appearance(from: entry.hero), weapon: entry.weapon)
        }
        hub.client.onFrame = { [weak self] kind, slot, payload in self?.received(kind, from: slot, payload) }
        hub.client.onPeer = { [weak self] notice in self?.peerChanged(notice) }
        hub.client.onReconnected = { [weak self] in self?.reconnected() }
    }

    var runID: String { info.runId }

    // MARK: Lifecycle

    /// The service says this run is going on and this phone is back in it.
    func resumed(_ info: RunStartInfo) {
        statusNote = nil
        if role == .client {
            // The host sends a fresh picture; until then, wait.
            latestSnapshot = nil
        }
    }

    private func reconnected() {
        statusNote = nil
        if role == .host {
            for slot in roster.keys where slot != mySlot { resyncSlots.insert(slot) }
        }
    }

    func stop() {
        finished = true
        if let hub, hub.client.onFrame != nil {
            hub.client.onFrame = nil
            hub.client.onPeer = nil
            hub.client.onReconnected = nil
        }
    }

    /// The service has ended the run: show how it went.
    func serviceEndedRun(_ end: RunEndInfo) {
        guard results == nil, let scene else { return }
        finished = true
        let outcome = RunSummary.Outcome(serviceOutcome: end.outcome)
        // The host counted every hero and split the echoes; believe their numbers.
        let report = PartyReport(json: end.summary?["report"])
        var summary = Self.makeSummary(simulation: scene.simulation, outcome: outcome, run: info,
                                       stats: report?.hero(slot: mySlot)?.stats)
        if let seconds = end.summary?["secondsSurvived"]?.intValue { summary.secondsSurvived = seconds }
        if let wave = end.summary?["wave"]?.intValue { summary.wave = max(summary.wave, wave) }
        let pooled = report?.hero(slot: mySlot) != nil ? report?.share : nil
        let echoes = services?.record(summary, echoes: pooled) ?? 0
        let headline = PartyRunSummary.headline(for: LobbyRoom.LastRun(runId: end.runId, outcome: end.outcome, summary: end.summary))
        let detail = PartyRunSummary.detail(for: LobbyRoom.LastRun(runId: end.runId, outcome: end.outcome, summary: end.summary))
        let finalResults = PartyResults(outcome: end.outcome, headline: headline, detail: detail, summary: summary,
                                        echoes: echoes, report: report, mySlot: mySlot)
        results = finalResults
        onResults?(finalResults)
    }

    static func makeSummary(simulation: GameSimulation, outcome: RunSummary.Outcome, run: RunStartInfo,
                            stats: RunStats? = nil) -> RunSummary {
        let seconds = Int(simulation.elapsed - (simulation.timeSinceWipe ?? 0))
        var summary = RunSummary(realm: simulation.run.realmID, weapon: simulation.run.starterWeaponID,
                                 secondsSurvived: max(0, seconds), stats: stats ?? simulation.stats,
                                 level: simulation.progression.level, allocation: simulation.allocation)
        summary.outcome = outcome
        summary.wave = simulation.wave.index
        summary.relics = simulation.relics
        return summary
    }

    // MARK: Receiving

    private func received(_ kind: FrameKind, from slot: Int?, _ payload: Data) {
        guard !finished else { return }
        switch (role, kind) {
        case (.host, .input):
            guard let slot, let input = NetInput.decode(payload) else { return }
            inputs[slot] = input
            lastInputTime[slot] = clock
            pendingPresses[slot, default: 0] |= input.abilityPresses
            if input.interact { pendingInteract.insert(slot) }
        case (.host, .command):
            guard let slot, let command = NetCommand.decode(payload) else { return }
            if commands.count < 64 { commands.append((slot, command)) }
        case (.client, .snapshot):
            if let snapshot = NetSnapshot.decode(payload) {
                latestSnapshot = snapshot
            } else if payload.first != NetTables.contentVersion {
                contentMismatch = true
            }
        case (.client, .events):
            if let events = NetEventCodec.decode(payload) {
                pendingClientEvents.append(contentsOf: events)
                if pendingClientEvents.count > 400 { pendingClientEvents.removeFirst(pendingClientEvents.count - 400) }
            }
        case (.client, .selfState):
            if let state = try? JSONDecoder().decode(HeroSelfState.self, from: payload) {
                pendingSelfState = state
            }
        default:
            break
        }
    }

    private func peerChanged(_ notice: PeerNotice) {
        guard role == .host, !finished, let scene else { return }
        scene.mutateSimulation { simulation in
            guard let index = simulation.members.firstIndex(where: { $0.id == notice.id }) else { return }
            switch notice.event {
            case .connected:
                simulation.setConnected(true, forHero: index)
            case .disconnected:
                simulation.setConnected(false, forHero: index)
            case .left:
                simulation.removeHero(index)
            }
        }
        if notice.event == .connected { resyncSlots.insert(notice.slot) }
    }

    // MARK: Host

    func hostWillStep(_ simulation: inout GameSimulation, dt: TimeInterval) {
        clock += dt
        for index in 1..<max(1, simulation.heroCount) {
            let slot = simulation.members[index].slot
            // A guest that has gone quiet lets go of the stick.
            let fresh = clock - (lastInputTime[slot] ?? -10) < Self.inputTimeout
            HostInput.apply(fresh ? inputs[slot] : nil, presses: pendingPresses[slot] ?? 0,
                            interact: pendingInteract.contains(slot), toHero: index, in: &simulation)
            pendingPresses[slot] = 0
        }
        pendingInteract.removeAll()

        for entry in commands {
            guard let index = simulation.members.firstIndex(where: { $0.slot == entry.slot }) else { continue }
            apply(entry.command, toHero: index, in: &simulation)
        }
        commands.removeAll()
    }

    private func apply(_ command: NetCommand, toHero index: Int, in simulation: inout GameSimulation) {
        HostInput.apply(command, toHero: index, in: &simulation)
        // The player sees the outcome at once.
        resyncSlots.insert(simulation.members[index].slot)
    }

    func hostDidFrame(_ simulation: inout GameSimulation, events: [(hero: Int, event: CombatEvent)], dt: TimeInterval) {
        guard !finished else { return }
        pendingEvents.append(contentsOf: events)
        if pendingEvents.count > 600 { pendingEvents.removeFirst(pendingEvents.count - 600) }
        sendClock += dt
        selfClock += dt
        let sendInterval = 1 / Self.snapshotRate
        guard sendClock >= sendInterval || !resyncSlots.isEmpty else { return }
        sendClock = 0

        let sendSelf = selfClock >= Self.selfStateInterval || !resyncSlots.isEmpty
        if sendSelf { selfClock = 0 }
        let slotOf: (Int) -> UInt8 = { [members = simulation.members] hero in
            members.indices.contains(hero) ? UInt8(clamping: members[hero].slot) : 0xFF
        }

        // Everything for every player goes out as one message: the service counts
        // messages it receives, not the players they reach.
        var outgoing: [(target: UInt8, kind: FrameKind, payload: Data)] = []
        for index in 1..<max(1, simulation.heroCount) {
            let member = simulation.members[index]
            guard member.isConnected, !member.isGone else { continue }
            let slot = UInt8(clamping: member.slot)

            let picture = simulation.snapshot(forViewer: index, radius: Self.interestRadius)
            outgoing.append((slot, .snapshot, picture.encoded()))

            let mine = pendingEvents.filter { !$0.event.isPersonal || $0.hero == index }.map { $0.event }
            if !mine.isEmpty {
                outgoing.append((slot, .events, NetEventCodec.encode(mine, slotOf: slotOf)))
            }
            if sendSelf {
                let state = simulation.perform(as: index) { $0.captureSelfState() }
                if let data = try? JSONEncoder().encode(state), data.count < PartyProtocol.maxHostFrame {
                    outgoing.append((slot, .selfState, data))
                }
            }
        }
        hub?.client.sendBatch(outgoing)
        pendingEvents.removeAll()
        resyncSlots.removeAll()
    }

    func hostFinished(outcome: RunSummary.Outcome, simulation: inout GameSimulation) {
        guard !finished, !closing, role == .host else { return }
        closing = true
        // Everyone gets their final numbers before the run is closed.
        for index in 1..<max(1, simulation.heroCount) {
            let member = simulation.members[index]
            guard member.isConnected, !member.isGone else { continue }
            let state = simulation.perform(as: index) { $0.captureSelfState() }
            if let data = try? JSONEncoder().encode(state) {
                hub?.client.sendFrame(.selfState, payload: data, target: UInt8(clamping: member.slot))
            }
        }
        let seconds = max(0, Int(simulation.elapsed - (simulation.timeSinceWipe ?? 0)))
        let report = PartyReport.make(simulation: &simulation, outcome: outcome, seconds: seconds)
        var fields: [String: JSONValue] = [
            "wave": .number(Double(simulation.wave.index)),
            "secondsSurvived": .number(Double(seconds)),
            "kills": .number(Double(report.totalKills)),
            "heroes": .array(report.heroes.map {
                .object(["name": .string($0.name), "level": .number(Double($0.level)), "kills": .number(Double($0.kills))])
            }),
        ]
        if let json = report.json { fields["report"] = json }
        let summary: JSONValue = .object(fields)
        // The host keeps answering its clients until the service confirms.
        hub?.client.endRun(runID: info.runId, outcome: outcome.serviceValue, summary: summary)
    }

    // MARK: Client

    func clientFrame(_ simulation: inout GameSimulation, intent: PlayerIntent, dt: TimeInterval) -> [CombatEvent] {
        guard !finished else { return [] }
        clock += dt
        if let state = pendingSelfState {
            pendingSelfState = nil
            simulation.applySelfState(state)
        }
        if let snapshot = latestSnapshot {
            latestSnapshot = nil
            simulation.applyMirror(snapshot)
        }
        var walking = intent
        walking.abilityPresses = 0
        simulation.advanceMirror(dt: dt, intent: simulation.hasMirroredState ? walking : .idle)

        accumulatedPresses |= intent.abilityPresses
        if intent.interact { interactPending = true }
        inputClock += dt
        sinceInputSent += dt
        if inputClock >= 1 / Self.inputRate {
            inputClock = 0
            var input = NetInput()
            input.move = intent.move
            input.abilityPresses = accumulatedPresses
            input.interact = interactPending
            input.menuOpen = menuOpen
            input.position = simulation.player.position
            if Self.worthSending(input, since: lastSentInput, elapsed: sinceInputSent) {
                inputSequence &+= 1
                input.sequence = inputSequence
                lastSentInput = input
                sinceInputSent = 0
                accumulatedPresses = 0
                interactPending = false
                hub?.client.sendFrame(.input, payload: input.encoded())
            }
        }

        let events = pendingClientEvents
        pendingClientEvents.removeAll()
        return events
    }

    /// Whether an input differs enough from the last one sent, or the last one
    /// has gone quiet for long enough, to be worth a message. A button, a
    /// change of stick or of menu always is.
    static func worthSending(_ input: NetInput, since last: NetInput?, elapsed: TimeInterval) -> Bool {
        guard let last else { return true }
        if input.abilityPresses != 0 || input.interact || input.menuOpen != last.menuOpen { return true }
        if abs(input.move.x - last.move.x) > 0.04 || abs(input.move.y - last.move.y) > 0.04 { return true }
        let repeatAfter = input.move == .zero ? inputRepeatIdle : inputRepeatMoving
        return elapsed >= repeatAfter
    }

    func send(_ command: NetCommand) {
        guard role == .client else { return }
        hub?.client.sendFrame(.command, payload: command.encoded())
    }

    func menuChanged(open: Bool) {
        menuOpen = open
    }

    func presentation(of simulation: GameSimulation) -> PartyPresentation {
        var result = PartyPresentation()
        if role == .host {
            for index in 0..<simulation.heroCount {
                let hero = simulation.heroSummary(index)
                result.heroes.append(PartyHeroState(
                    slot: hero.slot, position: hero.position, velocity: hero.velocity, facing: hero.facing,
                    health: hero.health, maxHealth: hero.maxHealth, barrier: hero.barrier,
                    isDefeated: hero.isDefeated, isInvulnerable: hero.isInvulnerable, isStealthed: hero.isStealthed,
                    isSheltered: hero.isSheltered, isConnected: hero.isConnected, weaponSprite: hero.weaponSprite,
                    form: hero.form))
            }
            for marker in simulation.reviveMarkers where marker.hero < simulation.members.count {
                result.markers.append(PartyMarkerState(
                    slot: simulation.members[marker.hero].slot, position: marker.position, progress: marker.progress,
                    reviverSlot: marker.reviver.flatMap {
                        $0 < simulation.members.count ? simulation.members[$0].slot : nil
                    }))
            }
        } else if let world = simulation.mirror {
            for hero in world.heroes {
                result.heroes.append(PartyHeroState(
                    slot: Int(hero.slot), position: hero.position, velocity: hero.velocity, facing: hero.facing,
                    health: hero.health, maxHealth: hero.maxHealth, barrier: hero.barrier, isDefeated: hero.isDefeated,
                    isInvulnerable: hero.isInvulnerable, isStealthed: hero.isStealthed,
                    isSheltered: hero.isSheltered, isConnected: hero.isConnected, weaponSprite: hero.weaponSprite,
                    form: hero.form))
            }
            for marker in world.markers {
                result.markers.append(PartyMarkerState(slot: Int(marker.slot), position: marker.position,
                                                       progress: marker.progress, reviverSlot: marker.reviver.map(Int.init)))
            }
        }
        return result
    }

    /// Words for a screen: who the host is doing without, or nothing.
    func updateStatus(hostAwayUntil: Date?, state: PartyConnectionState) {
        switch state {
        case .reconnecting, .connecting:
            statusNote = "Reconnecting to the party…"
        case .failed(let error):
            statusNote = error.message
        default:
            if role == .client, let until = hostAwayUntil {
                let seconds = max(0, Int(until.timeIntervalSinceNow.rounded(.up)))
                statusNote = "The host lost connection. Waiting \(seconds)s for them to return…"
            } else {
                statusNote = nil
            }
        }
    }
}

extension RunSummary.Outcome {
    /// The words the service uses for how a run ended.
    init(serviceOutcome: String) {
        self = serviceOutcome == "conquered" ? .conquered : .defeated
    }

    var serviceValue: String {
        switch self {
        case .conquered: return "conquered"
        case .defeated: return "defeated"
        }
    }
}
