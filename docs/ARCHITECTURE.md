# Fate Lost architecture

This file records the decisions that shape the codebase and why they were
made. Update it whenever one of them changes.

## 1. Simulation and presentation are separate layers

```
SwiftUI (UI/)            menus, HUD text, pause, settings
   │  reads GameSession, calls pause/resume
SpriteKit (Scenes/)      GameScene coordinator + focused renderers
   │  feeds PlayerIntent, reads state
Simulation (Game/)       GameSimulation, systems, world topology. No SpriteKit
   │
Core/ + Data/            math, persistence, settings, content tables
```

- `GameSimulation` owns the game state and advances it in fixed steps. It
  imports only Foundation and CoreGraphics, so every rule can be unit-tested
  without a scene.
- `GameScene` coordinates and holds no rules. Each frame it converts touches
  into a `PlayerIntent`, steps the simulation, passes the step's
  `CombatEvent`s to `CombatFeedback`, and hands the resulting state to
  renderers (`WrappingGroundRenderer`, `DecorationRenderer`, `EnemyRenderer`,
  `ProjectileRenderer`, `EffectsRenderer`, `PlayerView`, `CameraController`,
  `AtmosphereRenderer`, `GameHUDNode`).
- **Where new code goes:** gameplay rules become systems called from
  `GameSimulation.step`. Visuals become renderers called from
  `GameScene.render`. Neither goes directly into `GameScene`.

## 2. Fixed timestep

`FixedTimestep` turns variable frame times into whole 1/60 s simulation
steps, capped at 5 per frame so a hitch can't cause a catch-up spiral.
Movement, cooldowns and (later) combat stay deterministic and frame-rate
independent. The developer game-speed control scales simulated time only.

## 3. The wrapping world

The arena is a torus: leaving one edge brings you back on the opposite edge.

- **Simulation** stores every position wrapped into the arena rectangle.
  Anything comparing two positions must use `ToroidalWorld.delta(from:to:)` or
  `distance`, which take the short way across the seam.
- **Rendering** uses `WrappedRenderFrame`. It tracks an *unwrapped* focus that
  accumulates the player's actual motion, and draws everything else at
  `focus + shortestDelta(focus, object)`. Each object therefore appears at its
  copy nearest the player, the camera follows a continuous path, and there is
  never a teleport. After a long walk the unwrapped focus is pulled back by a
  whole number of arena sizes ("rebased"), and the camera moves by exactly the
  same amount so the shift can't be seen. This keeps floating-point precision.
- **Ground** is one isometric `SKTileMapNode` covering the full arena. SpriteKit
  culls and batches it, so it costs far less than hundreds of tile sprites. The
  camera never sees more than half the arena, so four copies arranged 2×2 always
  cover the view, and they leapfrog as the player moves. SpriteKit doesn't
  document its isometric row/column directions, so the renderer measures them
  at startup instead of assuming them.
- **Content generation** is periodic by construction. Terrain noise
  (`PeriodicValueNoise`) repeats exactly over the arena, and road meanders use
  a whole number of sine cycles per arena length, so no seam shows. Tests check
  both.

## 4. Isometric projection

`IsometricProjection` is a linear 2:1 mapping. World +x points to the lower
right of the screen, world +y to the lower left, and one world unit is one
tile. Joystick input is converted from screen direction to world direction,
so pushing right always moves right on screen. Depth sorting uses screen y
inside fixed z bands (`DepthSorting.Band`).

## 5. Built for hundreds of entities

- `ToroidalSpatialGrid` handles broad-phase "what's near here" queries that
  wrap across the seam. Decorations use it statically. Combat rebuilds an
  enemy grid twice per tick (before crowding and before hits); `removeAll`
  keeps bucket capacity, so a rebuild allocates nothing.
- `EnemyStore` keeps enemies as parallel arrays (struct of arrays). Removal
  swaps the last enemy into the gap, so it is O(1); renderers key their
  views by a stable enemy id, not by index.
- Enemy separation, the costly part of crowd AI, is recomputed for half the
  enemies each tick and cached in between (`EnemyAITuning.separationGroups`).
  Neighbour checks stop after 12, so extreme crowds cost a bounded amount.
- `NodePool` recycles nodes: decorations per sprite, enemies, projectiles
  and every effect kind. Effect kinds have ceilings (damage numbers, stains,
  bodies) so a screen-filling brawl costs a bounded amount.
- `DecorationRenderer` only re-queries when the camera crosses a grid cell,
  so most frames do no decoration work.
