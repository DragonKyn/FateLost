# Multiplayer protocol (version 1)

The app and the party service speak this. The service is `worker/`; the app side is
`FateLost/Multiplayer/PartyProtocol.swift` and `NetCodec.swift`. Any incompatible change bumps
`PROTOCOL_VERSION` (`worker/src/protocol.ts`) and `PartyProtocol.version` together; the service
answers a different version with `426 protocol_mismatch`. Gameplay frames carry a separate
`contentVersion` (`NetTables.contentVersion`) which a guest checks before drawing a snapshot.

Production `https://fate-lost-multiplayer.wickedstudiosca.workers.dev`, staging
`https://fate-lost-multiplayer-staging.wickedstudiosca.workers.dev`. HTTPS and WSS only.

## Room codes, names, ids

* Room code: 6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no 0, O, 1, I, L), drawn with
  rejection sampling from `crypto.getRandomValues`. There is no public list.
* Display name: NFC, 1–16 code points, no control (Cc), format (Cf), unassigned, private-use, surrogate
  or line/paragraph separator characters, none of a short list of blank letters (U+3164 and kin),
  at least one letter, number, symbol or punctuation mark. Spaces collapse.
* Fate ID: `FL-XXXX-XXXX` from the same alphabet.
* Password: optional, 1–64 characters, request body only.

## HTTP

Bodies are JSON, at most 2 000 bytes. Errors are `{"error":{"code","message",…}}`.

| Request | Body | Success | Errors |
|---|---|---|---|
| `POST /v1/rooms` | `{protocol,name,fateId,password?}` | `201 {code,playerId,token,room}` | 400 `bad_request`, 413, 426, 429 |
| `POST /v1/rooms/{code}/join` | same | `200 {code,playerId,token,room}` | 401 `password_required`, 403 `wrong_password`, 404 `room_not_found`, 409 `room_full` / `run_in_progress`, 429 `rate_limited`, 426 |
| `GET /v1/rooms/{code}/ws` | headers `Authorization: Bearer <token>`, `X-Fate-Protocol: 1` | `101` WebSocket | 401 `unauthorized`, 404, 426 |
| `GET /health` | | `{ok,service,protocol,environment}` | |

`token` is the room credential (256 bits, base64url). It is never returned again and never in a URL.

## Socket, JSON text frames

Client → server (each validated; at most 20 000 bytes):

`ready {ready}` · `loadout {loadout:{weapon,hero?,legacy?}}` (weapon `[A-Za-z0-9_.-]{1,40}`, hero a flat
object of short values, ≤ 1000 legacy ids) · `rename {name}` · `setRealm {realm}` (host) · `start` (host) ·
`kick {target}` (host) · `close` (host) · `leave` · `runEnd {runId,outcome,summary}` (host;
`defeated|conquered|aborted`, summary ≤ 6 000 bytes).

