import AVFoundation

/// Mixer channel a sound plays on; each has its own volume setting.
enum AudioChannel {
    case music
    case ambience
    case effects
    case interface
}

/// A named sound. Files are looked up in the bundle by name; a cue whose
/// files don't exist is silently skipped, so gameplay can trigger sounds
/// before the audio exists.
struct SoundCue: Hashable {
    /// One or more interchangeable recordings; one is picked at random each
    /// time so repeated sounds don't machine-gun.
    let fileNames: [String]
    let channel: AudioChannel
    /// Relative gain before channel and master volume.
    let gain: Float
    /// Minimum seconds between plays. In a brawl, dozens of identical hits
    /// can land in one frame; one well-placed sound reads better than forty.
    let minimumInterval: TimeInterval

    init(_ fileNames: [String], channel: AudioChannel, gain: Float = 1, minimumInterval: TimeInterval = 0) {
        self.fileNames = fileNames
        self.channel = channel
        self.gain = gain
        self.minimumInterval = minimumInterval
    }

    init(_ fileName: String, channel: AudioChannel, gain: Float = 1, minimumInterval: TimeInterval = 0) {
        self.init([fileName], channel: channel, gain: gain, minimumInterval: minimumInterval)
    }
}

extension SoundCue {
    // Interface
    static let uiConfirm = SoundCue("ui_confirm", channel: .interface, gain: 0.7)
    static let uiBack = SoundCue("ui_back", channel: .interface, gain: 0.7)

    // Combat
    static let swordSwing = SoundCue(["sfx_swing_1", "sfx_swing_2", "sfx_swing_3"], channel: .effects, gain: 0.55,
                                     minimumInterval: 0.05)
    static let hit = SoundCue(["sfx_hit_1", "sfx_hit_2", "sfx_hit_3"], channel: .effects, gain: 0.6,
                              minimumInterval: 0.045)
    static let criticalHit = SoundCue("sfx_hit_critical", channel: .effects, gain: 0.8, minimumInterval: 0.08)
    static let goblinDeath = SoundCue(["sfx_goblin_death_1", "sfx_goblin_death_2"], channel: .effects, gain: 0.5,
                                      minimumInterval: 0.07)
    static let bowShot = SoundCue("sfx_bow_shot", channel: .effects, gain: 0.55, minimumInterval: 0.05)
    static let arcaneCast = SoundCue("sfx_arcane_cast", channel: .effects, gain: 0.5, minimumInterval: 0.05)
    static let arcaneBurst = SoundCue("sfx_arcane_burst", channel: .effects, gain: 0.6, minimumInterval: 0.06)
    static let playerHurt = SoundCue("sfx_player_hurt", channel: .effects, gain: 0.8, minimumInterval: 0.2)
    static let playerDeath = SoundCue("sfx_player_death", channel: .effects, gain: 0.9)
    static let dodge = SoundCue("sfx_dodge", channel: .effects, gain: 0.5, minimumInterval: 0.15)
    static let kegBlast = SoundCue("sfx_keg_blast", channel: .effects, gain: 0.75, minimumInterval: 0.1)

    // Skills
    static let abilityImpact = SoundCue("sfx_ab_impact", channel: .effects, gain: 0.6, minimumInterval: 0.08)
    static let abilityFire = SoundCue("sfx_ab_fire", channel: .effects, gain: 0.55, minimumInterval: 0.08)
    static let abilityFrost = SoundCue("sfx_ab_frost", channel: .effects, gain: 0.55, minimumInterval: 0.08)
    static let abilityLightning = SoundCue("sfx_ab_lightning", channel: .effects, gain: 0.5, minimumInterval: 0.07)
    static let abilityHoly = SoundCue("sfx_ab_holy", channel: .effects, gain: 0.55, minimumInterval: 0.08)
    static let abilityShadow = SoundCue("sfx_ab_shadow", channel: .effects, gain: 0.55, minimumInterval: 0.08)
    static let abilityNature = SoundCue("sfx_ab_nature", channel: .effects, gain: 0.55, minimumInterval: 0.08)
    static let abilitySonic = SoundCue("sfx_ab_sonic", channel: .effects, gain: 0.55, minimumInterval: 0.08)
    static let abilityBuff = SoundCue("sfx_ab_buff", channel: .effects, gain: 0.6, minimumInterval: 0.1)
    static let summon = SoundCue("sfx_summon", channel: .effects, gain: 0.6, minimumInterval: 0.12)
    static let dash = SoundCue("sfx_dash", channel: .effects, gain: 0.55, minimumInterval: 0.08)
    static let heal = SoundCue("sfx_heal", channel: .effects, gain: 0.5, minimumInterval: 0.25)
    static let shapeshift = SoundCue("sfx_shapeshift", channel: .effects, gain: 0.7, minimumInterval: 0.2)