- `SpriteCatalog` packs every sprite into one runtime texture atlas so
  SpriteKit can batch draws.

The developer panel can spawn 500 goblins, and the performance overlay shows
simulation milliseconds per frame, so these limits can be checked on device.

## 6. Data-driven content

Balance numbers live in typed Swift tables, never in logic:

- `Data/RealmCatalog.swift`: all 10 realms with conquest wave, Legacy
  multiplier and arena definition
- `Data/ArenaThemes.swift`: ground palettes, roads, landmark clusters,
  decoration scatter and atmosphere for each realm
- `Data/StarterWeapons.swift`: weapon definitions (damage, speed, range,
  damage type, tags, delivery, targeting, rarity, sprite)
- `Data/EnemyCatalog.swift`: enemy definitions (health, speed, size, strike
  damage, reach, windup, cooldown, knockback resistance) and realm rosters
- `Game/Config/GameTuning.swift`: feel tuning for movement, combat, spawning,
  enemy AI, camera, controls and rendering

These are plain value types, so moving them to JSON later only means adding
decoding.

## 7. Art is swappable

Gameplay refers to visuals only through a `SpriteID`. `SpriteCatalog` resolves
an ID to an asset-catalogue image with the same name if one exists, and falls
back to procedurally drawn placeholder art (`PlaceholderArt`) otherwise.
Dropping in final art means adding assets with the right names. No code
changes.

## 8. Input

- The joystick floats: it appears wherever the thumb lands in the left half of
  the screen. When the thumb goes past the rim the base follows it, so
  reversing direction never needs a long drag back. The logic is
  `JoystickModel`, which is pure and tested. The visuals are
  `VirtualJoystickNode`.
- Touch-critical controls (joystick, ability sockets) are SpriteKit nodes for
  zero-latency multi-touch. Informational HUD (health, level, wave, time) is
  SwiftUI over the game view. The scene publishes `GameplayHUDState` only
  when a value changes.
- `HUDLayout` places controls from the screen size and safe-area insets, and
  scales them up on larger screens within a cap.

## 9. Services and state

- `AppServices` is created once at launch and passed down through the SwiftUI
  environment and scene initialisers. It holds settings, developer options,
  haptics, audio and realm progress. There are no global singletons.
- `AppRouter` swaps between full-screen modes: launch, menu, realm select,
  weapon select and gameplay. Gameplay is a set of modes rather than a
  drill-down hierarchy, which is why it doesn't use a `NavigationStack`.
- `GameSession` owns one run's scene and is the only bridge between SwiftUI
  and SpriteKit.

## 10. Persistence

`VersionedFileStore` writes JSON inside a `SaveEnvelope` that records the
schema version.

- Writes are atomic.
- Older versions go through a migration closure.
- Corrupt files, and files from a newer build, are renamed aside rather than
  deleted or overwritten, and the game continues with defaults.
- `GameSettings` decoding tolerates missing keys, so adding a setting never
  invalidates an existing file.

The Legacy profile (Phase 6) will use the same store.

## 11. Developer tooling

Developer tools are compiled in under `FATELOST_DEVTOOLS`. That flag is set in
Debug and in the CI sideload build (Release optimisation plus tools), so
performance measured on device is representative. A store build omits the
flag. `DeveloperOptions` exists in every build so gameplay code needs no
`#if`; only the UI and overlays that change it are conditional.

## 12. Concurrency

The project uses the Swift 5 language mode. Everything that touches UIKit or
SpriteKit runs on the main actor. SpriteKit nodes inherit main-actor isolation
through `UIResponder`, and renderers and services are annotated explicitly.
Simulation types are value types with no isolation, so they can later move
off the main thread if profiling shows a need.

## 13. Combat

A simulation step runs in a fixed order: the player moves, enemies spawn,
enemies chase, crowd and strike, the weapon attacks, projectiles fly, and
the dead are removed. Each system is a small value type that takes the
shared `CombatState` (enemies, projectiles, grid, random stream, stats,
events) as one `inout` argument.

- **Events, not callbacks.** Systems append `CombatEvent`s (swing, hit,
  kill, strike telegraph, burst, player hit, defeat). The scene drains them
  once per frame and `CombatFeedback` turns them into flashes, sparks,
  damage numbers, bodies, shake, hit-stop, sound and haptics. Game rules
  never depend on presentation, and feel can be tuned without touching
  rules. Events are presented *before* renderers update, so a killed
  enemy's view still exists to spawn its falling body from.
