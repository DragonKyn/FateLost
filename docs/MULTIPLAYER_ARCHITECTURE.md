# Multiplayer architecture

Fate Lost plays two to four heroes against one horde. This document is how it
is built. See also [the protocol](MULTIPLAYER_PROTOCOL.md), [the skill
audit](MULTIPLAYER_SKILL_AUDIT.md) and [the runbook](MULTIPLAYER_RUNBOOK.md).

## The shape of it

```
   host phone                      Cloudflare                     guest phones
 ┌────────────────┐            ┌─────────────────┐            ┌────────────────┐
 │ GameSimulation │  WebSocket │  Worker         │ WebSocket  │ GameSimulation │
 │ (all heroes)   │◀──────────▶│  └ PartyRoom DO │◀──────────▶│ (mirror only)  │
 │ GameScene      │            │  └ RateLimiter  │            │ GameScene      │
 └────────────────┘            └─────────────────┘            └────────────────┘
```

* **The Durable Object is authoritative for the party, not for the fight.** It
  owns the room code, who is in it, who hosts, ready states, the password, the
  run lifecycle (lobby → run → lobby) and each seat's credential. It does not
  simulate anything.
* **The host phone is authoritative for the fight.** It runs one
  `GameSimulation` containing every hero, the horde, the wave clock, drops,
  shrines and the revive rules. Guests send *what they want*; the host decides
  what happens.
* **Guests draw a mirror.** A guest keeps an ordinary `GameSimulation` that it
  never steps, filled from what the host sends, so the renderers, HUD and skill
  screens are the same code as in a solo run.
* **Gameplay bytes go through the room unread.** The Durable Object checks the
  sender, the size, the kind and the rate of a binary frame, then relays it.

## Why host-authoritative

The game is a deep single-player simulation (231 skills, 64 relics, a data-driven
effect interpreter). A dedicated server would mean running that simulation in
Workers; a lockstep model would need bit-exact floating point across devices.
Both were larger and riskier than making the existing simulation carry a party.
The cost is that a host with a modified app could cheat, and that the run ends
if the host is lost. Both are written under *Known limitations*.

## The party lifecycle

```
Create → players join → ready → Run 1 → results → SAME lobby → ready → Run 2 → …
```

A party is not a run. The room outlives every run: the code, the host, the
members, their names and the password stay; ready flags reset; the next run
gets a fresh seed and a fresh simulation on the host. A room ends only when the
host closes it, everyone leaves, or it is abandoned (30 minutes with nobody
connected; two hours of silence in a lobby). Rooms sleep in between: sockets use
the WebSocket Hibernation API, keep-alive pings are answered by the runtime
(`setWebSocketAutoResponse`) without waking the object, and there are no timers.
Time-driven change (host grace, expiry) is a single Durable Object alarm.

## Identity

Three separate things, on purpose:

| Layer | What | Secret? |
|---|---|---|
| Installation secret | 256 random bits, made on the phone, kept in the Keychain (this device only) | yes, never leaves the phone |
| Fate ID | `FL-8K4P-72QM`, a one-way hash of the secret, shown for troubleshooting | no, and it authenticates nothing |
| Room credential | 256 random bits issued by the room when a player joins, sent as `Authorization: Bearer` on the socket, stored by the room only as a SHA-256 hash | yes, room-scoped |

Display names are not identity: they need not be unique. They are validated on
the phone and again on the server (length, no control, format, unassigned or
private-use characters, no known blank letters, at least one visible character).
A kicked player's credential is deleted, so it cannot be used again.

Passwords are optional, never stored or returned, hashed with a per-room salt
(PBKDF2-SHA256, WebCrypto), sent only in a request body, and rate limited both per
address and per room (eight wrong guesses lock the room for a minute).

## The simulation carries a party

`GameSimulation` was written around one hero. Rather than rewrite the systems
(skills, stats, weapons, summons, procs all say "the player"), it keeps **one
hero live** in its ordinary fields and parks the others in `slots`, swapping
references when it turns to each (`activate`). A swap moves a few dozen pointers;
with one hero there is nothing to swap and the code path is the old one.

* What belongs to a hero (build, stats, cooldowns, summons, zones, projectiles,
  weapon, progression, finds, events) is swapped. What is shared (the horde, the
  spatial grid, orbs, drops, shrines, the curse, hostile shots, revive markers,
  the wave clock, the spawner) lives once.
* A test (`PartyHeroSwapTests`) classifies **every stored property** of
  `CombatState` and `GameSimulation` as hero or shared and fails if one is added
  and forgotten.
* One step: each hero's timers, movement and casts; then the world once (waves,
  spawns, the horde); then each hero's weapon, summons, shots, zones, procs and
  pickups; experience is pooled; each hero's finds and healing. Turns rotate so
  nobody always picks up first.
* The horde chooses the nearest reachable hero. What enemies do (strikes, blasts,
  charges, shots) is recorded as *incidents* and carried out afterwards, each in
  the context of the hero it fell on, so the same AI code serves every hero.
* Experience gathered by anyone is everyone's; a fallen hero banks theirs and
  is paid on revival. Enemy health scales with party size (+55% per extra hero)
  and spawn rate with the number standing (+45%).
