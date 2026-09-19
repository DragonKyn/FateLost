import Foundation

/// Bard: music as a weapon. Skalds sing warriors into legends, Dirges play
/// the enemy's funeral, Virtuosos make the horde dance to their tune.
enum BardSkills: SkillContent {
    static let archetype = ArchetypeID.bard

    static let definition = ArchetypeDefinition(
        id: .bard, name: "Bard", tagline: "Every battle has a rhythm. Yours is the only one that matters.",
        symbol: "music.note", color: RGBA(hex: 0x3AB0A0),
        paths: [
            PathDefinition(id: pathID("skald"), name: "Skald",
                           summary: "War chants, rhythm and ballads of heroes."),
            PathDefinition(id: pathID("dirge"), name: "Dirge",
                           summary: "Laments, dissonance and songs of ruin."),
            PathDefinition(id: pathID("virtuoso"), name: "Virtuoso",
                           summary: "Enthralling melodies and a horde that turns on itself."),
        ],
        resonance: [StatModifier(.areaSize, .increased, 0.008), StatModifier(.damage, .increased, 0.006)],
        resonanceText: "+0.8% area size and +0.6% damage per point"
    )

    // MARK: Core

    static let discordantChord = skill(
        "core.discordantChord", "Discordant Chord", tier: .one, ranks: 5, kind: .active, symbol: "waveform",
        text: "Strike a chord that shakes everything around you for {0%} power and hurls it back.",
        values: [rv(2, 0.45)],
        effects: [ability("discordantChord", "Discordant Chord", symbol: "waveform", cooldown: rv(8, -0.5),
                          nova(rv(3.2), dmg(2, 0.45, .arcane, [.spell, .area, .ability], knockback: 2), .sonic))],
        tags: [.spell, .area]
    )

    static let tempo = skill(
        "core.tempo", "Tempo", tier: .one, ranks: 5, kind: .passive, symbol: "metronome.fill",
        text: "+{0%} attack speed and +{1%} movement speed.",
        values: [rv(0.05, 0.05), rv(0.05, 0.05)],
        effects: [inc(.attackSpeed, 0.05), inc(.moveSpeed, 0.05)]
    )

    static let resoundingVoice = skill(
        "core.resoundingVoice", "Resounding Voice", tier: .one, ranks: 5, kind: .passive,
        symbol: "speaker.wave.3.fill",
        text: "+{0%} area size and +{1%} damage.",
        values: [rv(0.1, 0.1), rv(0.05, 0.05)],
        effects: [inc(.areaSize, 0.1), inc(.damage, 0.05)]
    )

    // MARK: Skald

    static let warChant = skill(
        "skald.warChant", "War Chant", path: "skald", tier: .two, ranks: 3, kind: .active, symbol: "music.mic",
        text: "Chant for 8 s: +{0%} attack speed and +{1%} damage.",
        values: [rv(0.3, 0.1), rv(0.15, 0.05)],
        effects: [ability("warChant", "War Chant", symbol: "music.mic", cooldown: rv(18, -1.5),
                          buff("warChant", [mod(.attackSpeed, .increased, 0.3, 0.1), mod(.damage, .increased, 0.15, 0.05)],
                               duration: 8))]
    )

    static let rhythm = skill(
        "skald.rhythm", "Rhythm", path: "skald", tier: .two, ranks: 3, kind: .proc, symbol: "metronome",
        text: "Every 4th attack builds rhythm: +{0%} damage for 4 s, stacking 5 times.",
        values: [rv(0.04, 0.02)],
        effects: [proc(.everyNthAttack(4), buff("rhythm", [mod(.damage, .increased, 0.04, 0.02)],
                                                duration: 4, stacks: 5))]
    )

    static let battleSaga = skill(
        "skald.battleSaga", "Battle Saga", path: "skald", tier: .three, ranks: 3, kind: .proc, symbol: "book.fill",
        text: "Using an ability grants +{0%} damage for 5 s.",
        values: [rv(0.12, 0.06)],
        effects: [proc(.abilityCast, buff("battleSaga", [mod(.damage, .increased, 0.12, 0.06)], duration: 5))],
        requires: ["skald.warChant", "skald.rhythm"]
    )

    static let warDrums = skill(
        "skald.warDrums", "War Drums", path: "skald", tier: .three, ranks: 3, kind: .aura, symbol: "drop.circle.fill",
        text: "Drums beat around you each second, knocking back and striking nearby enemies for {0%} power.",
        values: [rv(0.8, 0.3)],
        effects: [.aura(zone(rv(2.8), duration: 0, tick: 1, dmg(0.8, 0.3, .physical, [.area], knockback: 1),
                             follows: true, .sonic))],
        requires: ["skald.warChant", "skald.rhythm"]
    )

