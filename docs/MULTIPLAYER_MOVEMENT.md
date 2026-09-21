# How other players' movement is drawn

The problem: the host sends a picture of the world 15 times a second, and a picture arrives late, unevenly,
in bunches, out of order, or not at all. Drawn as it arrived, a remote hero steps 15 times a second and the steps
are uneven. On the host the guest was also pushed a step every time their phone reported in.

Nothing below changes what the game *is*. The host's simulation stays the truth for collisions, damage, death and
revival. This decides only where a remote hero is **drawn** between pictures, and it can neither write a position
nor be more than a fraction of a second from the simulation.

## What was wrong, and where

| Where | Cause | Fix |
| --- | --- | --- |
| A guest watching the host or another guest | The latest snapshot's position was drawn as it arrived (15 steps a second) | Interpolate between buffered snapshots, drawn a little behind "now" (`RemoteTrack`, `StreamClock`, `RemotePlayback`) |
| The host watching a guest | Each report from the guest's phone moved the simulated hero all the way to where the phone said it was, so a hero walking at speed stepped forward at every report | Close 35% of the gap per report (`HostInput.adoptionShare`), and draw the guest on a steady path (`VisualFollower`) |
| A guest's own hero | A gap of only 0.6 tiles (a walk's worth of lag) was treated as disagreement and pulled back | Follow the host only past 2.2 tiles; snap past 3.5; ease small gaps away only when standing still |

Local movement is untouched: a phone's own hero moves under its own thumb at once.

## The model

**Snapshots.** Sent at a fixed **15 Hz** (unchanged; not per frame). Each carries the host's tick (ms), every hero's
position (1/16 tile), velocity (1/8 tile/s) and facing. Inputs go up at most 20 Hz, and only when they change (2–7 Hz
otherwise; see the architecture doc). A snapshot whose tick is not newer than the last is **dropped whole** (stale or
repeated); a tick that goes back by more than 5 s is a host that started over and resets the stream.

**Buffer and interpolation.** `RemoteTrack` keeps the last 8 pictures of each remote hero (about half a second). The
drawing runs **100 ms** behind the newest news (`StreamClock.baseDelay`): a picture and a half, so two pictures nearly
always bracket the moment being drawn, and it is a straight blend between them (torus-aware: it crosses the map's seam
like anywhere else). Velocity and facing are blended or taken from the nearer picture.

**Adaptive delay.** `StreamClock` maps host time onto this phone's clock (following the earliest arrivals, easing
toward them at 30% per picture and drifting away at 2%) and measures jitter (an average of how much each gap between
arrivals differs from the gap between the host's stamps). The delay is `100 ms + 2 × jitter`, capped at **200 ms**. The
render time is also *slewed*: it never runs more than 10% faster or slower than real time, so a change in the delay is
walked into, never jumped (a 20 ms change takes about 0.2 s and is not visible). A clock that has moved more than 0.4 s
(a phone suspended, a host that restarted) is started over.

**Late pictures.** Past the newest picture, a hero is carried along their last velocity for at most **250 ms**
(`RemoteTrack.maxExtrapolation`), then held. A velocity above 40 tiles/s is never believed. When the stream resumes,
the difference between where the hero was going and where they turn out to be (up to 3 tiles) is **absorbed**: the drawn
path stays continuous and the difference fades over about 120 ms.

**Jumps.** A picture that lies more than 6 tiles from where the last one and its velocity explain, or that implies more
than 40 tiles/s, is a teleport, a recall or a revival elsewhere. It is flagged (`MovementStats.jumps`), never slid across,
and drawn at once when its time comes. Dashes (30 tiles/s over a few pictures) are below both limits and are drawn as motion.

**The host's view of a guest.** `VisualFollower` carries the drawn position along the guest's velocity between frames and
closes about two thirds of any gap to the simulated position in 70 ms; a gap over 3.5 tiles, a fall or a rise is drawn at
once. The drawing is within 0.35 tiles of the simulation in the tests.

**The guest's view of itself.** Prediction is unchanged. Reconciliation with the host's report of that hero: under 0.2
tiles, nothing; 0.2–2.2 tiles, eased away at 20% per snapshot only if standing still (a walking hero is always a little
ahead of a snapshot that is a round trip old, and that is lag, not disagreement); 2.2–3.5, followed at 20% per snapshot;
over 3.5, snapped to.

## Cost

* **Send rate:** 15 snapshots a second and up to 20 inputs a second: no increase. Smoothing is entirely on the receiving
  phone. Movement alone (four heroes, nothing else in the picture) is about 100 bytes a snapshot, roughly 1.5 KB/s a
  guest; a snapshot with a big fight in it is a few KB, as before.
* **Cloudflare:** the host still sends one batched message per tick and guests send only changed input, so requests to the
  room are unchanged (about 60–225 request-equivalents a minute for two to four players) and there are no new
  observability events (invocation logs are off).
* **CPU:** a few dozen floating-point operations per remote hero per frame. The test suite times a minute of a full party
  (`testTheWholeFeatureCostsLittlePerFrameForAFullParty`). It scales linearly with players and stays trivial at four.

## Measured

Counters, not packets (`MovementStats`, shown in the developer performance overlay as `net …` for a guest): snapshots
received, mean and longest gap between them, the delay and jitter in force, the share of frames that had to be guessed
(extrapolated or held) rather than interpolated, stale pictures dropped, and jumps.

The tests in `FateLostTests/MovementSmoothingTests.swift` run a seeded stream through simulated links and assert on what
would be drawn (frame-to-frame step evenness, largest step, worst distance from the truth, no backward drawing, no slide
across a teleport, order and staleness, clock behaviour):

| Condition | Stream | Asserted |
| --- | --- | --- |
| Normal Wi-Fi | 30 ms ± 10 ms | steps even (deviation under 12% of the mean; the old drawing was over 90%), no step over 1.3 × a normal one, never more than 1.3 tiles behind, nothing guessed |
| Moderate latency | 120 ms ± 20 ms | steps even, largest step under 1.4 × normal, never more than about 1.8 tiles behind |
| Heavy jitter and reordering | 100 ms ± 80 ms | less than half the old unevenness, jitter measured, delay raised but capped at 200 ms |
| Brief loss | 0.3 s of nothing | no lurch, never drawn backwards, carried over by extrapolation |
| Endless outage | stream stops | held within 250 ms of travel, however long it lasts |
| Rapid direction changes | reverse every 0.25 s | never strays more than 1.7 tiles from the hero, never overshoots the path |
| Dash | 6 tiles in 0.2 s | drawn as motion, not flagged as a jump, caught up afterwards |
| Teleport | 47 tile jump | recognised once, never slid across, drawn in a single frame |
| Map seam | walking over the wrap | as smooth as anywhere |
| Death and revival | fallen heroes draw exactly where they lie (velocity zero, drawn at once) | |
| Host and guest views | `VisualFollower` absorbs the nudges (largest step under 70% of the simulation's), within 0.35 tiles | |

These are simulated links, not a phone on a real network. The same stream should be checked on two phones (see the
runbook); the overlay's `net` line gives the aggregate numbers to compare.
