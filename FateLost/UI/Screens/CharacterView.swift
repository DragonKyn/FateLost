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
        case companions = "Allies"

        var id: String { rawValue }
    }

    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var page: Page = .body
    @State private var breathing = false
    /// A locked option selected to be tried on and, if wanted, bought.
    @State private var inspected: HeroOption?

    @State private var selectedCompanion: CompanionTarget = .bearForm
    /// A locked companion option selected to be tried on and, if wanted, bought.
    @State private var inspectedCompanion: CompanionOption?

    private var look: HeroAppearance { services.hero }

    /// What the preview shows: the chosen look, or that look with the
    /// selected locked option tried on.
    private var shownLook: HeroAppearance {
        inspected?.applying(to: look) ?? look
    }

    private var companionLook: CompanionLook { services.hero.companions[selectedCompanion] }

    /// What the companion preview shows: the saved look, or that look with
    /// the selected locked option tried on — the same rule the hero's own
    /// preview follows.
    private var shownCompanionLook: CompanionLook {
        guard let inspectedCompanion, inspectedCompanion.target == selectedCompanion else { return companionLook }
        return inspectedCompanion.applying(to: companionLook)
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
                            inspectedCompanion = nil
                        }

                        ScrollView(.vertical, showsIndicators: false) {
                            content
                                .padding(.bottom, 8)
                        }

                        // Pinned below the scroll, never buried by it: a
                        // player should never have to hunt for the button
                        // that spends their echoes.
                        if let option = inspected {
                            unlockBar(for: option)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if let option = inspectedCompanion {
                            unlockBar(for: option)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
            .padding(.vertical, FLTheme.Metrics.screenPaddingVertical)
        }
        .animation(.easeOut(duration: 0.16), value: inspected)
        .animation(.easeOut(duration: 0.16), value: inspectedCompanion)
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

    @ViewBuilder
    private var preview: some View {
        if page == .companions {
            companionPreview
        } else {
            heroPreview
        }
    }

    private var heroPreview: some View {
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

    private var companionPreview: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(RadialGradient(colors: [Color.black.opacity(0.6), .clear],
                                         center: .center, startRadius: 0, endRadius: 60))
                    .frame(width: 130, height: 26)
                    .offset(y: -6)
                if let sprite = PlaceholderArt.sprite(for: selectedCompanion.sprite) {
                    Image(uiImage: sprite.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 130 * shownCompanionScale)
                        .colorMultiply(shownCompanionTintColor)
                        .offset(y: breathing ? -3 : 0)
                        .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: breathing)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 210)
            .flPanel(highlighted: inspectedCompanion != nil)

            VStack(spacing: 2) {
                Text(selectedCompanion.name)
                    .font(FLTheme.Typeface.heading(16))
                    .foregroundStyle(FLTheme.Palette.parchment)
                Text(shownAppearance.name)
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
        }
    }

    private var shownAppearance: CompanionAppearanceOption {
        CompanionAppearanceCatalog.option(shownCompanionLook.appearanceID ?? "base", for: selectedCompanion)
    }

    private var shownCompanionScale: CGFloat {
        CGFloat(selectedCompanion.catalogueScale * shownCompanionLook.scale.multiplier)
    }

    private var shownCompanionTintColor: Color {
        guard let id = shownAppearance.tint else { return .white }
        return Color(uiColor: UIColor(rgb: HeroPalette.swatch(id, in: HeroPalette.trim).hex))
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
        case .companions: companionsSection
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
            extraSection("Eyewear", HeroUnlocks.eyewear)
        }
    }

    private func extraSection(_ title: String, _ options: [HeroOption]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FLSectionLabel(text: title.uppercased())
            optionGrid(options)
        }
    }

    // MARK: Companions

    private var companionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            companionTargetPicker

            VStack(alignment: .leading, spacing: 2) {
                Text("Editing \(selectedCompanion.name)")
                    .font(FLTheme.Typeface.heading(15))
                    .foregroundStyle(FLTheme.Palette.parchment)
                Text(selectedCompanion.blurb)
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }

            companionOptionSection("APPEARANCE", CompanionUnlocks.appearances(for: selectedCompanion))
            companionOptionSection("SIZE", CompanionUnlocks.scales(for: selectedCompanion)
                .filter { if case .scale(_, .standard) = $0 { return false } else { return true } })
            companionOptionSection("EXTRA", CompanionUnlocks.extras(for: selectedCompanion)
                .filter { if case .extra(_, .none) = $0 { return false } else { return true } })
        }
    }

    /// Every companion or form, as a row of chips: which one is being
    /// edited is always in view, and switching is one tap away.
    private var companionTargetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CompanionTarget.allCases) { target in
                    Button {
                        services.haptics.play(.uiTap)
                        selectedCompanion = target
                        inspectedCompanion = nil
                    } label: {
                        Text(target.name)
                            .font(FLTheme.Typeface.label(12))
                            .foregroundStyle(target == selectedCompanion
                                             ? FLTheme.Palette.emberBright : FLTheme.Palette.parchment)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .flPanel(highlighted: target == selectedCompanion)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private func companionOptionSection(_ title: String, _ options: [CompanionOption]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FLSectionLabel(text: title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(options) { option in
                    CompanionOptionCard(target: selectedCompanion, option: option,
                                        isEquipped: option.isWorn(by: companionLook),
                                        isInspected: inspectedCompanion == option,
                                        price: price(of: option))
                        .onTapGesture { chooseCompanion(option) }
                }
            }
        }
    }

    /// The price of a companion option the player does not yet own, if any.
    private func price(of option: CompanionOption) -> Int? {
        services.owns(option) ? nil : CompanionUnlocks.cost(of: option)
    }

    /// Wears an option that is owned, and selects one that is not so it can
    /// be tried on — the same rule the hero's own wardrobe follows. Tapping
    /// an already-equipped size or extra a second time takes it back off.
    private func chooseCompanion(_ option: CompanionOption) {
        services.haptics.play(.uiTap)
        if option.isWorn(by: companionLook), let fallback = option.fallback {
            services.audio.play(.uiConfirm)
            applyCompanion(fallback.applying(to: companionLook))
            inspectedCompanion = nil
        } else if services.owns(option) {
            services.audio.play(.uiConfirm)
            applyCompanion(option.applying(to: companionLook))
            inspectedCompanion = nil
        } else {
            inspectedCompanion = option
        }
    }

    private func applyCompanion(_ next: CompanionLook) {
        var hero = services.hero
        hero.companions[selectedCompanion] = next
        services.setHero(hero)
    }

    private func purchaseCompanion(_ option: CompanionOption) {
        guard services.buyCompanion(option) else { return }
        services.haptics.play(.uiTap)
        services.audio.play(.uiConfirm)
        applyCompanion(option.applying(to: companionLook))
        inspectedCompanion = nil
    }

    /// The same shape as the hero wardrobe's own unlock bar.
    private func unlockBar(for option: CompanionOption) -> some View {
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
            Button("Unlock · \(CompanionUnlocks.cost(of: option))") { purchaseCompanion(option) }
                .buttonStyle(.flPrimaryCompact)
                .disabled(denial != nil)
                .frame(width: 150)
            Button {
                inspectedCompanion = nil
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

    // MARK: Colours

    private var colours: some View {
        VStack(alignment: .leading, spacing: 14) {
            swatches("Cloak", HeroPalette.cloak, options: HeroUnlocks.cloakColours, selected: look.cloakColor)
            swatches("Trim", HeroPalette.trim, options: HeroUnlocks.trimColours, selected: look.trimColor)
            swatches("Eyes", HeroPalette.eyes, options: HeroUnlocks.eyeColours, selected: look.eyeColor)
            if [.bare, .wizardHat, .bandana, .cowboyHat].contains(look.head) {
                skinAndHair
            } else {
                Text("Skin and hair are seen with a bare head, a wizard's hat, a bandana or a cowboy hat.")
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

/// One companion option: an appearance (previewed on the real sprite, in
/// its own colour), a size or an extra (a symbol standing in for it, since
/// neither has art of its own). Every card reads the same way the hero's
/// own `OptionCard` does: locked shows a price, owned shows a checkmark,
/// worn is highlighted.
private struct CompanionOptionCard: View {
    let target: CompanionTarget
    let option: CompanionOption
    let isEquipped: Bool
    let isInspected: Bool
    /// Echoes it costs while it is still locked; nil once it is owned.
    let price: Int?

    var body: some View {
        VStack(spacing: 6) {
            thumbnail
                .frame(height: 46)
            Text(option.title)
                .font(FLTheme.Typeface.heading(13))
                .foregroundStyle(isEquipped || isInspected ? FLTheme.Palette.emberBright : FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if isEquipped {
                Label("Equipped", systemImage: "checkmark.seal.fill")
                    .font(FLTheme.Typeface.number(10))
                    .foregroundStyle(FLTheme.Palette.emberBright)
            } else if let price {
                Text("\(price) echoes")
                    .font(FLTheme.Typeface.number(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            } else {
                Text("Owned")
                    .font(FLTheme.Typeface.number(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .flPanel(highlighted: isEquipped || isInspected)
        .opacity(price == nil || isEquipped ? 1 : 0.85)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isEquipped ? .isSelected : [])
    }

    @ViewBuilder private var thumbnail: some View {
        switch option {
        case .appearance(let target, let appearanceID):
            let tint = CompanionAppearanceCatalog.option(appearanceID, for: target).tint
            if let sprite = PlaceholderArt.sprite(for: target.sprite) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: sprite.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorMultiply(tint.map { Color(uiColor: UIColor(rgb: HeroPalette.swatch($0, in: HeroPalette.trim).hex)) } ?? .white)
                    if price != nil, !isEquipped {
                        lockBadge
                    }
                }
            }
        case .scale(_, let scale):
            Image(systemName: scale == .runt ? "arrow.down.right.and.arrow.up.left"
                  : scale == .massive ? "arrow.up.left.and.arrow.down.right" : "circle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isEquipped ? FLTheme.Palette.ember : FLTheme.Palette.parchmentDim)
        case .extra(_, let extra):
            Image(systemName: extra == .banner ? "flag.fill" : "nosign")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isEquipped ? FLTheme.Palette.ember : FLTheme.Palette.parchmentDim)
        }
    }

    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(FLTheme.Palette.parchment)
            .padding(5)
            .background(Circle().fill(Color.black.opacity(0.6)))
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
