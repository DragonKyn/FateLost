import CoreGraphics
import Foundation

/// Identifies a run before it starts: where, with what, and from which seed.
struct RunConfiguration: Hashable {
    let realmID: RealmID
    let starterWeaponID: WeaponID
    let seed: UInt64

    static func new(realm: RealmID, weapon: WeaponID) -> RunConfiguration {
        RunConfiguration(realmID: realm, starterWeaponID: weapon, seed: UInt64.random(in: .min ... .max))
    }
}

/// The authoritative game state for one run, advanced in fixed steps.
///
/// Deliberately free of SpriteKit: the scene feeds it intents and reads its
/// state to draw. That keeps game rules testable and lets rendering change
/// without touching them. Each later phase adds systems here (spawning,
/// combat, pickups, waves) rather than into the scene.
struct GameSimulation {
    let run: RunConfiguration
    let realm: RealmDefinition
    let arena: ArenaLayout
    let weapon: WeaponDefinition

    private(set) var player: PlayerState
    /// Simulated seconds since the run began (excludes pauses).
    private(set) var elapsed: TimeInterval = 0

    private let movement: MovementSystem

    var world: ToroidalWorld { arena.world }

    init(run: RunConfiguration, tuning: GameTuning) {
        self.run = run
        realm = RealmCatalog.realm(run.realmID)
        weapon = StarterWeapons.definition(for: run.starterWeaponID) ?? StarterWeapons.sword
        arena = ArenaGenerator(definition: realm.arena, seed: run.seed).generate()
        player = PlayerState(position: arena.playerSpawn, maxHealth: tuning.player.baseMaxHealth)
        movement = MovementSystem(tuning: tuning.player)
    }

    mutating func step(dt: TimeInterval, intent: PlayerIntent) {
        elapsed += dt
        movement.step(&player, intent: intent, speedMultiplier: 1, world: world, dt: CGFloat(dt))
    }
}
