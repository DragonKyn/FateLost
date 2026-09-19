import SwiftUI

/// Animated menu backdrop: a dark vignette with embers drifting upward.
///
/// Drawn with `Canvas` inside a `TimelineView`, so it is one lightweight view
/// rather than dozens of animated subviews. Ember paths are a pure function
/// of time, so there is no state to manage.
struct EmberBackground: View {
    var emberCount = 42

    var body: some View {
        ZStack {
            FLTheme.Palette.abyss
            RadialGradient(
                colors: [FLTheme.Palette.blood.opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: 1.1), startRadius: 20, endRadius: 520
            )
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for index in 0..<emberCount {
                        drawEmber(index: index, time: time, size: size, in: &context)
                    }
                }
            }
            RadialGradient(colors: [.clear, .black.opacity(0.75)], center: .center,
                           startRadius: 180, endRadius: 700)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func drawEmber(index: Int, time: TimeInterval, size: CGSize, in context: inout GraphicsContext) {
        // Per-ember constants derived from its index: stable, no RNG state.
        let width = Double(size.width)
        let height = Double(size.height)
        let seed = Double(index) * 12.9898
        let speed = 18 + fract(sin(seed) * 43758.5453) * 34
        let period = (height + 60) / speed
        let offset = fract(sin(seed * 1.7) * 23421.631) * period
        let progress = fract((time + offset) / period)
        let baseX = fract(sin(seed * 3.1) * 9631.17) * width
        let sway = sin(time * 0.9 + seed) * 14
        let x = baseX + sway
        let y = height + 30 - progress * (height + 60)
        let radius = 0.8 + fract(sin(seed * 5.3) * 1234.5) * 1.8
        let fade = sin(progress * .pi)

        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect.insetBy(dx: -radius * 2, dy: -radius * 2)),
                     with: .color(FLTheme.Palette.ember.opacity(0.12 * fade)))
        context.fill(Path(ellipseIn: rect), with: .color(FLTheme.Palette.emberBright.opacity(0.8 * fade)))
    }

    private func fract(_ value: Double) -> Double {
        value - floor(value)
    }
}