* A hero with a menu open (skill tree, a find) is *sheltered* (untargetable and
  immune) for up to 25 seconds, since the game does not pause for one player. A
  disconnected hero is sheltered for 60 seconds.

### Teams and relationships

`Relationship` (`selfHero`, `ally`, `deadAlly`, `enemy`) and `TargetRule` say
what an effect may reach. Damage and crowd control are `hostile` (enemies only,
so friendly fire does not exist). Heals, shields and helpful fields are
`blessing`. `resurrection` reaches `deadAlly` (no skill uses it yet; the revive
system is a party mechanic, not a skill). Nothing multiplayer-specific lives
inside an ability: `ActionExecutor` queues a `PartyEffect` and the party
delivers it.

### Death and revival

There is no downed state. A hero at zero health dies, their forces are dismissed,
and a `ReviveMarker` (a grave cross) is left where they lay. A living friend within
1.8 tiles can tap **Revive**; a three second channel begins. It is broken by:
the reviver being struck (any blow that lands, including one a barrier absorbs; a
dodge or an immune hero does not count), moving more than 2.6 tiles away,
falling, leaving, or the target already being alive. Completing it returns the
hero at 30% health with two seconds of immunity, keeping their build and level.
The host validates everything; a guest only ever sends "I pressed interact".
Off-screen markers get a named, cross-shaped arrow in the same beacon layer as
shrines and chests.

One death never ends the run. When every hero has fallen (or is gone, or has been
disconnected past the grace) the host ends the run, results are shown and everyone
returns to the same lobby.

## Networking

Everything on the wire is in [the protocol](MULTIPLAYER_PROTOCOL.md). In short:

* **Inputs** (guest → host, 20 Hz, 10 bytes): stick, ability presses, interact,
  menu open, and where the guest thinks it is. The host adopts that position if it is
  within 1.6 tiles of its own (so movement feels instant without allowing
  teleports) and otherwise the guest is pulled back.
* **Snapshots** (host → each guest, 15 Hz): the whole party, and everything within
  26 tiles of that guest's hero, capped per kind so a frame always fits. Positions
  are 1/16 tile, angles one byte, health a fraction. About 5 KB in a large fight.
* **Events** (host → guest): what happened (hits, kills, casts, revives), so a guest
  makes its own effects and sounds. Personal events (`isPersonal`) go only to their hero.
* **Self state** (host → guest, 4 Hz, JSON): level, points, build, relics, the find on
  offer, cooldowns, stats.
* **Commands** (guest → host, JSON): commit a skill draft, equip abilities, choose
  or reroll a relic, toggle summons. The host applies each only if legal for that hero
  now (`commit` re-validates the tree, cost and no-refunds rules).
* The guest predicts its own movement, eases enemies and summons toward each new
  snapshot, flies shots on in straight lines, and counts cooldowns down between reports.

## Reconnecting

`PartyClient` reconnects with exponential backoff and full jitter (0.5 s doubling to
15 s, 14 attempts). The credential is the same, so the room replaces the old socket
for the same seat: there is never a duplicate hero. The app is also nudged when it
returns to the foreground. A dead connection is detected by a missing pong (45 s).
On reconnect the host sends a fresh snapshot and self state; a hero who was dead
is still dead with their marker in place. A killed app rejoins from the credential in
the Keychain. If the **host** drops, guests see "waiting for the host" for 45 s; if
they do not return the run is abandoned and everyone lands in the lobby. Host
migration is done **only in the lobby** (the oldest connected member takes over);
mid-run migration is deliberately not attempted, because the simulation lives on
the host's phone.

## Known limitations

* **A host can cheat**, and a guest can lie about what it owns: Legacy progress is
  held on each phone. The host builds each guest's hero from *node ids* against its
  own copy of the tree, so a client can only claim things that exist, but cannot be
  proved to have bought them. Acceptable between friends; not for a public ladder.
* **The host is a single point of failure.** Losing it ends the run.
* **The host phone does the work** for all heroes. Four heroes cost roughly four
  heroes' worth of simulation; on older phones a large late-run fight may drop
  frames. Enemy caps are unchanged.
* **Late joiners cannot enter a run in progress** (only reconnects).
* **Everything since the first party build is unproven on real devices.** The
  netcode is covered by unit tests and a real multi-client test of the service, but
  latency, phones, cellular hand-offs and feel have not been tried.
* Party balance numbers (enemy scaling, revive time and health, shelter length) are
  first guesses in `PartyTuning`.

## Files

Worker: `worker/src/{index,partyRoom,rateLimiter,protocol,crypto,limits,http,env}.ts`,
config `worker/wrangler.toml`, tests `worker/test`.

App: `FateLost/Multiplayer/` (protocol models, identity, HTTP API, socket, `PartyClient`,
hub, run controller, wire codecs), `Game/Simulation/GameSimulation+Party.swift` and
`+Mirror.swift`, `Game/Combat/PartyTypes.swift`, `Scenes/Gameplay/Entities/PartyRenderer.swift`,
`UI/Screens/Multiplayer/`.
