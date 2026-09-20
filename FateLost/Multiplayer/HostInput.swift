import CoreGraphics
import Foundation

/// How the host turns what a guest sent into what their hero does.
///
/// A guest is trusted with what it *wants* (a direction, buttons, a wish to
/// interact) and, within reason, with where it is. Everything else the host
/// works out itself. Pulled out of the run controller so it can be tested
/// without a network.
enum HostInput {
    /// A guest's claim about its own position is believed when it is this close
    /// to where the host has the hero. Movement feels instant, and nobody can
    /// step further than this from where the host thinks they are.
    static let positionTrust: CGFloat = 1.6

    /// Applies one guest's latest input to their hero for the coming steps.
    static func apply(_ input: NetInput?, presses: UInt8, interact: Bool, toHero index: Int,
                      in simulation: inout GameSimulation) {
        var intent = PlayerIntent.idle
        if let input {
            intent.move = input.move
            simulation.setMenuOpen(input.menuOpen, forHero: index)
            adopt(hint: input.position, forHero: index, in: &simulation)
        }
        intent.abilityPresses = presses
        intent.interact = interact
        simulation.setIntent(intent, forHero: index)
    }

    /// Takes the guest's word for where they are, if it is believable.
    static func adopt(hint: CGPoint, forHero index: Int, in simulation: inout GameSimulation) {
        let state = simulation.playerState(of: index)
        guard !state.isDefeated, !simulation.isSheltered(index) else { return }
        if simulation.world.distance(state.position, hint) <= positionTrust {
            simulation.perform(as: index) { sim in
                sim.player.position = sim.world.wrap(hint)
                sim.combat.playerPosition = sim.player.position
            }
        }
    }

    /// Carries out a guest's build command for their hero, if it is legal.
    static func apply(_ command: NetCommand, toHero index: Int, in simulation: inout GameSimulation) {
        simulation.perform(as: index) { sim in
            switch command.kind {
            case .commit:
                guard let ranks = command.ranks else { return }
                var draft = SkillAllocation()
                for (id, rank) in ranks {
                    guard let skill = SkillCatalog.skill(id) else { continue }
                    for _ in 0..<max(0, min(rank, 12)) { draft.add(skill) }
                }
                sim.commit(draft, slots: command.slots ?? [])
            case .equip:
                sim.equip(command.slots ?? [])
            case .chooseRelic:
                if let choice = command.index { sim.chooseRelic(at: choice) }
            case .chooseWeapon:
                sim.chooseWeapon()
            case .rerollOffer:
                sim.rerollOffer()
            case .toggleSummons:
                sim.toggleSummonsDismissed()
            }
        }
    }
}
