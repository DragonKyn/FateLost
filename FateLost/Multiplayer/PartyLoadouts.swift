import Foundation

/// How a player's permanent progress travels to the host, and how the host
/// turns it back into stats.
///
/// A Legacy board of hundreds of nodes cannot be sent as numbers to trust, so
/// what travels is *which nodes are owned* (plus the weapon's mastery rank and
/// the codex rerolls, as two pseudo-ids). The host rebuilds the bonuses from
/// its own copy of the tree, so a client can only ever claim things that
/// exist. It cannot be checked that the player really bought them: progress is
/// held on each phone. That is a known limit for a cooperative game between
/// friends, and is written down in docs/MULTIPLAYER_ARCHITECTURE.md.
enum PartyLegacy {
    /// The most ids the host will read from one player.
    static let maximumIDs = 700

    static func ids(from profile: LegacyProfile, weapon: WeaponDefinition) -> [String] {
        var result = profile.unlocked.sorted()
        result.append("mastery.\(weapon.id).\(profile.rank(of: weapon))")
        result.append("rerolls.\(CodexRewards.bonusRerolls(discovered: profile.lifetime.relicsDiscovered))")
        return result
    }

    /// Every stat bonus the ids stand for, for a run started with `weapon`.
    static func modifiers(from ids: [String], weapon: WeaponDefinition) -> [StatModifier] {
        var result: [StatModifier] = []
        for id in Set(ids.prefix(maximumIDs)) {
            if let node = LegacyTree.node(id) {
                result.append(node.modifier)
            } else if id.hasPrefix("mastery."), let split = id.lastIndex(of: ".") {
                let owner = String(id[id.index(id.startIndex, offsetBy: "mastery.".count)..<split])
                let rank = Int(id[id.index(after: split)...]) ?? 0
                if owner == weapon.id {
                    result.append(contentsOf: WeaponMastery.modifiers(for: weapon,
                                                                       rank: min(max(rank, 0), WeaponMastery.maxRank)))
                }
            }
        }
        return result
    }

    static func bonusRerolls(from ids: [String]) -> Int {
        for id in ids.prefix(maximumIDs) where id.hasPrefix("rerolls.") {
            let count = Int(id.dropFirst("rerolls.".count)) ?? 0
            return min(max(count, 0), CodexRewards.thresholds.count)
        }
        return 0
    }
}

extension PartyLoadout {
    /// What this player brings: their weapon, their look, what they own.
    static func make(weapon: WeaponDefinition, hero: HeroAppearance, profile: LegacyProfile) -> PartyLoadout {
        var look: [String: JSONValue]?
        if case .object(let fields)? = JSONValue.from(hero) {
            look = fields
        }
        return PartyLoadout(weapon: weapon.id, hero: look, legacy: PartyLegacy.ids(from: profile, weapon: weapon))
    }

    /// A member's look, as it was sent, or the default if it cannot be read.
    static func appearance(from fields: [String: JSONValue]?) -> HeroAppearance {
        guard let fields, let look = JSONValue.object(fields).decoded(as: HeroAppearance.self) else {
            return .standard
        }
        return look
    }
}

extension RunStartInfo {
    /// The party as the simulation needs it, host first, then the others by
    /// seat. Only the host is sent what each player owns; anyone else gets
    /// plain heroes, which the host never asks them to build.
    func partyConfigs() -> [PartyHeroConfig] {
        let ordered = roster.sorted { lhs, rhs in
            if lhs.id == hostId { return true }
            if rhs.id == hostId { return false }
            return lhs.slot < rhs.slot
        }
        return ordered.map { entry in
            let weapon = StarterWeapons.definition(for: entry.weapon) ?? StarterWeapons.sword
            let ids = entry.legacy ?? []
            return PartyHeroConfig(id: entry.id, name: entry.name, slot: entry.slot, weaponID: weapon.id,
                                   legacy: PartyLegacy.modifiers(from: ids, weapon: weapon),
                                   bonusRerolls: PartyLegacy.bonusRerolls(from: ids))
        }
    }
}
