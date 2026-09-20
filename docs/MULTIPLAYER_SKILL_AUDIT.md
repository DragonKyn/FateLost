# Multiplayer skill audit

Every one of the 231 skills (12 files: eleven archetypes and the eight orders) is
written from the same small vocabulary, `EffectAction`, run by one interpreter
(`ActionExecutor`) between systems. That is what made a party tractable: each
*action* was audited once, and each *skill* inherits the result. Where the
interpreter needed to learn about allies, it did so in one place, through
`Relationship` / `TargetRule` (`Game/Combat/PartyTypes.swift`), not with
multiplayer conditionals inside abilities.

Rule of thumb: **anything that hurts reaches enemies only; anything an ability
gives reaches you and your living friends nearby; everything you own stays yours.**
Friendly fire is off, and there is no code path that damages a hero from a hero.

A scan of the skill content (`Data/Skills/*Skills.swift`) found: 75 skills
that afflict or crowd-control, 54 with procs, 49 with novas/cones/strikes, 26 with
zones, 25 that summon, 19 that buff, 16 that regenerate, 13 with on-kill effects,
11 with projectiles, 10 auras, 8 that heal, 8 that shield, 5 chains, 5 dashes,
3 healing fields, 3 immunity, 3 forms, 3 stealth, 3 life steal, 2 cooldown effects.

## Audit by effect

| Action | Multiplayer behaviour | Change made |
|---|---|---|
| `nova`, `cone`, `chain`, `volley`, `strikes` (damage) | Hurts enemies only. Kill credit and lifesteal go to the hero whose hit landed (their build's procs fire). Projectiles are per hero; enemy shots are shared and hit whichever hero they reach first. | Enemy shots moved to a shared list; hostile hits become incidents applied per hero. |
| `afflict`, `pull` | Enemies only. Statuses are on the enemy and tick once for everyone (damage over time is credited to whichever hero's turn runs the status pass). | Status tick runs once per step, not per hero. Enemy statuses are no longer cleared when one hero falls in a party. |
| `heal` | **Reaches the caster and living allies within 6 tiles** (× area size), each healed by the same share of *their own* max health. Enemies and dead allies are never healed. | `PartyEffect.heal` with `TargetRule.allies`. |
| `barrier` | Same as heal. | `PartyEffect.barrier`. |
| Zone with `playerBuff` (healing/armour fields, auras) | **Buffs every living hero standing inside**, not just the one who laid it. | `PartyEffect.buff` from `ZoneSystem`. |
| `buff` | Personal (a war-cry you use on yourself, a form's haste). Deliberately not shared, so a party is not four times as strong from one cast. | none |
| `invulnerable`, `stealth`, `transform`, `dash` | Personal. Stealth hides only the caster from the horde's targeting. | Enemy target selection is per hero (`AITarget.isHidden`). |
| `selfDamage` | Personal, never lethal. | none |
| `reduceCooldowns` | Personal. | none |
| `summon` | Belongs to the hero who cast it and follows them. Enemies weigh *every* hero's summons (taunts, screening) and wound them, resolved in the owner's context. Summon limits and cooldowns are per hero. | `AllyAnchor.hero`; world anchors; wounds are incidents. |
| Auras (`isAura` zones) | Follow the hero who has them; if they carry a buff, it reaches allies in the radius like any field. | as fields |
| Procs (`hit`, `crit`, `kill`, `hurt`, `dodge`, `interval`, `cast`) | Fire for the hero they belong to only. A heal or barrier from a *proc* (life-on-kill, a hurt barrier) stays personal: only abilities bless. | `bless()` requires an ability behind the action. |
| Life steal, regeneration, healing received, overheal to barrier | Personal stats. | none |
| Kill credit, XP, levels | A kill is credited to the hero whose damage landed; **experience gathered by anyone is everyone's**, and a fallen hero banks theirs. Levels, skill points and relics stay individual. | `shareExperience()`, `bankedExperience`. |
| Shrines and chests | Whoever walks onto one takes the bargain and the find; the offer is theirs. | none (already per hero) |
| Revive / resurrection | No skill resurrects. Reviving is a party mechanic (marker, 3 s channel, broken by damage or distance). `TargetRule.resurrection` exists for a future skill. | `ReviveMarker`, `stepRevives`. |

## The skills that change

Abilities (cast on a button) whose heal or barrier now also reaches allies:

* Healing: Cleric **Renewal** and **Miracle** (the full heal reaches friends in range as the same fraction of *their* max
  health; Miracle's immunity and burst stay the caster's); Paladin **Hallowed Storm**; Monk **Spirit Palm** and
  **Transcendence** (heal only; the immunity is personal); Druid **Rampage** (heal only; the buff is personal).
* Shielding: Warrior **Bulwark** and **Aegis of the Oath**; Wizard **Stillness of Ages**; Bard **Grand Masquerade**.

Skills that heal or shield through a *trigger* stay personal, on purpose, because a party would otherwise multiply
them: Druid **Rejuvenation** (every 8 s), Warrior **Blood for Blood** (kills), Wizard **Warding Glyph**, Paladin **Shield
of Faith**, Monk **Chi Barrier**, Cleric **Sacred Ward**, and the order capstones **Debt Collector** and **Warden of the
Deep Wood**.

Fields and auras that carry a buff now help everyone inside: Cleric **Hallowed Ground**, Paladin **Hallowed Bastion**,
Warrior **War Banner**, and auras such as Paladin **Aura of Resolve**, **Steadfast**, Warrior **Commanding Presence**
and Bard **War Drums**, wherever their data gives a `playerBuff`.

No skill needed a data change: the behaviour is decided by *what kind of action it is* and *whether an ability cast
it*, and is covered by tests (`PartyCombatTests`): an area attack hurts the horde and never the party in it; an
ability's heal reaches a friend in range, not one out of range, not a fallen one, not an enemy; a proc's heal stays
personal; a healing field helps everyone inside; enemy shots hit the hero they reach.

## Not changed on purpose

* Personal buffs stay personal (see above).
* Summons are not shared between heroes.
* Crowd control on the horde still ends when one hero falls **only in a solo run**; in a party, an affliction may belong
  to anyone, so it runs its course.
* Forms are per hero and drawn on the guest's screen from the host's word.

## Open questions for play-testing

* Is 6 tiles the right reach for a blessing? (`CombatTuning.supportRadius`.)
* Should an ability's *buff* half of a mixed heal-and-buff (Rampage, Transcendence) also reach allies?
* Party scaling (`PartyTuning`: +55% enemy health and +45% spawns per extra hero).
