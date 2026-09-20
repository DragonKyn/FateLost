import SwiftUI

/// Fate Lost's visual language for SwiftUI screens.
///
/// Near-black stone, parchment text, and a single ember accent. Titles use a
/// serif face for a tome-like feel; body and numbers stay in the system face
/// for legibility at small sizes.
enum FLTheme {
    enum Palette {
        static let abyss = Color(red: 0.043, green: 0.039, blue: 0.047)
        static let stone = Color(red: 0.094, green: 0.086, blue: 0.098)
        static let stoneRaised = Color(red: 0.13, green: 0.118, blue: 0.13)
        static let rim = Color(red: 0.36, green: 0.31, blue: 0.25)
        static let parchment = Color(red: 0.90, green: 0.86, blue: 0.78)
        static let parchmentDim = Color(red: 0.62, green: 0.58, blue: 0.52)
        static let ember = Color(red: 0.85, green: 0.51, blue: 0.17)
        static let emberBright = Color(red: 1.0, green: 0.70, blue: 0.35)
        static let blood = Color(red: 0.55, green: 0.12, blue: 0.12)
        static let locked = Color(red: 0.35, green: 0.33, blue: 0.33)
    }

    enum Typeface {
        static func title(_ size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .serif)
        }

        static func heading(_ size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .serif)
        }

        static func body(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .regular)
        }

        static func label(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .semibold).smallCaps()
        }

        static func number(_ size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
        }
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 14
        /// Apple's minimum comfortable touch target, with room to spare.
        static let minimumTouchTarget: CGFloat = 52
        static let screenPadding: CGFloat = 24
        /// Top and bottom margin on screens that have to fit a landscape phone,
        /// which is only about 380 points tall once the home indicator is out
        /// of the way. Twenty-four each way was a quarter of what is left.
        static let screenPaddingVertical: CGFloat = 12
    }
}

// MARK: - Buttons

struct FLButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
    }

    var kind: Kind = .primary
    /// Smaller type and padding, for toolbars and tight panels.
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FLTheme.Typeface.heading(compact ? 16 : 19))
            .tracking(compact ? 0.8 : 1.5)
            // Labels shrink a little rather than ever wrapping mid-word.
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 14 : 28)
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : FLTheme.Metrics.minimumTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1.5)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return FLTheme.Palette.abyss
        case .secondary: return FLTheme.Palette.parchment
        case .destructive: return FLTheme.Palette.parchment
        }
    }

    private var fill: AnyShapeStyle {
        switch kind {
        case .primary:
            return AnyShapeStyle(LinearGradient(colors: [FLTheme.Palette.emberBright, FLTheme.Palette.ember],
                                                startPoint: .top, endPoint: .bottom))
        case .secondary:
            return AnyShapeStyle(FLTheme.Palette.stoneRaised.opacity(0.85))
        case .destructive:
            return AnyShapeStyle(FLTheme.Palette.blood.opacity(0.85))
        }
    }

    private var border: Color {
        switch kind {
        case .primary: return FLTheme.Palette.emberBright.opacity(0.6)
        case .secondary: return FLTheme.Palette.rim
        case .destructive: return FLTheme.Palette.blood
        }
    }
}

extension ButtonStyle where Self == FLButtonStyle {
    static var flPrimary: FLButtonStyle { FLButtonStyle(kind: .primary) }
    static var flSecondary: FLButtonStyle { FLButtonStyle(kind: .secondary) }
    static var flDestructive: FLButtonStyle { FLButtonStyle(kind: .destructive) }
    static var flPrimaryCompact: FLButtonStyle { FLButtonStyle(kind: .primary, compact: true) }
    static var flSecondaryCompact: FLButtonStyle { FLButtonStyle(kind: .secondary, compact: true) }
}

// MARK: - Panels

struct FLPanel: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous)
                    .fill(FLTheme.Palette.stone.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(highlighted ? FLTheme.Palette.ember : FLTheme.Palette.rim.opacity(0.7),
                                  lineWidth: highlighted ? 2 : 1)
            )
    }
}

extension View {
    func flPanel(highlighted: Bool = false) -> some View {
        modifier(FLPanel(highlighted: highlighted))
    }
}

/// Small-caps section label.
struct FLSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(FLTheme.Typeface.label(13))
            .tracking(2)
            .foregroundStyle(FLTheme.Palette.parchmentDim)
            // A label is one word on one line: shrink it before it wraps
            // ("DAMAG / E") or is cut short ("DAMA...").
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// Screen header with a back button, used by every sub-menu.
struct FLScreenHeader: View {
    let title: String
    var subtitle: String?
    let onBack: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .frame(width: FLTheme.Metrics.minimumTouchTarget, height: FLTheme.Metrics.minimumTouchTarget)
                    .flPanel()
            }
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FLTheme.Typeface.title(28))
                    .foregroundStyle(FLTheme.Palette.parchment)
                if let subtitle {
                    Text(subtitle)
                        .font(FLTheme.Typeface.body(14))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
            }
            Spacer()
        }
    }
}
