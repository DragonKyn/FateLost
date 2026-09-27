import Foundation

/// One thing a companion's look can be given: the run of colour and size,
/// or a prop beside it. Priced the way the hero's own wardrobe is — the
/// flashier or heavier the companion, the more it costs.
enum CompanionOption: Hashable, Identifiable {
    /// Unlocks free choice of colour and size for this target, together:
    /// neither is a stat, so there is no reason to gate them separately.
    case customize(CompanionTarget)
    case extra(CompanionTarget, CompanionExtra)

    var id: String {
        switch self {
        case .customize(let target): return "companion.customize.\(target.rawValue)"
        case .extra(let target, let extra): return "companion.extra.\(target.rawValue).\(extra.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .customize(let target): return "Restyle: \(target.name)"
        case .extra(_, let extra): return extra.name
        }
    }

    var blurb: String {
        switch self {
        case .customize(let target): return "\(target.blurb) Recolour and resize it freely, any time."
        case .extra(_, let extra): return extra.blurb
        }
    }
}

enum CompanionUnlocks {
    static func cost(of option: CompanionOption) -> Int {
        switch option {
        case .customize(let target):
            switch target {
            case .bearForm, .wolfForm: return 240
            case .skeleton, .hellhound: return 216
            case .boneColossus, .fiend: return 336
            }
        case .extra(_, let extra):
            switch extra {
            case .none: return 0
            case .charm: return 150
            case .banner: return 180
            }
        }
    }

    static func isFree(_ option: CompanionOption) -> Bool { cost(of: option) == 0 }

    static let customizations: [CompanionOption] = CompanionTarget.allCases.map { .customize($0) }

    static func extras(for target: CompanionTarget) -> [CompanionOption] {
        CompanionExtra.allCases.map { .extra(target, $0) }
    }

    /// Every option there is.
    static let all: [CompanionOption] = customizations + CompanionTarget.allCases.flatMap { extras(for: $0) }

    /// Every option that costs something.
    static let priced: [CompanionOption] = all.filter { !isFree($0) }
}
