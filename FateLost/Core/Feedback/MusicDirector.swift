import Foundation

/// Chooses what plays where, so screens ask for a mood rather than a file.
enum MusicDirector {
    static let menuTheme = SoundCue.musicMenu

    /// Each realm will get its own battle theme; all share the Ashen Wilds
    /// theme until they do.
    static func battleTheme(for realm: RealmID) -> SoundCue {
        .musicAshenWilds
    }

    static func ambience(for realm: RealmID) -> SoundCue {
        .ambienceAshenWilds
    }
}
