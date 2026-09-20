import SwiftUI

/// Choose Your Fate: who walks into the dark.
///
/// The hero is a body, a cloak, a head, colours and extras, and every choice
/// is purely how they look. Nothing here is stronger than anything else. The
/// plainer options are free and the elaborate ones cost echoes, roughly in
/// step with how much they change the figure, so there is always something
/// worth saving toward.
///
/// Buying works the way the rest of Legacy does: select a thing to see it,
/// read what it costs and why it is locked, and press Unlock. A locked option
/// is tried on in the preview first, so a player knows what they are buying.
struct CharacterView: View {
    private enum Page: String, CaseIterable, Identifiable {
        case body = "Body"
        case cloak = "Cloak"
        case head = "Head"
        case colours = "Colours"
        case extras = "Extras"

        var id: String { rawValue }
    }

    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var page: Page = .body
    @State private var breathing = false
    /// A locked option selected to be tried on and, if wanted, bought.
    @State private var inspected: HeroOption?

    private var look: HeroAppearance { services.hero }

    /// What the preview shows: the chosen look, or that look with the
    /// selected locked option tried on.
    private var shownLook: HeroAppearance {
        inspected?.applying(to: look) ?? look
    }

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 20)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    FLScreenHeader(title: "Choose Your Fate",
                                   subtitle: "Who walks into the dark is yours to decide.") {
                        services.audio.play(.uiBack)
                        router.show(.mainMenu)
                    }
                    echoBalance
                }

                HStack(alignment: .top, spacing: 18) {
                    preview
                        .frame(width: 210)

                    VStack(alignment: .leading, spacing: 10) {
                        Picker("", selection: $page) {
                            ForEach(Page.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: page) { _, _ in
                            services.haptics.play(.uiTap)
                            inspected = nil
                        }

                        ScrollView(.vertical, showsIndicators: false) {
                            content
                                .padding(.bottom, 8)
                        }

                        if let option = inspected {
                            unlockBar(for: option)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(FLTheme.Metrics.screenPadding)
        }
        .animation(.easeOut(duration: 0.16), value: inspected)
        .onAppear { breathing = true }
    }

    // MARK: Echoes

    private var echoBalance: some View {
        VStack(spacing: 0) {
            Text("\(services.profile.echoes)")
                .font(FLTheme.Typeface.number(24))
                .foregroundStyle(FLTheme.Palette.emberBright)
            Text("ECHOES")
                .font(FLTheme.Typeface.label(9))
                .tracking(2)
                .foregroundStyle(FLTheme.Palette.parchmentDim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .flPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(services.profile.echoes) echoes to spend")
    }

    // MARK: Buying

    /// The same shape as the Legacy detail panels: what it is, why it is
    /// locked, and a single Unlock button that is disabled until it can work.
    private func unlockBar(for option: HeroOption) -> some View {
        let denial = services.profile.denial(for: option)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(option.title)
                    .font(FLTheme.Typeface.heading(15))
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let denial {
                    Label(denial, systemImage: "lock.fill")
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                } else {
                    Text("Trying it on")
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
            }
            Spacer(minLength: 4)
            Button("Unlock · \(HeroUnlocks.cost(of: option))") { purchase(option) }
                .buttonStyle(.flPrimaryCompact)
                .disabled(denial != nil)
                .frame(width: 150)
            Button {
                inspected = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Stop trying it on")
        }
        .padding(10)
        .flPanel(highlighted: true)
    }

    private func purchase(_ option: HeroOption) {
        guard services.buyLook(option) else { return }
        services.haptics.play(.uiTap)
        services.audio.play(.uiConfirm)
        // Something bought is something wanted: wear it straight away.
        services.setHero(option.applying(to: services.hero))
        inspected = nil
    }

    /// Wears an option that is owned, and selects one that is not so it can
    /// be tried on.
    private func choose(_ option: HeroOption) {
        services.haptics.play(.uiTap)
        if services.owns(option) {
            services.audio.play(.uiConfirm)
            services.setHero(option.applying(to: services.hero))
            inspected = nil
        } else {
            inspected = option
        }
    }

    // MARK: Preview

    private var preview: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(RadialGradient(colors: [Color.black.opacity(0.6), .clear],
                                         center: .center, startRadius: 0, endRadius: 60))
                    .frame(width: 130, height: 26)
                    .offset(y: -6)
                HeroPortrait(look: shownLook, height: 200)
                    .offset(y: breathing ? -3 : 0)
                    .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: breathing)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 210)
            .flPanel(highlighted: inspected != nil)

            HStack(spacing: 8) {
                Button("Random") {
                    services.haptics.play(.uiTap)
                    services.audio.play(.uiConfirm)
                    var generator = SystemRandomNumberGenerator()
                    services.setHero(.random(using: &generator, owns: { services.owns($0) }))
                    inspected = nil
                }
                .buttonStyle(.flSecondaryCompact)
                Button("Reset") {
                    services.haptics.play(.uiTap)
                    services.setHero(.standard)
                    inspected = nil
                }
                .buttonStyle(.flSecondaryCompact)
            }
        }
    }

    // MARK: Options

    @ViewBuilder
    private var content: some View {
        switch page {
        case .body: optionGrid(HeroUnlocks.builds)
        case .cloak: optionGrid(HeroUnlocks.cloaks)
        case .head: optionGrid(HeroUnlocks.heads)
        case .colours: colours
        case .extras: extras
        }
    }

    private func optionGrid(_ options: [HeroOption]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 10) {
            ForEach(options) { option in
                OptionCard(look: option.applying(to: look), name: option.title, blurb: option.blurb,
                           isSelected: option.isWorn(by: look) || inspected == option,
                           price: price(of: option))
                    .onTapGesture { choose(option) }
            }
        }
    }

    /// The price of an option the player does not yet own, if any.
    private func price(of option: HeroOption) -> Int? {
        services.owns(option) ? nil : HeroUnlocks.cost(of: option)
    }

    private var extras: some View {
        VStack(alignment: .leading, spacing: 14) {
            extraSection("Emblem", HeroUnlocks.emblems)
            extraSection("Metalwork", HeroUnlocks.details)
            extraSection("Wings", HeroUnlocks.wings)
        }
    }

    private func extraSection(_ title: String, _ options: [HeroOption]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FLSectionLabel(text: title.uppercased())
            optionGrid(options)
        }
    }

    // MARK: Colours

    private var colours: some View {
        VStack(alignment: .leading, spacing: 14) {
            swatches("Cloak", HeroPalette.cloak, options: HeroUnlocks.cloakColours, selected: look.cloakColor)
            swatches("Trim", HeroPalette.trim, options: HeroUnlocks.trimColours, selected: look.trimColor)
            swatches("Eyes", HeroPalette.eyes, options: HeroUnlocks.eyeColours, selected: look.eyeColor)
            if look.head == .bare || look.head == .wizardHat {
                skinAndHair
            } else {
                Text("Skin and hair are seen with a bare head or a wizard's hat.")
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
        }
    }

    /// Skin and hair are who a player is, so they are always free.
    private var skinAndHair: some View {
        VStack(alignment: .leading, spacing: 14) {
            plainSwatches("Skin", HeroPalette.skin, selected: look.skinTone) { id in
                var next = services.hero
                next.skinTone = id
                services.setHero(next)
            }
            plainSwatches("Hair", HeroPalette.hair, selected: look.hairColor) { id in
                var next = services.hero
                next.hairColor = id
                services.setHero(next)
            }
        }
    }

    private func swatches(_ title: String, _ list: [HeroSwatch], options: [HeroOption],
                          selected: String) -> some View {
        let current = HeroPalette.swatch(selected, in: list)
        return VStack(alignment: .leading, spacing: 6) {
            swatchLabel(title, current.name)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(zip(list, options)), id: \.0.id) { swatch, option in
                    let locked = !services.owns(option)
                    Button { choose(option) } label: {
                        SwatchDot(hex: swatch.hex, isSelected: swatch.id == current.id || inspected == option,
                                  isLocked: locked)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(locked ? "\(swatch.name), locked, \(HeroUnlocks.cost(of: option)) echoes"
                                               : swatch.name)
                    .accessibilityAddTraits(swatch.id == current.id ? .isSelected : [])
                }
            }
        }
    }

    private func plainSwatches(_ title: String, _ list: [HeroSwatch], selected: String,
                               choose: @escaping (String) -> Void) -> some View {
        let current = HeroPalette.swatch(selected, in: list)
        return VStack(alignment: .leading, spacing: 6) {
            swatchLabel(title, current.name)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(list) { swatch in
                    Button {
                        services.haptics.play(.uiTap)
                        choose(swatch.id)
                    } label: {
                        SwatchDot(hex: swatch.hex, isSelected: swatch.id == current.id, isLocked: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch.name)
                    .accessibilityAddTraits(swatch.id == current.id ? .isSelected : [])
                }
            }
        }
    }

    private func swatchLabel(_ title: String, _ name: String) -> some View {
        HStack(spacing: 8) {
            FLSectionLabel(text: title.uppercased())
            Text(name)
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
        }
    }
}

