import CoreGraphics

/// Kinds of static set dressing that can appear in an arena.
enum DecorationKind: String, Codable, CaseIterable {
    case deadTree
    case deadTreeSmall
    case gravestone
    case graveCross
    case ruinedPillar
    case ruinedWall
    case brokenCart
    case campfire
    case oldShrine
    case rock
    case grassTuft
    case bones
}

/// How a decoration is layered.
enum DecorationLayer: String, Codable {
    /// Lies on the ground; always drawn beneath standing objects.
    case groundDecal
    /// Stands up out of the ground; depth-sorted with characters.
    case standing
}

enum DecorationAnimation: String, Codable {
    case none
    /// Flame-like pulsing plus an additive glow.
    case flicker
    /// Faint pulsing glow for magical landmarks.
    case pulse
}

/// Presentation and footprint data for one decoration kind.
struct DecorationSpec: Equatable {
    let kind: DecorationKind
    let spriteID: SpriteID
    let layer: DecorationLayer
    /// World-unit radius used to keep decorations from overlapping.
    let footprintRadius: CGFloat
    /// Reserved for Phase 2 obstacle collision. Nothing blocks yet.
    let blocksMovement: Bool
    let animation: DecorationAnimation
    let scaleRange: ClosedRange<CGFloat>
}

enum DecorationCatalog {
    static func spec(for kind: DecorationKind) -> DecorationSpec {
        switch kind {
        case .deadTree:
            return DecorationSpec(kind: kind, spriteID: .decorDeadTree, layer: .standing,
                                  footprintRadius: 1.1, blocksMovement: true, animation: .none,
                                  scaleRange: 0.85...1.2)
        case .deadTreeSmall:
            return DecorationSpec(kind: kind, spriteID: .decorDeadTreeSmall, layer: .standing,
                                  footprintRadius: 0.7, blocksMovement: false, animation: .none,
                                  scaleRange: 0.8...1.1)
        case .gravestone:
            return DecorationSpec(kind: kind, spriteID: .decorGravestone, layer: .standing,
                                  footprintRadius: 0.5, blocksMovement: true, animation: .none,
                                  scaleRange: 0.85...1.1)
        case .graveCross:
            return DecorationSpec(kind: kind, spriteID: .decorGraveCross, layer: .standing,
                                  footprintRadius: 0.45, blocksMovement: true, animation: .none,
                                  scaleRange: 0.85...1.1)
        case .ruinedPillar:
            return DecorationSpec(kind: kind, spriteID: .decorRuinedPillar, layer: .standing,
                                  footprintRadius: 0.7, blocksMovement: true, animation: .none,
                                  scaleRange: 0.9...1.25)
        case .ruinedWall:
            return DecorationSpec(kind: kind, spriteID: .decorRuinedWall, layer: .standing,
                                  footprintRadius: 1.2, blocksMovement: true, animation: .none,
                                  scaleRange: 0.9...1.1)
        case .brokenCart:
            return DecorationSpec(kind: kind, spriteID: .decorBrokenCart, layer: .standing,
                                  footprintRadius: 1.0, blocksMovement: true, animation: .none,
                                  scaleRange: 0.95...1.05)
        case .campfire:
            return DecorationSpec(kind: kind, spriteID: .decorCampfire, layer: .standing,
                                  footprintRadius: 0.6, blocksMovement: false, animation: .flicker,
                                  scaleRange: 0.9...1.1)
        case .oldShrine:
            return DecorationSpec(kind: kind, spriteID: .decorOldShrine, layer: .standing,
                                  footprintRadius: 1.0, blocksMovement: true, animation: .pulse,
                                  scaleRange: 1.0...1.0)
        case .rock:
            return DecorationSpec(kind: kind, spriteID: .decorRock, layer: .standing,
                                  footprintRadius: 0.5, blocksMovement: false, animation: .none,
                                  scaleRange: 0.6...1.3)
        case .grassTuft:
            return DecorationSpec(kind: kind, spriteID: .decorGrassTuft, layer: .groundDecal,
                                  footprintRadius: 0.3, blocksMovement: false, animation: .none,
                                  scaleRange: 0.7...1.3)
        case .bones:
            return DecorationSpec(kind: kind, spriteID: .decorBones, layer: .groundDecal,
                                  footprintRadius: 0.4, blocksMovement: false, animation: .none,
                                  scaleRange: 0.8...1.1)
        }
    }
}

/// One placed decoration in a generated arena.
struct DecorationPlacement: Equatable {
    let kind: DecorationKind
    /// Wrapped world position of the object's base.
    let position: CGPoint
    let scale: CGFloat
    /// Mirror horizontally for variety without extra art.
    let mirrored: Bool
}
