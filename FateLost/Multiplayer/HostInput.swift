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

    /// How much of the gap to a believable report is closed by each report.
    /// Closing all of it at once would step the hero by however far they had
    /// got ahead, every time one arrived; closing a share of it, they are
    /// walked into agreement over a few reports and never seen to jump.
    static let adoptionShare: CGFloat = 0.35
    /// Gaps smaller than this are simply agreed.
    static let adoptionSnap: CGFloat = 0.06

    /// Takes the guest's word for where they are, if it is believable, a step
    /// at a time.
    static func adopt(hint: CGPoint, forHero index: Int, in simulation: inout GameSimulation) {
        let state = simulation.playerState(of: index)
        guard !state.isDefeated, !simulation.isSheltered(index) else { return }
        let gap = simulation.world.delta(from: state.position, to: hint)
        guard gap.length <= positionTrust else { return }
        let share = gap.length <= adoptionSnap ? 1 : adoptionShare
        simulation.perform(as: index) { sim in
            sim.player.position = sim.world.wrap(sim.player.position + gap * share)
            sim.combat.playerPosition = sim.player.position
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
            case .proceed:
                sim.voteToProceed(hero: index)
            }
        }
    }
}
