# Champions, marked ground and passive healing

## The rule

Nothing a champion does is unavoidable. Every move is either **marked ground** (drawn on the floor from the moment it
exists, filling as it counts down, hurting only on landing) or **shots slow enough to weave through**. A hero who
reads the mark and steps out takes nothing.

## How it works

* `Hazard` (`Game/Combat/Hazard.swift`): a marked area of the floor, a **circle**, a **cone** or a **lane**, with a
  warning time. It hurts every hero still inside it once, when the warning ends, and glows for 0.3 s after. Damage goes
  through the same `WorldIncident.strikeHero` path as any other blow, so each hero's dodge, armour and barrier apply.
* `BossKit` / `BossBrain` / `BossSystem` (`Game/Systems/BossSystem.swift`): each champion has a kit (a list of moves, an
  `intensity` 1...10 and a `tempo`). The brain picks the next move (never the same twice running), is committed to it,
  then **stands still and hittable for 0.8 s** ("the punish window"). It is skipped while the champion is mid-charge or
  in its ordinary windup, and a stun cancels the pattern.
* `EnemyAISystem` holds a casting champion still. Its ordinary attack (charge, summon, shot, melee) carries on between moves.
* `HazardRenderer` draws the marks; guests draw the same marks because they are replicated (below).

## The moves

| Move | What it is | How to beat it |
| --- | --- | --- |
| Slam | A disc round the champion. From intensity 4, eight shards fly out from its edge as it lands | Leave the disc; the shards start outside it, so a hero at its feet is inside the pattern |
| Cleave | A wedge toward the nearest hero. From intensity 6 a second wedge behind, marked from the start | Step out sideways |
| Volley | A fan of 5 to 7 shots (two volleys from intensity 5), aimed at the nearest hero without leading | Keep moving |
| Ring | Two or three rings of about ten shots that start 3 tiles out, each ring offset half a step from the last | Slip through the gap; a hero close in is inside the ring |
| Spiral | A rotating stream, two arms (three from intensity 8), shots 1.2 tiles or more apart | Circle with it |
| Meteors | A disc on every hero, and others scattered round them, all landing together | Leave your own |
| Lanes | Two to four parallel strips across the hero, with gaps between | Step into a gap (1.7 tiles wide) |

Moves open up as health falls: two at the start, a third below two thirds, a fourth below one third. The pauses between
moves shorten by 16% each phase.

## The ten kits

| Champion | Moves | Intensity | Tempo (s) |
| --- | --- | --- | --- |
| Grask, the Warchief | Slam, Volley | 1 | 5.6 |
| The Drowned King | Meteors, Ring, Slam | 2 | 5.4 |
| The Hollow Stag | Slam, Lanes, Volley | 3 | 5.2 |
| The Rime Tyrant | Ring, Cleave, Lanes, Meteors | 4 | 5.0 |
| The Plague Monarch | Meteors, Ring, Cleave, Spiral | 5 | 4.8 |
| Vaskar, the Ember Lord | Cleave, Meteors, Lanes, Slam | 6 | 4.6 |
| Voidmaw | Ring, Spiral, Meteors, Lanes | 7 | 4.4 |
| The Iron Saint | Lanes, Cleave, Slam, Volley, Spiral | 8 | 4.2 |
| The Grave Warden | Meteors, Spiral, Lanes, Ring, Slam | 9 | 4.0 |
| The Abyssal Echo | Spiral, Lanes, Meteors, Cleave, Ring, Slam | 10 | 3.7 |

Intensity raises the size of the ground, the number of shots and shortens warnings, which never fall below
`BossSystem.minimumWarning` (0.7 s). No shot is faster than `fastestShot` (8 tiles a second; a hero walks at 4.2).

## The promise, tested

`FateLostTests/BossTests.swift` runs each champion for 70 seconds against a hero standing at melee range, the worst
place to be, and asserts that every mark appears before it lands, has at least 0.7 s of warning, and could be left
in time (the shortest walk to safety fits in the warning, at walking speed, after a quarter-second to react). It also
covers the geometry (including across the map seam), that damage lands once and only after the warning, that a
champion holds still while it casts, that a stun cancels a pattern, and the wire round trip. What the tests cannot
say is whether it is *fun*: the numbers (`BossSystem`, the kits in `EnemyCatalog`) are meant to be tuned by playing.

## Multiplayer

The host owns the fight. Marks travel in the snapshot (`NetHazard`: shape, position, direction, size, warning, age;
up to 24 near the viewer, about 20 bytes each and only while a champion is casting). A guest never computes damage; it
draws the mark, counts its age on between snapshots, and the host tells it who was hurt through the ordinary hero
health in the snapshot. Shots are the ordinary hostile projectiles, already replicated. This changed the wire format,
so `NetTables.contentVersion` is now 4: a phone on an older build is refused rather than misdrawn.

## Passive healing

Stacking regeneration from several classes (Verdant Blood, Inner Calm, Legacy grains, relics) used to add without
limit. Now `PlayerTuning.effectiveRegeneration` counts it in full up to **3% of max health a second**, then each extra
point counts for less, approaching a ceiling of **6% of max health a second** and never passing it.

* One maxed passive is barely touched; four stacked are worth roughly one and a half.
* **Timed auras and songs are not capped** (Consecrate, Renewal, a Bard's song): they are skills with a cooldown and
  are paid for in full. Life steal and one-off heals are not regeneration and are not capped either.
* Both numbers are in `PlayerTuning` (`regenKneeFraction`, `regenCeilingFraction`).

Other ways to bring it under control that were considered and not built: regeneration paused for two seconds after
taking a hit (rewards dodging, but slows every build), or healing that cannot exceed a share of the damage just taken.
Either can sit on top of the soft cap if it turns out to still be too strong.
