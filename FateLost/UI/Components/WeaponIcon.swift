import SwiftUI
import UIKit

/// A weapon drawn as itself: its own art, tilted the way it is carried,
/// instead of a generic symbol shared by every blade on the rack.
struct WeaponIcon: View {
    let weapon: WeaponDefinition
    /// The square it is fitted into.
    var size: CGFloat = 28

    /// Art is drawn once per weapon and kept.
    @MainActor private static var images: [SpriteID: UIImage] = [:]

    @MainActor
    static func image(for id: SpriteID) -> UIImage? {
        if let cached = images[id] { return cached }
        guard let image = PlaceholderArt.sprite(for: id)?.image else { return nil }
        images[id] = image
        return image
    }

    var body: some View {
        Group {
            if let image = Self.image(for: weapon.spriteID) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .rotationEffect(.degrees(35))
                    .padding(size * 0.04)
            } else {
                Image(systemName: WeaponGlyph.symbol(for: weapon))
                    .font(.system(size: size * 0.7, weight: .semibold))
                    .foregroundStyle(FLTheme.Palette.ember)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
