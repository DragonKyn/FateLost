import Foundation

/// One thing a companion's look can be given: a named appearance, a size,
/// or a prop beside it. Each is its own purchase — buying a colour never
/// buys another, the way a hero's own wardrobe works.
enum CompanionOption: Hashable, Identifiable {
    case appearance(CompanionTarget, String)
    case scale(CompanionTarget, CompanionScale)
    case extra(CompanionTarget, CompanionExtra)

    var id: String {
        switch self {
        case .appearance(let target, let appearanceID): return "companion.appearance.\(target.rawValue).\(appearanceID)"
        case .scale(let target, let scale): return "companion.scale.\(target.rawValue).\(scale.rawValue)"
        case .extra(let target, let extra): return "companion.extra.\(target.rawValue).\(extra.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .appearance(let target, let appearanceID):
            return CompanionAppearanceCatalog.option(appearanceID, for: target).name
        case .scale(_, let scale): return scale.name
        case .extra(_, let extra): return extra.name
        }
    }

    var blurb: String {
        switch self {
        case .appearance(let target, let appearanceID):
            return CompanionAppearanceCatalog.option(appearanceID, for: target).blurb
        case .scale(_, let scale):
            switch scale {
            case .runt: return "Smaller, and a little quicker to overlook."
            case .standard: return ""
            case .massive: return "Bigger. Considerably."
            }
        case .extra(_, let extra): return extra.blurb
        }
    }

    var target: CompanionTarget {
        switch self {
        case .appearance(let target, _): return target
        case .scale(let target, _): return target
        case .extra(let target, _): return target
        }
    }

    /// The look this option produces when worn over another.
    func applying(to look: CompanionLook) -> CompanionLook {
        var next = look
        switch self {
        case .appearance(_, let appearanceID): next.appearanceID = appearanceID == "base" ? nil : appearanceID
        case .scale(_, let scale): next.scale = scale
        case .extra(_, let extra): next.extra = extra
        }
        return next
    }

    func isWorn(by look: CompanionLook) -> Bool {
        switch self {
        case .appearance(_, let appearanceID): return (look.appearanceID ?? "base") == appearanceID
        case .scale(_, let scale): return look.scale == scale
        case .extra(_, let extra): return look.extra == extra
        }
    }

    /// What wearing this a second time takes it back to: a size or an
    /// extra can be taken off, but an appearance has no "off" — something
    /// is always worn, so tapping the one already on does nothing further.
    var fallback: CompanionOption? {
        switch self {
        case .appearance: return nil
        case .scale(let target, _): return .scale(target, .standard)
        case .extra(let target, _): return .extra(target, .none)
        }
    }
}

enum CompanionUnlocks {
    static func cost(of option: CompanionOption) -> Int {
        switch option {
        case .appearance(let target, let appearanceID):
            guard appearanceID != "base" else { return 0 }
            switch target.weight {
            case .light: return 130
            case .medium: return 150
            case .heavy: return 200
            }
        case .scale(let target, let scale):
            guard scale != .standard else { return 0 }
            switch target.weight {
            case .light: return 100
            case .medium: return 120
            case .heavy: return 160
            }
        case .extra(_, let extra):
            switch extra {
            case .none: return 0
            case .banner: return 150
            }
        }
    }

    static func isFree(_ option: CompanionOption) -> Bool { cost(of: option) == 0 }

    static func appearances(for target: CompanionTarget) -> [CompanionOption] {
        CompanionAppearanceCatalog.options(for: target).map { .appearance(target, $0.id) }
    }

    static func scales(for target: CompanionTarget) -> [CompanionOption] {
        CompanionScale.allCases.map { .scale(target, $0) }
    }

    static func extras(for target: CompanionTarget) -> [CompanionOption] {
        CompanionExtra.allCases.map { .extra(target, $0) }
    }

    /// Every option there is.
    static let all: [CompanionOption] = CompanionTarget.allCases.flatMap {
        appearances(for: $0) + scales(for: $0) + extras(for: $0)
    }

    /// Every option that costs something.
    static let priced: [CompanionOption] = all.filter { !isFree($0) }
}