    // Progression
    static let levelUp = SoundCue("sfx_level_up", channel: .effects, gain: 0.85, minimumInterval: 0.3)
    /// Experience chimes climbing a pentatonic scale as embers are gathered
    /// in quick succession.
    static let emberChimes: [SoundCue] = (1...5).map {
        SoundCue("sfx_ember_\($0)", channel: .effects, gain: 0.32, minimumInterval: 0.06)
    }
    static let skillLearn = SoundCue("ui_skill_learn", channel: .interface, gain: 0.7)
    static let skillTreeOpen = SoundCue("ui_tree_open", channel: .interface, gain: 0.7)

    // Music and beds
    static let musicMenu = SoundCue("mus_menu_fate_lost", channel: .music)
    static let musicAshenWilds = SoundCue("mus_battle_ashen_wilds", channel: .music, gain: 0.85)
    static let musicDefeat = SoundCue("mus_defeat", channel: .music)
    static let ambienceAshenWilds = SoundCue("amb_ashen_wilds", channel: .ambience, gain: 0.5)
}

/// Plays music, ambience and effects at the player's chosen volumes.
///
/// Everything runs through one `AVAudioEngine`.
///
/// - **Effects** are decoded into memory once and played on a fixed bank of
///   voices, with minimal latency and no per-play allocation, which dense
///   combat needs. When every voice is busy the oldest is cut, so the newest
///   (most relevant) sound always plays.
/// - **Music and ambience** stream from disk. Looping tracks are queued back
///   to back on a player node, which is sample-accurate: compressed files
///   loop without the gap `AVAudioPlayer` leaves at the seam. Each has two
///   decks so tracks can crossfade.
@MainActor
final class AudioManager {
    private let volumes: () -> GameSettings

    private let engine = AVAudioEngine()
    private let effectsMixer = AVAudioMixerNode()
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var missingFiles: Set<String> = []
    private var lastPlayed: [SoundCue: TimeInterval] = [:]
    private var effectFormat: AVAudioFormat?
    private let voiceCount = 16

    private var musicDecks: [StreamDeck] = []
    private var ambienceDecks: [StreamDeck] = []
    private var currentMusic: SoundCue?
    private var currentAmbience: SoundCue?
    private var musicDucked = false
    private var fadeTimer: Timer?

    init(volumes: @escaping () -> GameSettings) {
        self.volumes = volumes
        configureSession()
        configureEngine()
        observeSystemEvents()
    }

    // MARK: - Effects

    func play(_ cue: SoundCue) {
        let now = ProcessInfo.processInfo.systemUptime
        if cue.minimumInterval > 0, let last = lastPlayed[cue], now - last < cue.minimumInterval {
            return
        }
        guard let name = cue.fileNames.randomElement(), let buffer = buffer(named: name) else { return }
        guard startEngineIfNeeded(), !voices.isEmpty else { return }
        lastPlayed[cue] = now

        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.volume = cue.gain * channelVolume(cue.channel)
        // `.interrupts` cuts whatever this voice was playing: voices are
        // used round-robin, so that is always the oldest sound.
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.isPlaying {
            voice.play()
        }
    }

    /// Decodes clips ahead of time so their first play has no hitch.
    func preload(_ cues: [SoundCue]) {
        for cue in cues {
            for name in cue.fileNames {
                _ = buffer(named: name)
            }
        }
    }

    // MARK: - Music and ambience

    /// Crossfades to a music track. Asking for the current track again does
    /// nothing, so screens can call this freely.
    func playMusic(_ cue: SoundCue, fadeDuration: TimeInterval = 1.5, loops: Bool = true) {
        guard cue != currentMusic else { return }
        currentMusic = cue
        crossfade(decks: musicDecks, to: cue, loops: loops, fadeDuration: fadeDuration)
    }

    func stopMusic(fadeDuration: TimeInterval = 1.2) {
        currentMusic = nil
        for deck in musicDecks { deck.fadeOut(duration: fadeDuration) }
        startFadeTimer()
    }