- **Readable danger.** Enemy strikes have a windup (the goblin crouches and
  reddens). Stepping out of reach during it dodges the blow. After a hit the
  player is briefly immune, which stops a crowd landing every blow in the same
  instant.
- **Responsive weapons.** A weapon with nothing in reach stays ready, so it
  fires the moment an enemy steps in rather than on a fixed beat. Melee
  swings hit everything in their arc, plus anything standing on top of the
  player. Targeting (`Targeting.nearest`, `.densestCluster`) goes through
  the spatial grid.
- **Determinism.** Combat randomness (crits, damage variance, spawn
  positions) uses its own seeded stream derived from the run seed, so a
  seed plus a sequence of intents always gives the same fight. Tests rely on
  this.
- **Spawning** happens on a ring just outside the screen's farthest corner.
  The scene measures that from the real screen size. Some spawns are biased
  ahead of a moving player. Enemies left far behind are moved back to the
  ring rather than trailing uselessly.

## 14. Audio

`AudioManager` runs everything through one `AVAudioEngine`.

- **Effects** are decoded into memory once and played on 16 round-robin
  voices, so a play costs no allocation and the oldest sound is the one cut
  when all voices are busy. Each `SoundCue` can have several interchangeable
  recordings and a minimum re-trigger interval, so forty simultaneous hits
  produce one clean impact, not a wall of noise.
- **Music and ambience** stream from disk on two decks each, and crossfade.
  A looping track keeps two copies queued on its player node, which makes
  the loop sample-accurate even for AAC. `AVAudioPlayer` leaves a gap
  there. `MusicDirector` picks tracks by context (menu, realm, defeat).
- **Content** is synthesised by `tools/audio/render_audio.py`, which is
  deterministic and needs only numpy. CI renders it before each build and
  encodes music as AAC. The rendered files are not committed. Loops are
  rendered with their reverb tail folded back onto the start, so the seam
  is inaudible.
- The session category is `.ambient`: the game respects the silent switch
  and mixes with the player's own music.

## 15. Skills and progression

Skills are **data, not code**. Every one of the 231 skills (`Data/Skills/`)
is a `SkillDefinition` whose `effects` are drawn from a small shared
vocabulary (`Game/Skills/Model/`):

- `SkillEffect`: stat modifiers (always, or while a `PlayerCondition`
  holds), bonuses against enemies matching a `TargetCondition`, statuses on
  hit, triggered procs, weapon modifiers, abilities, companions, auras,
  refusing death, permanent forms.
- `EffectAction`: what abilities and procs *do*: novas, cones, chains,
  volleys, strikes from above, zones, summons, buffs, barriers, heals,
  dashes, stealth, forms, afflictions, pulls, cooldown refunds, and random
  or combined actions.

Numbers are `RankValue`s (a value at rank 1 plus a step per rank), resolved
once when a build is compiled. `CompiledBuild.compile` flattens an
allocation into arrays the step reads; nothing walks the tree during play.
`ActionExecutor` is the single interpreter for every action, and runs queued
actions between systems so no effect ever runs inside another system's
enemy loop. All damage resolves in `CombatState.strike(_:with:)`.

**Tree rules** (`SkillTreeRules`, configurable): tiers open at 0/3/7/12/20
points spent in the archetype's lower tiers; later path skills need one
earlier skill of the same path; each archetype allows one capstone. The
tree screen edits a draft that is validated by the same rules and committed
at once.

**Avoiding forced metas.** The design choices that keep early picks free:

- Weapon and skill damage both grow with character level at the same rate
  (`SkillPower`), so nobody needs to buy baseline damage to keep up, and a
  skill learned at level 2 is still good at level 30.
- Rank 1 carries each skill's mechanic; further ranks add steadily, so
  breadth and depth are both viable.
- Damage increases stack additively and utility stats are capped (dodge,
  cooldown reduction, life steal, crit), giving natural diminishing
  returns.
- Every point grants its archetype's small *resonance* bonus, so no point
  is filler.
- Skills are written weapon-agnostically (extra projectiles become extra
  strikes for melee weapons, cleave becomes a burst for projectiles).
- Capstones change how you play rather than multiplying numbers.

**Experience.** Enemies drop `ExperienceOrb`s, drawn in within the pickup
radius. Levels come quickly at first (`ProgressionTuning`); each grants a
point, heals a little, and releases a burst that clears space before the
tree opens. Enemies gain health and damage with time.