private struct SwatchDot: View {
    let hex: UInt32
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        Circle()
            .fill(Color(uiColor: UIColor(rgb: hex)))
            .frame(width: 32, height: 32)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
            .overlay {
                if isLocked {
                    Circle().fill(Color.black.opacity(0.55))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FLTheme.Palette.parchment)
                }
            }
            .padding(3)
            .overlay(Circle().strokeBorder(isSelected ? FLTheme.Palette.emberBright : Color.clear, lineWidth: 2))
            .frame(width: 40, height: 40)
    }
}

/// One choice, shown as the whole figure wearing it.
private struct OptionCard: View {
    let look: HeroAppearance
    let name: String
    let blurb: String
    let isSelected: Bool
    /// Echoes it costs while it is still locked; nil once it is owned.
    let price: Int?

    var body: some View {
        VStack(spacing: 4) {
            HeroPortrait(look: look, height: 92)
                .opacity(price == nil ? 1 : 0.85)
                .overlay(alignment: .topTrailing) {
                    if let price {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                            Text("\(price)")
                        }
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(FLTheme.Palette.abyss)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(FLTheme.Palette.emberBright))
                    }
                }
            Text(name)
                .font(FLTheme.Typeface.heading(14))
                .foregroundStyle(isSelected ? FLTheme.Palette.emberBright : FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(blurb)
                .font(FLTheme.Typeface.body(11))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .flPanel(highlighted: isSelected)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(price.map { "\(name), locked, \($0) echoes. \(blurb)" } ?? "\(name). \(blurb)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The hero drawn to a given height. Redrawn at a high scale rather than
/// enlarged, so it stays crisp, and remembered, so scrolling through a
/// dozen options does not redraw a dozen figures every frame.
struct HeroPortrait: View {
    let look: HeroAppearance
    let height: CGFloat

    var body: some View {
        Image(uiImage: HeroPortraits.image(for: look))
            .resizable()
            .interpolation(.high)
            .aspectRatio(PlaceholderArt.heroCanvas.width / PlaceholderArt.heroCanvas.height, contentMode: .fit)
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

@MainActor
enum HeroPortraits {
    private static var cache: [HeroAppearance: UIImage] = [:]
    private static let scale: CGFloat = 6

    static func image(for look: HeroAppearance) -> UIImage {
        if let cached = cache[look] { return cached }
        // A player can make far more looks than they will ever view; keep
        // the memory this holds bounded.
        if cache.count > 200 { cache.removeAll(keepingCapacity: true) }
        let image = PlaceholderArt.heroPortrait(look, scale: scale)
        cache[look] = image
        return image
    }
}
