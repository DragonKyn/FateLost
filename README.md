# Fate Lost

*Forge Your Fate.*

Fate Lost is a dark-fantasy isometric survival roguelite for iPhone and iPad.
Every run starts as a classless Level 1 Adventurer: your class comes only from
where you spend skill points, and you can mix archetypes freely. Death takes
the build. Your Legacy stays.

Native Swift: SpriteKit for gameplay, SwiftUI for menus. Landscape only.
iOS 17 or later.

## Status

**Phase 3: The roguelite loop.** Slain enemies leave embers of experience;
gather them to level up. Every level releases a burst of fate energy that
hurls the horde back, and grants a skill point to spend in a skill tree of
231 skills across eleven archetypes (Warrior, Rogue, Ranger, Wizard,
Sorcerer, Warlock, Cleric, Paladin, Druid, Monk, Bard), each with a shared
core and three subclass paths ending in a capstone. Abilities go on the
four HUD buttons; companions, auras, forms and triggered effects work on
their own. The goblin warband now fields grunts, skulkers, spearmen, brutes
and sappers.

Phase 2 brought the combat: goblins pour in from beyond the edge of the screen in
ever-growing numbers, chase you across the wrapping arena and telegraph their
strikes. Your weapon attacks automatically: the Sword sweeps an arc, the Bow
looses arrows, the Staff bursts arcane bolts on the densest cluster. Hits
flash, knock back and throw damage numbers; bodies fall; the camera shakes
and the phone buzzes when you're struck. When your health runs out, your fate
is sealed and a summary offers another run. Original music and sound effects
play throughout.

| Phase | Scope | State |
|---|---|---|
| 1 Playground | App shell, menus, isometric wrapping world, joystick, camera | **Done** |
| 2 Combat | Enemies, spawning, health, auto-attacks, Sword; music and sound | **Done** |
| 3 Roguelite loop | XP, levels, skill points, the full skill tree, abilities, summary | **Done** |
| 4 Variety | Summons that can be lost, 33 creatures across 8 families, strains | **Done** |
| 5 Waves | The wave clock, ten champions, realm conquest | **Done** |
| 6 Legacy | 500 permanent upgrades, statistics, save/load, realm unlocks | **Done** |
| 7 Multiclass | Eight orders, the Armoury and weapon mastery | **Done** |
| 8 Spoils | Relics, chests, shrines, weapon finds and the codex | **Done** |
| 9 Fate | A customisable hero (five builds, eleven cloaks, ten heads, emblems, metalwork and wings) with earned looks, fairer bosses, a locked developer mode | **Done** |
| 10 Together | Two to four heroes, one horde: a Cloudflare party service, a persistent lobby, host-authoritative play, revive markers, shared blessings | **Built, unproven on devices** |

## Multiplayer

Fate Lost plays two to four heroes together. One phone hosts and simulates; the others watch and ask. A
Cloudflare Worker with one Durable Object per party keeps the lobby (room code, optional password, ready
states, host, run lifecycle) and relays gameplay. A party outlives its runs: after a run everyone returns to
the same lobby. There is no public lobby list.

* Player guide: Main menu → **Multiplayer** → Host Game or Join Game.
* How it works: [docs/MULTIPLAYER_ARCHITECTURE.md](docs/MULTIPLAYER_ARCHITECTURE.md), the wire format in
  [docs/MULTIPLAYER_PROTOCOL.md](docs/MULTIPLAYER_PROTOCOL.md), every skill's party behaviour in
  [docs/MULTIPLAYER_SKILL_AUDIT.md](docs/MULTIPLAYER_SKILL_AUDIT.md), deployment and rollback in
  [docs/MULTIPLAYER_RUNBOOK.md](docs/MULTIPLAYER_RUNBOOK.md), and how other players' movement is drawn smoothly in
  [docs/MULTIPLAYER_MOVEMENT.md](docs/MULTIPLAYER_MOVEMENT.md).
* The service lives in `worker/` (TypeScript, tested against a local Worker and a deployed staging Worker).
  Cloudflare credentials are never in the app or the repository.

## Building

The project is authored on Windows, so builds happen on a Mac or in CI.

- **Xcode (Mac):** open `FateLost.xcodeproj`, select the `FateLost` scheme, and run.
  You need Xcode 16 or later, because the project uses folder-synchronised groups.
  New `.swift` files under `FateLost/` or `FateLostTests/` are picked up automatically.
- **Audio:** run `python3 tools/audio/render_audio.py` once (needs numpy) before
  building in Xcode. It writes the game's music and effects into
  `FateLost/Resources/Audio/`, which is not committed. Without it the game runs silently.
- **CI:** every push to `main` runs `.github/workflows/ios-build.yml`. It:
  1. renders the audio and converts the music to AAC,
  2. builds an unsigned Release `.ipa` with developer tools included (artifact `FateLost-unsigned-ipa`),
  3. runs the unit tests on an iPhone simulator, and
  4. commits `xcodebuild.log`, `test.log`, `audio-render.log` and `build-report.txt` to the `ci-logs` branch.
- **On device:** install the IPA with Sideloadly, which re-signs it with your Apple ID.

## Developer tools

Builds compiled with `FATELOST_DEVTOOLS` (Debug, plus the CI sideload IPA) can
show a wrench button on the main menu and in the gameplay HUD, but only after
the developer code has been entered under Settings, Developer. Locking it again
switches every cheat off. The panel currently has:

- a performance overlay (FPS, simulation time per frame, node/enemy/projectile/effect counts, spawn rate),
- hitbox display and a wrap-seam visualiser,
- god mode, restore health, kill all enemies, and a toggle for natural spawning,
- stress spawns of 10, 100, 250 or 500 goblins,
- instant levels (1, 5 or 20) and a skill point refund,
- a game speed control (0.25× to 4×) and a camera shake test,
- an "unlock all realms" toggle.

## Music and sound

Every sound in Fate Lost is original, synthesised by
[`tools/audio/render_audio.py`](tools/audio/render_audio.py) from oscillators,
plucked-string models, FM bells, filtered noise and convolution reverb. No
samples, loops or third-party recordings are used, so there is nothing to
license. The score shares one leitmotif, *Fate* (D minor: a rising fifth
falling back by step):

- **Fate Lost** (menu): solo cello, then choir, over harp and a low drone.
- **The Ashen Wilds** (battle): taiko and driving low strings, the motif on horns and then choir.
- **Fate Sealed** (defeat): a falling chord and the motif on a lone music box.

Music loops are sample-accurate. To replace any sound with a recording, drop a
file with the same name (`.m4a`, `.caf` or `.wav`) into the app bundle.

## Layout

```
FateLost/
  App/          entry point, router, service container
  Core/         math, time, persistence, settings, audio, haptics (no SpriteKit)
  Data/         content tables: realms, arena themes, starter weapons, enemies
  Game/         pure simulation: world topology, arena generation, player,
                enemies, combat systems, input models, tuning. Unit-testable,
                no SpriteKit
  Rendering/    sprite catalogue, placeholder art, node pooling
  Scenes/       SpriteKit: GameScene coordinator, renderers, camera, HUD nodes
  UI/           SwiftUI theme, components, screens
  Debug/        developer options, overlays, panel
  Resources/    asset catalogue
FateLostTests/  XCTest unit tests
tools/audio/    the music and sound-effect synthesiser
tools/art/      the sketchbook that generates creature, bestiary, prop, weapon, loot and hero art
docs/           architecture notes
```

For the design reasoning, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
