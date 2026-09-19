import AVFoundation

/// Mixer channel a sound plays on; each has its own volume setting.
enum AudioChannel {
    case music
    case ambience
    case effects
    case interface
}

/// A named sound. Files are looked up in the bundle by `fileName`; a cue with
/// no file yet is silently skipped, so gameplay can trigger sounds before the
/// audio exists.
struct SoundCue: Hashable {
    let fileName: String
    let channel: AudioChannel
    /// Relative gain before channel and master volume.
    let gain: Float

    init(_ fileName: String, channel: AudioChannel, gain: Float = 1) {
        self.fileName = fileName
        self.channel = channel
        self.gain = gain
    }
}

extension SoundCue {
    static let uiConfirm = SoundCue("ui_confirm", channel: .interface)
    static let uiBack = SoundCue("ui_back", channel: .interface)
    static let ambienceAshenWilds = SoundCue("amb_ashen_wilds", channel: .ambience, gain: 0.6)
    static let musicMenu = SoundCue("mus_menu", channel: .music)
}

/// Plays music, ambience and effects at the player's chosen volumes.
///
/// Effects use a small pool of preloaded players per cue so rapid repeats
/// (hundreds of hits a second, eventually) overlap instead of cutting each
/// other off. Looping music and ambience each get one dedicated player.
@MainActor
final class AudioManager {
    private let volumes: () -> GameSettings
    private var effectPools: [SoundCue: [AVAudioPlayer]] = [:]
    private var missingCues: Set<String> = []
    private var musicPlayer: AVAudioPlayer?
    private var ambiencePlayer: AVAudioPlayer?
    private let voicesPerEffect = 4

    init(volumes: @escaping () -> GameSettings) {
        self.volumes = volumes
        configureSession()
    }

    func play(_ cue: SoundCue) {
        guard let player = availablePlayer(for: cue) else { return }
        player.volume = cue.gain * channelVolume(cue.channel)
        player.currentTime = 0
        player.play()
    }

    func playLoop(_ cue: SoundCue) {
        guard let player = makePlayer(for: cue) else { return }
        player.numberOfLoops = -1
        player.volume = cue.gain * channelVolume(cue.channel)
        player.play()
        switch cue.channel {
        case .music:
            musicPlayer?.stop()
            musicPlayer = player
        default:
            ambiencePlayer?.stop()
            ambiencePlayer = player
        }
    }

    func stopLoops(fadeDuration: TimeInterval = 0.6) {
        musicPlayer?.setVolume(0, fadeDuration: fadeDuration)
        ambiencePlayer?.setVolume(0, fadeDuration: fadeDuration)
    }

    /// Re-applies volumes after the player changes settings.
    func refreshVolumes() {
        musicPlayer?.volume = channelVolume(.music)
        ambiencePlayer?.volume = channelVolume(.ambience)
    }

    private func channelVolume(_ channel: AudioChannel) -> Float {
        let settings = volumes()
        switch channel {
        case .music: return Float(settings.effectiveMusicVolume)
        case .ambience, .effects, .interface: return Float(settings.effectiveEffectsVolume)
        }
    }

    private func availablePlayer(for cue: SoundCue) -> AVAudioPlayer? {
        if effectPools[cue] == nil {
            let voices = (0..<voicesPerEffect).compactMap { _ in makePlayer(for: cue) }
            effectPools[cue] = voices
        }
        guard let pool = effectPools[cue], !pool.isEmpty else { return nil }
        return pool.first { !$0.isPlaying } ?? pool.first
    }

    private func makePlayer(for cue: SoundCue) -> AVAudioPlayer? {
        guard !missingCues.contains(cue.fileName) else { return nil }
        let url = ["caf", "wav", "m4a", "mp3"].lazy
            .compactMap { Bundle.main.url(forResource: cue.fileName, withExtension: $0) }
            .first
        guard let url, let player = try? AVAudioPlayer(contentsOf: url) else {
            missingCues.insert(cue.fileName)
            return nil
        }
        player.prepareToPlay()
        return player
    }

    private func configureSession() {
        // Ambient: respects the silent switch and mixes with the player's own
        // music, which is what people expect from a mobile game.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
