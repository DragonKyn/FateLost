import UIKit

/// Draws a realm's map for the selection screen.
///
/// This is not an illustration of the realm — it is the realm. The same
/// `ArenaGenerator` that builds the ground you fight on is run at map scale,
/// and its tiles, roads and landmarks are drawn straight out. Two realms look
/// different here for exactly the reason they look different in play: their
/// palettes, road networks and set dressing are not the same.
///
/// Generating is cheap but not free, so results are cached by realm and the
/// work is done off the main actor.
enum RealmMapImage {
    /// Tiles a side. Small enough to generate quickly, large enough that the
    /// terrain noise and roads read as shapes rather than pixels.
    private static let tiles = 72
    /// A fixed seed, so a realm's map is the same every time it is shown.
    private static let seed: UInt64 = 0x5EED_FA7E

    private static let cache = Cache()

    /// A realm's map at the given pixel size, generated once and kept.
    static func image(for realm: RealmDefinition, size: CGSize, scale: CGFloat) -> UIImage? {
        let key = Key(realm: realm.id, width: Int(size.width * scale), height: Int(size.height * scale))
        if let cached = cache.image(for: key) { return cached }
        let layout = ArenaGenerator(
            definition: ArenaDefinition(columns: tiles, rows: tiles, theme: realm.arena.theme),
            seed: seed
        ).generate()
        let image = draw(layout: layout, theme: realm.arena.theme, size: size, scale: scale)
        cache.store(image, for: key)
        return image
    }

    // MARK: - Drawing

    private static func draw(layout: ArenaLayout, theme: ArenaTheme, size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ctx = context.cgContext
            let cellWidth = size.width / CGFloat(layout.columns)
            let cellHeight = size.height / CGFloat(layout.rows)

            // Ground, one filled cell per tile. Cells overlap by a hair so no
            // seam shows between them at fractional sizes.
            for row in 0..<layout.rows {
                for column in 0..<layout.columns {
                    let style = theme.groundStyles[Int(layout.groundStyles[row * layout.columns + column])]
                    ctx.setFillColor(style.base.cgColor)
                    ctx.fill(CGRect(x: CGFloat(column) * cellWidth, y: CGFloat(row) * cellHeight,
                                    width: cellWidth + 0.7, height: cellHeight + 0.7))
                }
            }

            // Landmarks and scattered props, as marks in their own colours.
            // Only standing things are drawn: ground decals would read as noise.
            for placement in layout.decorations {
                let spec = DecorationCatalog.spec(for: placement.kind)
                guard spec.layer == .standing else { continue }
                let point = CGPoint(x: placement.position.x * cellWidth, y: placement.position.y * cellHeight)
                let radius = max(0.6, spec.footprintRadius * cellWidth * 0.55)
                ctx.setFillColor(mark(for: placement.kind).cgColor)
                ctx.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius,
                                           width: radius * 2, height: radius * 2))
            }

            // A cross where a run begins.
            let spawn = CGPoint(x: layout.playerSpawn.x * cellWidth, y: layout.playerSpawn.y * cellHeight)
            ctx.setStrokeColor(UIColor(red: 0.93, green: 0.78, blue: 0.42, alpha: 0.95).cgColor)
            ctx.setLineWidth(max(1, size.width / 90))
            let arm = max(3, size.width / 26)
            ctx.strokeLineSegments(between: [
                CGPoint(x: spawn.x - arm, y: spawn.y), CGPoint(x: spawn.x + arm, y: spawn.y),
                CGPoint(x: spawn.x, y: spawn.y - arm), CGPoint(x: spawn.x, y: spawn.y + arm),
            ])

            // Vignette, so the map sits into the card rather than on it.
            let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.55).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0.45, 1]) {
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                ctx.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                                       endCenter: centre, endRadius: max(size.width, size.height) * 0.72,
                                       options: [])
            }
        }
    }

    /// What colour a prop shows up as from above. Deliberately broad: a map
    /// wants three or four readable kinds of mark, not eighteen.
    private static func mark(for kind: DecorationKind) -> UIColor {
        switch kind {
        case .deadTree, .deadTreeSmall, .bogStump, .forestStump:
            return UIColor(red: 0.17, green: 0.14, blue: 0.10, alpha: 0.9)
        case .pineTree:
            return UIColor(red: 0.13, green: 0.22, blue: 0.14, alpha: 0.95)
        case .reeds, .mushrooms, .grassTuft:
            return UIColor(red: 0.30, green: 0.36, blue: 0.20, alpha: 0.75)
        case .gravestone, .graveCross, .skullPile, .gibbet:
            return UIColor(red: 0.74, green: 0.71, blue: 0.62, alpha: 0.9)
        case .ruinedPillar, .ruinedWall, .brokenStatue, .barricade, .oldShrine:
            return UIColor(red: 0.48, green: 0.46, blue: 0.43, alpha: 0.95)
        case .iceSpire:
            return UIColor(red: 0.78, green: 0.91, blue: 0.96, alpha: 0.95)
        case .obsidianShard, .blackObelisk:
            return UIColor(red: 0.09, green: 0.08, blue: 0.12, alpha: 0.95)
        case .floatingStone:
            return UIColor(red: 0.56, green: 0.44, blue: 0.78, alpha: 0.9)
        case .campfire:
            return UIColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 0.95)
        case .warBanner:
            return UIColor(red: 0.55, green: 0.15, blue: 0.13, alpha: 0.95)
        case .brokenCart, .rock:
            return UIColor(red: 0.35, green: 0.32, blue: 0.28, alpha: 0.85)
        case .plagueBell, .siegeRam:
            return UIColor(red: 0.42, green: 0.32, blue: 0.20, alpha: 0.95)
        case .moltenChain:
            return UIColor(red: 0.89, green: 0.38, blue: 0.10, alpha: 0.95)
        case .brokenStair, .ruinedArch:
            return UIColor(red: 0.58, green: 0.56, blue: 0.52, alpha: 0.95)
        case .hollowThrone:
            return UIColor(red: 0.40, green: 0.28, blue: 0.62, alpha: 0.95)
        default:
            return UIColor(white: 0.3, alpha: 0.8)
        }
    }

    // MARK: - Cache

    private struct Key: Hashable {
        let realm: RealmID
        let width: Int
        let height: Int
    }

    /// A tiny thread-safe cache. Maps are generated off the main actor, so
    /// two cards asking at once must not race.
    private final class Cache: @unchecked Sendable {
        private var storage: [Key: UIImage] = [:]
        private let lock = NSLock()

        func image(for key: Key) -> UIImage? {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }

        func store(_ image: UIImage, for key: Key) {
            lock.lock()
            storage[key] = image
            lock.unlock()
        }
    }
}
