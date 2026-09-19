# Fate Lost

*You begin as nobody. Every run, you decide what you become.*

Fate Lost is a dark-fantasy isometric survival roguelite for iPhone and iPad.
Every run starts as a classless Level 1 Adventurer: your class comes only from
where you spend skill points, and you can mix archetypes freely. Death takes
the build. Your Legacy stays.

Native Swift: SpriteKit for gameplay, SwiftUI for menus. Landscape only.
iOS 17 or later.

## Status

**Phase 1: Playground.** You can launch the game, go through the menus, pick
The Ashen Wilds and a starter weapon, and walk around a generated isometric
arena that wraps seamlessly at every edge, using a floating touch joystick.

| Phase | Scope | State |
|---|---|---|
| 1 Playground | App shell, menus, isometric wrapping world, joystick, camera | **Done** |
| 2 Combat | Enemies, spawning, health, auto-attacks, Sword | Next |
| 3 Roguelite loop | XP, levels, skill points, skills, death, summary | |
| 4 Variety | Bow, Staff, more enemies, pickups, shrines, loot | |
| 5 Waves | WaveManager, elites, milestones, the Grave Warden | |
| 6 Legacy | Legacy XP and upgrades, save/load, realm unlocks | |
| 7 Multiclass | Hybrid prerequisites, Spellblade | |

## Building

The project is authored on Windows, so builds happen on a Mac or in CI.

- **Xcode (Mac):** open `FateLost.xcodeproj`, select the `FateLost` scheme, and run.
  You need Xcode 16 or later, because the project uses folder-synchronised groups.
  New `.swift` files under `FateLost/` or `FateLostTests/` are picked up automatically.
- **CI:** every push to `main` runs `.github/workflows/ios-build.yml`. It:
  1. builds an unsigned Release `.ipa` with developer tools included (artifact `FateLost-unsigned-ipa`),
  2. runs the unit tests on an iPhone simulator, and
  3. commits `xcodebuild.log`, `test.log` and `build-report.txt` to the `ci-logs` branch.
- **On device:** install the IPA with Sideloadly, which re-signs it with your Apple ID.

## Developer tools

Builds compiled with `FATELOST_DEVTOOLS` (Debug, plus the CI sideload IPA) show a
wrench button on the main menu and in the gameplay HUD. The panel currently has:

- a performance overlay (FPS, node count, entity counts, wave, level, position),
- a wrap-seam visualiser that draws the arena boundaries so you can confirm they're invisible,
- a game speed control (0.25× to 4×),
- a camera shake test,
- an "unlock all realms" toggle.

## Layout

```
FateLost/
  App/          entry point, router, service container
  Core/         math, time, persistence, settings, audio, haptics (no SpriteKit)
  Data/         content tables: realms, arena themes, starter weapons
  Game/         pure simulation: world topology, arena generation, player,
                movement, input models, tuning. Unit-testable, no SpriteKit
  Rendering/    sprite catalogue, placeholder art, node pooling
  Scenes/       SpriteKit: GameScene coordinator, renderers, camera, HUD nodes
  UI/           SwiftUI theme, components, screens
  Debug/        developer options, overlays, panel
  Resources/    asset catalogue
FateLostTests/  XCTest unit tests
docs/           architecture notes
```

For the design reasoning, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