    func playAmbience(_ cue: SoundCue, fadeDuration: TimeInterval = 2) {
        guard cue != currentAmbience else { return }
        currentAmbience = cue
        crossfade(decks: ambienceDecks, to: cue, loops: true, fadeDuration: fadeDuration)
    }

    func stopAmbience(fadeDuration: TimeInterval = 1.2) {
        currentAmbience = nil
        for deck in ambienceDecks { deck.fadeOut(duration: fadeDuration) }
        startFadeTimer()
    }

    /// Lowers music (for the pause menu) without stopping it.
    func setMusicDucked(_ ducked: Bool) {
        guard ducked != musicDucked else { return }
        musicDucked = ducked
        refreshVolumes()
    }

    /// Re-applies volumes after the player changes settings.
    func refreshVolumes() {
        let duck: Float = musicDucked ? 0.35 : 1
        for deck in musicDecks {
            deck.channelGain = channelVolume(.music) * duck
        }
        for deck in ambienceDecks {
            deck.channelGain = channelVolume(.ambience)
        }
    }

    private func crossfade(decks: [StreamDeck], to cue: SoundCue, loops: Bool, fadeDuration: TimeInterval) {
        guard decks.count == 2 else { return }
        // The quieter deck takes the new track; the other fades away.
        let incoming = decks[0].level <= decks[1].level ? decks[0] : decks[1]
        let outgoing = incoming === decks[0] ? decks[1] : decks[0]
        outgoing.fadeOut(duration: fadeDuration)

        guard let name = cue.fileNames.first, let url = Self.url(forResource: name),
              let file = try? AVAudioFile(forReading: url) else {
            startFadeTimer()
            return
        }
        guard startEngineIfNeeded() else { return }
        incoming.start(file: file, loops: loops, cueGain: cue.gain, engine: engine)
        incoming.fadeIn(duration: fadeDuration)
        refreshVolumes()
        startFadeTimer()
    }

