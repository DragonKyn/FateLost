# Champions, rifts, night hunters and passive healing

## The rule

Nothing a champion does is unavoidable. Every move is either **marked ground** (drawn on the floor from the moment it
exists, filling as it counts down, hurting only on landing) or **shots slow enough to weave through**. A hero who
reads the mark and steps out takes nothing.

## How it works

* `Hazard` (`Game/Combat/Hazard.swift`): a marked area of the floor, a **circle**, a **cone** or a **lane**, with a
  warning time. It hurts every hero still inside it when the warning ends and glows for 0.3 s after. Some also *linger*
  (a burning pool, a sweeping beam) and hurt on a tick while they last; some *follow* a hero until the last 0.7 s (a
  hunt); one can *carry the champion* to where it lands (a blink); a *guide* only shows where something will happen.
  Damage goes through the same `WorldIncident.strikeHero` path as any other blow, so dodge, armour and barrier apply.
* `BossKit` / `BossBrain` / `BossSystem` (`Game/Systems/BossSystem.swift`): each champion has a kit (moves, an
  `intensity` 1...10, a `tempo`, optional `adds` and a `signature` move). The brain picks the next move (never the same
  twice running, its signature twice as often), is committed to it, then **stands still and hittable for 0.8 s**.
  It never starts a move mid-charge or mid-windup, and a stun cancels the pattern.
* **Phases.** At two thirds and one third of its health a champion stops, roars and lays a large marked slam and a ring,
  and calls in its own kind. Moves open up over the phases (see below), the pauses shorten by 16% per phase, and in the
  last phase a move is followed straight away one time in three.
* `EnemyAISystem` holds a casting champion still. Its ordinary attack (charge, summon, shot, melee) carries on between moves.
* `HazardRenderer` draws the marks; guests draw the same marks because they are replicated (below).

## The moves

| Move | What it is | How to beat it |
| --- | --- | --- |
| Slam | A disc round the champion. From intensity 4, eight shards fly out from its edge as it lands | Leave the disc; the shards start outside it |
| Cleave | A wedge toward the nearest hero. From intensity 6 a second wedge behind, marked from the start | Step out sideways |
| Volley | A fan of 5 to 7 shots (two volleys from intensity 5), aimed without leading | Keep moving |
| Ring | Two or three rings of about ten shots that start 3 tiles out, each offset half a step | Slip through the gap; a hero close in is inside it |
| Spiral | A rotating stream, two or three arms, shots 1.2 tiles or more apart | Circle with it |
| Meteors | A disc on every hero and others round them, landing together; from intensity 6 each smoulders for 3 s | Leave your own, then the embers |
| Lanes | Two to four parallel strips across the hero, with gaps | Step into a gap (1.7 tiles wide) |
| Pools | Discs that land and keep burning for 5 s or more | Leave, and stay out |
| Blink | The champion vanishes and lands somewhere else with a slam; the landing is marked first | Be somewhere else |
| Summon | Its own kind called in around it | Thin them, or ignore them |
| Sweep | A beam that turns across a marked wedge over about 2.5 s | Leave the wedge, or get behind the champion |
| Hunt | A mark on every hero that follows them, then locks for the last 0.7 s | Keep moving, then step out |

Moves open up as health falls: the first two at the start, then more each phase until all are open.

## Who, and where