    static let balladOfTheUndying = skill(
        "skald.balladOfTheUndying", "Ballad of the Undying", path: "skald", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "music.quarternote.3",
        text: "For {0} s: +40% damage, +30% attack speed and +20 health per second.",
        values: [rv(10, 2)],
        effects: [ability("balladOfTheUndying", "Ballad of the Undying", symbol: "music.quarternote.3",
                          cooldown: rv(60, -5), ultimate: true,
                          buff("ballad", [mod(.damage, .increased, 0.4), mod(.attackSpeed, .increased, 0.3),
                                          mod(.healthRegen, .flat, 20)], duration: rv(10, 2)))],
        requires: ["skald.battleSaga", "skald.warDrums"]
    )

    static let livingLegend = skill(
        "skald.livingLegend", "Living Legend", path: "skald", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "crown.fill",
        text: "Everything you set in motion lasts 50% longer, and you deal 15% more damage.",
        effects: [more(.effectDuration, 0.5, 0), more(.damage, 0.15, 0)],
        requires: ["skald.balladOfTheUndying"]
    )

    // MARK: Dirge

    static let lament = skill(
        "dirge.lament", "Lament", path: "dirge", tier: .two, ranks: 3, kind: .passive, symbol: "music.note",
        text: "Hits have a {0%} chance to weaken for 4 s: the enemy deals 20% less damage.",
        values: [rv(0.15, 0.08)],
        effects: [.inflict(.any, status(.weaken, chance: rv(0.15, 0.08), potency: 0.2, duration: 4))]
    )

    static let dissonance = skill(
        "dirge.dissonance", "Dissonance", path: "dirge", tier: .two, ranks: 3, kind: .active,
        symbol: "waveform.path.ecg",
        text: "A jarring wave: {0%} power around you, and enemies take 25% more damage for 6 s.",
        values: [rv(1.5, 0.4)],
        effects: [ability("dissonance", "Dissonance", symbol: "waveform.path.ecg", cooldown: rv(12, -1),
                          nova(rv(3.5), dmg(1.5, 0.4, .arcane, [.spell, .area, .ability], knockback: 0.6),
                               status: status(.shock, potency: 0.25, duration: 6), .sonic))]
    )

    static let requiem = skill(
        "dirge.requiem", "Requiem", path: "dirge", tier: .three, ranks: 3, kind: .passive, symbol: "music.note.list",
        text: "+{0%} damage against weakened enemies and against shocked ones.",
        values: [rv(0.15, 0.08)],
        effects: [.damageAgainst(.status(.weaken), rv(0.15, 0.08)), .damageAgainst(.status(.shock), rv(0.15, 0.08))],
        requires: ["dirge.lament", "dirge.dissonance"]
    )

    static let echoes = skill(
        "dirge.echoes", "Echoes", path: "dirge", tier: .three, ranks: 3, kind: .passive,
        symbol: "dot.radiowaves.left.and.right",
        text: "Abilities have a {0%} chance to sound twice.",
        values: [rv(0.08, 0.05)],
        effects: [flat(.spellEcho, 0.08, 0.05)],
        requires: ["dirge.lament", "dirge.dissonance"]
    )

    static let dirgeOfRuin = skill(
        "dirge.dirgeOfRuin", "Dirge of Ruin", path: "dirge", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "speaker.wave.3.fill",
        text: "Play a song of ruin for {0} s: {1%} power twice a second to everything around you, weakening and shaking it.",
        values: [rv(6, 1), rv(1.4, 0.4)],
        effects: [ability("dirgeOfRuin", "Dirge of Ruin", symbol: "speaker.wave.3.fill", cooldown: rv(55, -4),
                          ultimate: true,
                          .zone(zone(rv(4), duration: rv(6, 1), tick: 0.5,
                                     dmg(1.4, 0.4, .arcane, [.spell, .area, .ability], knockback: 0.5),
                                     status: status(.weaken, potency: 0.3, duration: 1.5), follows: true, .sonic)))],
        requires: ["dirge.requiem", "dirge.echoes"]
    )