    /// Steps deck fades at display rate while any are in progress.
    private func startFadeTimer() {
        guard fadeTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.stepFades() }
        }
        RunLoop.main.add(timer, forMode: .common)
        fadeTimer = timer
    }

    private func stepFades() {
        let now = ProcessInfo.processInfo.systemUptime
        var active = false
        for deck in musicDecks + ambienceDecks {
            active = deck.stepFade(now: now) || active
        }
        if !active {
            fadeTimer?.invalidate()
            fadeTimer = nil
        }
    }

    // MARK: - Internals

    private func channelVolume(_ channel: AudioChannel) -> Float {
        let settings = volumes()
        switch channel {
        case .music: return Float(settings.effectiveMusicVolume)
        case .ambience, .effects, .interface: return Float(settings.effectiveEffectsVolume)
        }
    }

    private func buffer(named name: String) -> AVAudioPCMBuffer? {
        if let cached = buffers[name] { return cached }
        guard !missingFiles.contains(name) else { return nil }
        guard let url = Self.url(forResource: name), let file = try? AVAudioFile(forReading: url),
              let format = effectFormat, let converted = Self.decode(file, to: format) else {
            missingFiles.insert(name)
            return nil
        }
        buffers[name] = converted
        return converted
    }

    /// Reads a whole file and converts it to the effect voices' format, so
    /// every clip can play on any voice.
    private static func decode(_ file: AVAudioFile, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let source = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let raw = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: frames) else { return nil }
        do {
            try file.read(into: raw)
        } catch {
            return nil
        }
        if source.sampleRate == format.sampleRate, source.channelCount == format.channelCount,
           source.commonFormat == format.commonFormat {
            return raw
        }
        guard let converter = AVAudioConverter(from: source, to: format) else { return nil }
        let ratio = format.sampleRate / source.sampleRate
        let capacity = AVAudioFrameCount(Double(frames) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .endOfStream
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return raw
        }
        return status == .error ? nil : output
    }

    /// Bundle lookup across the formats the build may contain. Resources in
    /// a folder may be copied flat or keep their folder, so both are tried.
    static func url(forResource name: String) -> URL? {
        for ext in ["m4a", "caf", "wav", "mp3"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio") {
                return url
            }
        }
        return nil
    }

    private func configureEngine() {
        let output = engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = output.sampleRate > 0 ? output.sampleRate : 44_100
        // Effects are mono; the mixer places them in the centre. Any stereo
        // clip is folded down once at decode time.
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        effectFormat = format

        engine.attach(effectsMixer)
        engine.connect(effectsMixer, to: engine.mainMixerNode, format: format)
        for _ in 0..<voiceCount {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: effectsMixer, format: format)
            voices.append(voice)
        }

        musicDecks = [StreamDeck(engine: engine), StreamDeck(engine: engine)]
        ambienceDecks = [StreamDeck(engine: engine), StreamDeck(engine: engine)]

        engine.prepare()
        startEngineIfNeeded()
    }

    @discardableResult
    private func startEngineIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func observeSystemEvents() {
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                           queue: .main) { [weak self] notification in
            let ended = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .ended
            guard ended else { return }
            MainActor.assumeIsolated { self?.restart() }
        }
        // Route changes (headphones, AirPods) stop the engine and its nodes.
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                           queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restart() }
        }
    }

    private func restart() {
        try? AVAudioSession.sharedInstance().setActive(true)
        guard startEngineIfNeeded() else { return }
        for deck in musicDecks + ambienceDecks {
            deck.resume()
        }
    }

    private func configureSession() {
        // Ambient: respects the silent switch and mixes with the player's own
        // music, which is what people expect from a mobile game.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

/// One streaming player with its own fader, for music or ambience.
///
/// A looping track is kept two files deep in the player's queue: whenever
/// one copy finishes, another is appended, so the seam is sample-accurate.
@MainActor
private final class StreamDeck {
    private let player = AVAudioPlayerNode()
    private let fader = AVAudioMixerNode()
    private weak var engine: AVAudioEngine?
    private var connectedFormat: AVAudioFormat?
    private var file: AVAudioFile?
    private var loops = false
    /// Bumped on every start/stop so stale completion callbacks are ignored.
    private var generation = 0

    private var cueGain: Float = 1
    /// Player's channel volume (settings, ducking).
    var channelGain: Float = 1 {
        didSet { applyVolume() }
    }
    /// 0…1 fade position.
    private(set) var level: Float = 0
    private var fadeFrom: Float = 0
    private var fadeTo: Float = 0
    private var fadeStart: TimeInterval = 0
    private var fadeDuration: TimeInterval = 0
    private var stopWhenSilent = false

    init(engine: AVAudioEngine) {
        self.engine = engine
        engine.attach(player)
        engine.attach(fader)
        engine.connect(fader, to: engine.mainMixerNode, format: nil)
        fader.outputVolume = 0
    }

    func start(file: AVAudioFile, loops: Bool, cueGain: Float, engine: AVAudioEngine) {
        generation += 1
        player.stop()
        self.file = file
        self.loops = loops
        self.cueGain = cueGain
        stopWhenSilent = false

        let format = file.processingFormat
        if connectedFormat != format {
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: fader, format: format)
            connectedFormat = format
        }
        enqueue(generation: generation)
        if loops {
            enqueue(generation: generation)
        }
        player.play()
    }

    /// Restarts playback after the engine was stopped by the system.
    func resume() {
        guard file != nil, level > 0, !player.isPlaying else { return }
        player.play()
    }

    func fadeIn(duration: TimeInterval) {
        beginFade(to: 1, duration: duration)
    }

    func fadeOut(duration: TimeInterval) {
        guard level > 0 || fadeTo > 0 else { return }
        stopWhenSilent = true
        beginFade(to: 0, duration: duration)
    }

    /// Advances the fade; returns true while still fading.
    func stepFade(now: TimeInterval) -> Bool {
        guard fadeDuration > 0 else { return false }
        let t = min(1, (now - fadeStart) / fadeDuration)
        level = fadeFrom + (fadeTo - fadeFrom) * Float(t)
        applyVolume()
        guard t >= 1 else { return true }
        fadeDuration = 0
        if level <= 0, stopWhenSilent {
            generation += 1
            player.stop()
            file = nil
        }
        return false
    }

    private func beginFade(to target: Float, duration: TimeInterval) {
        fadeFrom = level
        fadeTo = target
        fadeStart = ProcessInfo.processInfo.systemUptime
        fadeDuration = max(duration, 0.01)
    }

    private func applyVolume() {
        fader.outputVolume = level * cueGain * channelGain
    }

    private func enqueue(generation scheduled: Int) {
        guard let file else { return }
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.generation == scheduled, self.loops else { return }
                    self.enqueue(generation: scheduled)
                }
            }
        }
    }
}