Every realm sends one champion for each of its boss waves, none twice, each a step up from the last, the realm's own
great champion last. There are 27 (the ten realm champions and 17 more), all with their own art, numbers and kit
(`EnemyCatalog.champions`, easiest first; `bosses(for:)` gives each realm's list). The Abyss sends them all in order.

| Realm | Its champions |
| --- | --- |
| Ashen Wilds | Rukh the Pit-Brute, Grask the Warchief |
| Drowned Fen | Grask, Vesk the Bogmother, The Drowned King |
| Hollow Forest | The Drowned King, Old Thornmaw, The Hollow Stag |
| Frozen Wastes | The Hollow Stag, Frostfang, Yrsa the Rimewitch, The Rime Tyrant |
| Blighted Kingdom | The Rime Tyrant, Sir Rotgrave, The Bloated One, The Plague Monarch |
| Burning Depths | The Plague Monarch, Cinderjaw, The Magma Colossus, Azreth, Vaskar the Ember Lord |
| Shattered Realm | Vaskar, The Fractured Eye, The Riftweaver, The Warped Knight, Voidmaw |
| Fallen Citadel | Voidmaw, The Oathbreaker, The Siege Titan, The Bellkeeper, The Gilded Regent, The Iron Saint |
| Gate of Ruin | The Rime Tyrant, The Plague Monarch, Vaskar, Voidmaw, The Iron Saint, The Grave Warden |

Intensity (1 to 10) raises the size of the ground, the number of shots and shortens warnings, which never fall below
`BossSystem.minimumWarning` (0.7 s). No shot is faster than `fastestShot` (8 tiles a second; a hero walks at 4.2).

## The promise, tested

`FateLostTests/BossTests.swift` runs each of the 27 champions for 70 seconds against a hero standing at melee range, the
worst place to be, and asserts that every mark appears before it lands, has at least 0.7 s of warning, and could be
left in time (the shortest walk to safety fits in the warning, at walking speed, after a quarter-second to react). It
also covers the geometry (including across the map seam), that damage lands once and only after the warning, that
pools tick, beams sweep, hunts lock and blinks land, that a champion holds still while it casts, that phases happen
once, that no realm repeats a champion, and the wire round trip. What the tests cannot say is whether it is *fun*: the
numbers (`BossSystem`, the kits in `EnemyCatalog`) are meant to be tuned by playing.

## Rifts

About one champion in ten (`RiftTuning.chance`; not a realm's last, which ends the run) opens a **portal** where it
falls: one of four, in the colour of what waits behind it. It stays 90 seconds, is pointed at by an arrow, and shows as
a column of light.

Step through and the **whole party** goes: any fallen hero is raised, the horde is left behind, and everyone lands on
the far side of the map (nothing else is there) with a few seconds of immunity. The wave clock is stopped and put back
exactly as it was afterwards. Three and a half seconds later the great one arrives:

| Rift | Who | Sprite |
| --- | --- | --- |
| Cinders | Ignarok, the World-Forge | a furnace-giant, at 2.6 times a champion's scale |
| Tides | Nerezza, the Brine Matriarch | a spider older than the sea |
| Winter | Auroch, the White Sovereign | an antlered ice-king |
| The Void | The Unblinking | one great eye |

Each has 14,000 health (scaled like any enemy by time and party size), intensity 9, eight moves and reinforcements. On
winning, everyone gets experience worth 2.5 levels, a **rift find** (three relics, each **epic** (78%) or **legendary**
(22%)) and a pale-gold way home where it fell; stepping onto that puts everyone back where they stood. Dying in the
rift is the same as dying anywhere.

## Night hunters (from the Frozen Wastes on)

* **Vampire bat.** Fast and fragile, and it darts from side to side. Its bite cuts **health regeneration to a tenth for
  6 seconds** (`Withered`), so a build that regenerates its way out of trouble has to kill bats first.
* **Dusk stalker.** Almost invisible until it winds up (half a second, in which it shows), then lunges five tiles from
  the shadows. If the blow lands it **hamstrings** (30% slower for 4 seconds).

Both show as small red chips under the health bar with the time left; tap one to read it. (A guest sees the slow but not
the chip.) A blow that is dodged or that lands on a hero who is immune leaves no mark.

## Multiplayer

The host owns the fight. Marks travel in the snapshot (`NetHazard`: shape, position, direction, size, warning, age,
linger, a guide flag; up to 24 near the viewer) and so do portals and the rift the party is in (`NetPortal`, and one
byte). A guest never computes damage; it draws, counts ages on between snapshots, and the host tells it who was hurt
through the ordinary hero health. Shots are the ordinary hostile projectiles. `NetTables.contentVersion` is now 5: a
phone on an older build is refused rather than misdrawn.

## Passive healing

Stacking regeneration from several classes used to add without limit. `PlayerTuning.effectiveRegeneration` now counts
it in full up to **3% of max health a second**, then each extra point counts for less, approaching a ceiling of **6%**.
Timed auras and songs are not capped (they are skills with a cooldown), and neither are life steal or one-off heals.
The vampire bat is the other half of the answer: a build that stacks regeneration meets creatures that switch it off.