    static let finalVerse = skill(
        "dirge.finalVerse", "Final Verse", path: "dirge", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "crown.fill",
        text: "Weakened enemies burst into a shriek of sound when they die, 200% power around them.",
        effects: [proc(.kill(killedBy: nil), target: .status(.weaken),
                       nova(rv(2), dmg(2, 0, .arcane, [.spell, .area], knockback: 1), at: .origin, .sonic))],
        requires: ["dirge.dirgeOfRuin"]
    )

    // MARK: Virtuoso

    static let enthrallingMelody = skill(
        "virtuoso.enthrallingMelody", "Enthralling Melody", path: "virtuoso", tier: .two, ranks: 3, kind: .active,
        symbol: "music.note",
        text: "Enemies around you fall under your spell for {0} s, attacking each other.",
        values: [rv(3, 0.5)],
        effects: [ability("enthrallingMelody", "Enthralling Melody", symbol: "music.note", cooldown: rv(14, -1),
                          .afflict(status(.confuse, duration: rv(3, 0.5)), radius: 3.5))]
    )

    static let crescendo = skill(
        "virtuoso.crescendo", "Crescendo", path: "virtuoso", tier: .two, ranks: 3, kind: .passive,
        symbol: "chart.line.uptrend.xyaxis",
        text: "+{0%} critical chance and +{1%} critical damage.",
        values: [rv(0.04, 0.03), rv(0.12, 0.1)],
        effects: [flat(.critChance, 0.04, 0.03), flat(.critDamage, 0.12, 0.1)]
    )

    static let puppeteer = skill(
        "virtuoso.puppeteer", "Puppeteer", path: "virtuoso", tier: .three, ranks: 3, kind: .passive,
        symbol: "theatermasks.fill",
        text: "+{0%} damage against confused enemies, and everything you inflict lasts {1%} longer.",
        values: [rv(0.25, 0.1), rv(0.1, 0.05)],
        effects: [.damageAgainst(.status(.confuse), rv(0.25, 0.1)), inc(.effectDuration, 0.1, 0.05)],
        requires: ["virtuoso.enthrallingMelody", "virtuoso.crescendo"]
    )

    static let ringingNotes = skill(
        "virtuoso.ringingNotes", "Ringing Notes", path: "virtuoso", tier: .three, ranks: 3, kind: .proc,
        symbol: "bell.fill",
        text: "Hits have a {0%} chance to ring out, leaping to 3 enemies for {1%} power.",
        values: [rv(0.08, 0.04), rv(1.2, 0.35)],
        effects: [proc(.hit(tags: [], type: nil), chance: rv(0.08, 0.04), cooldown: 0.2,
                       .chain(ChainSpec(jumps: 3, damage: dmg(1.2, 0.35, .arcane, [.spell]), visual: .sonic)))],
        requires: ["virtuoso.enthrallingMelody", "virtuoso.crescendo"]
    )

    static let grandMasquerade = skill(
        "virtuoso.grandMasquerade", "Grand Masquerade", path: "virtuoso", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "theatermasks.circle.fill",
        text: "Every enemy nearby joins the dance for {0} s, turning on its own. You gain a barrier.",
        values: [rv(4, 1)],
        effects: [ability("grandMasquerade", "Grand Masquerade", symbol: "theatermasks.circle.fill",
                          cooldown: rv(60, -5), ultimate: true,
                          .all([.afflict(status(.confuse, duration: rv(4, 1)), radius: 6.5), .barrier(0.2)]))],
        requires: ["virtuoso.puppeteer", "virtuoso.ringingNotes"]
    )

    static let maestro = skill(
        "virtuoso.maestro", "Maestro", path: "virtuoso", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "crown.fill",
        text: "Every 6 s you play a free tune: a Discordant Chord, an Enthralling Melody or a War Chant.",
        effects: [proc(.interval(6), .random([
            nova(rv(3.2), dmg(2.5, 0, .arcane, [.spell, .area], knockback: 2), .sonic),
            .afflict(status(.confuse, duration: 2.5), radius: 3.5),
            buff("maestroChant", [mod(.attackSpeed, .increased, 0.3), mod(.damage, .increased, 0.15)], duration: 5),
        ]))],
        requires: ["virtuoso.grandMasquerade"]
    )

    static let skills: [SkillDefinition] = [
        discordantChord, tempo, resoundingVoice,
        warChant, rhythm, battleSaga, warDrums, balladOfTheUndying, livingLegend,
        lament, dissonance, requiem, echoes, dirgeOfRuin, finalVerse,
        enthrallingMelody, crescendo, puppeteer, ringingNotes, grandMasquerade, maestro,
    ]
}