Server → client: `welcome {you,room}` · `room {room}` (the full lobby on any change) ·
`runStart {resumed,runId,runNumber,seed,realm,hostId,you,roster}` (the host's roster also carries each
player's `legacy`; `seed` is decimal text of a 64-bit unsigned integer) · `runEnd {runId,outcome,summary}`
· `peer {id,slot,event}` (to the host: `connected|disconnected|left`) · `hostAway {until}` · `hostBack`
· `newHost {id}` · `kicked` · `left` · `closed {reason}` · `replaced` · `error {code,message}`.

Keep-alive: the client sends the text `ping`; the runtime answers `pong` without waking the room.

Close codes: `4000` replaced by a newer connection, `4001` unknown member, `4003` kicked, `4004` room closed.

### Room view

`{code,protocol,hostId,phase:"lobby"|"inRun",runNumber,hasPassword,maxPlayers,realm,members:[{id,name,
fateId,slot,host,ready,connected,weapon,hero}],run:{runId,seed,startedAt}|null,lastRun:{runId,outcome,summary}|null,
hostGraceEndsAt}`. It never contains a credential or a verifier.

### Rules the room enforces

* At most 4 members; a run needs ≥ 2; every non-host member must be connected and ready to `start`.
* No joining mid-run (reconnecting is fine).
* Only the host may `start`, `kick`, `close`, `setRealm`, `runEnd`; the host cannot be kicked.
* `runEnd` must name the current run; it returns the party to `lobby`, clears ready flags, stores `lastRun`.
* Host leaves in a lobby: the oldest connected member is promoted. Host leaves mid-run: the run is aborted
  and a new host promoted. Host disconnects mid-run: 45 s grace, then the run is aborted. Host
  disconnects in a lobby: 60 s, then handover if someone else is connected.
* Rates: a socket is limited by a token bucket (guest 100/s burst 160; host 300/s burst 400).
  Creating rooms: 12 per hour per address. Failed joins: 12 per 10 minutes. Eight wrong passwords lock a room for 60 s.

## Socket, binary frames (relayed unread)

Kinds: `1` input, `2` snapshot, `3` command, `4` events, `5` self state, `6` batch (host only).

* Guest → room: `[kind][payload…]` (≤ 4 096 bytes). The host receives `[kind][senderSlot][payload…]`.
* Host → room: `[kind][target][payload…]` (≤ 24 000 bytes); `target` is a seat or `0xFF` for everyone. A guest receives `[kind][payload…]`.
* Host → room, batched: `[6][count]` then per entry `[target][kind][lengthHigh][lengthLow][payload…]` (whole frame
  ≤ 64 000 bytes, ≤ 24 entries, each entry ≤ 24 000 bytes, no nested batches). The room unpacks it and gives each
  target an ordinary `[kind][payload…]` frame. The whole batch is checked before any of it is sent; a malformed one is
  dropped. A guest may not send a batch. This is how the host sends everything for every player in one message a tick,
  because the free plan counts messages the room *receives*.
* Frames outside a run, of unknown kind, or over the limit are dropped.

All numbers little-endian. Coordinates are `Int16` in 1/16 tile. Angles one byte over 2π. Strings `u8` length + UTF-8 (≤ 60).

### Input (10 bytes)
`u16 seq · i8 moveX · i8 moveY (×127) · u8 presses (bits 0–3) · u8 flags (1 interact, 2 menuOpen) · coord x · coord y`

### Snapshot
`u8 contentVersion · u32 tickMs · wave{u16 index,u8 phase,u8 bossFraction,u8 curseSeconds,string bossTitle,u8 restSeconds,u8 restVotes,u8 restVoters} ·
u8 heroes[slot,flags,x,y,i8 vx,i8 vy (×8),angle,u16 health,u16 max,u16 barrier,u8 level,u16 weaponSpriteHash,(string form)] ·
u8 markers[slot,x,y,u8 progress,u8 reviver] · u16 enemies[u32 id,u16 kindHash,u8 strain,x,y,u8 health,angle,u16 statusMask,u8 windup,angle,bool charging] ·
u16 projectiles[u32 id,x,y,i8 vx,i8 vy,u16 spriteHash,u8 visual,u8 radius×64,bool hostile] · u8 zones[…] · u8 allies[…] · u16 orbs[…] · u8 drops[…] · u8 shrines[…]`

Caps per snapshot: 450 enemies, 200 projectiles, 40 zones, 100 summons, 150 orbs, 40 drops, 6 shrines. Hashes are
FNV-1a folded to 16 bits of the sprite/enemy name; a test asserts they are collision-free. A reader never traps: short or
inconsistent data returns nothing.

Wave phases: `0` fighting, `1` boss incoming, `2` boss fight, `3` conquered, `4` resting (the party's breather). Content
version is 2.

### Events
`u8 count`, then per event a tag and its fields (see `NetEventCodec`); 41 kinds. At most 48 per packet; when over,
ordinary hits are dropped first. Hero numbers in events are relay seats.

### Self state, commands
JSON. `HeroSelfState` (`level, experience, required, earnedPoints, unspentPoints, ranks, slots, buildVersion, relics,
offer, weapon, wielded, cooldowns, moveSpeed, summonsDismissed, hasSummons, allyCount, stats, shelterSecondsLeft`) and
`NetCommand {kind: commit|equip|chooseRelic|chooseWeapon|rerollOffer|toggleSummons|proceed, ranks?, slots?, index?}` (≤ 400
skills, ranks 0–12, ≤ 4 slots).

### Run summary (`runEnd`)
The host's `summary` carries `wave`, `secondsSurvived`, `kills`, a light `heroes` list and a `report`: for every hero their
level, kills, elites, champions, crits, dodges, revives, falls, damage dealt and taken, healing, best hit and the echoes
they added to the pool, plus `pool` and `share` (pool ÷ heroes, at least 1). It stays well under the 6 000-byte limit.
Every phone shows the same results screen from it and credits its own player `share`.

## Legacy on the wire

A guest sends its owned Legacy node ids plus `mastery.<weapon>.<rank>` and `rerolls.<n>`; the host rebuilds bonuses
from its own tree (`PartyLegacy`), ignoring unknown ids, duplicates, and anything past 700 entries.
