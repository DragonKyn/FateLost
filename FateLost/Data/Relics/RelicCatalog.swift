import Foundation

/// Every relic in the game.
enum RelicCatalog {
    static let all: [RelicDefinition] =
        CommonRelics.all + UncommonRelics.all + RareRelics.all + EpicRelics.all + LegendaryRelics.all

    private static let byID: [RelicID: RelicDefinition] = {
        var index: [RelicID: RelicDefinition] = [:]
        for relic in all {
            index[relic.id] = relic
        }
        return index
    }()

    static func relic(_ id: RelicID) -> RelicDefinition? {
        byID[id]
    }

    static func relics(of rarity: ItemRarity) -> [RelicDefinition] {
        all.filter { $0.rarity == rarity }
    }
}
