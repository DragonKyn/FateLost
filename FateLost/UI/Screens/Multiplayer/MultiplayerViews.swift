import SwiftUI
import UIKit

// MARK: - Shared pieces

/// A labelled text field in the game's own style.
private struct FLField<Field: View>: View {
    let label: String
    var caption: String?
    @ViewBuilder let field: () -> Field

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            FLSectionLabel(text: label)
            field()
                .font(FLTheme.Typeface.body(17))
                .foregroundStyle(FLTheme.Palette.parchment)
                .padding(.horizontal, 12)
                .frame(minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(FLTheme.Palette.abyss))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(FLTheme.Palette.rim.opacity(0.8), lineWidth: 1))
            if let caption {
                Text(caption)
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A small pill: HOST, READY, NOT READY, OFFLINE.
private struct StatusChip: View {
    enum Tone {
        case host
        case ready
        case waiting
        case offline
    }

    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(1)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(background))
    }

    private var foreground: Color {
        switch tone {
        case .host: return FLTheme.Palette.abyss
        case .ready: return FLTheme.Palette.abyss
        case .waiting: return FLTheme.Palette.parchment
        case .offline: return FLTheme.Palette.parchmentDim
        }
    }

    private var background: Color {
        switch tone {
        case .host: return FLTheme.Palette.emberBright
        case .ready: return Color(red: 0.55, green: 0.82, blue: 0.48)
        case .waiting: return FLTheme.Palette.rim.opacity(0.6)
        case .offline: return FLTheme.Palette.locked.opacity(0.5)
        }
    }
}

/// A notice for the top of a screen: something happened that the player should know.
private struct NoticeBanner: View {
    let text: String
    var systemImage = "exclamationmark.triangle.fill"
    var dismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(FLTheme.Palette.emberBright)
            Text(text)
                .font(FLTheme.Typeface.body(14))
                .foregroundStyle(FLTheme.Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .flPanel(highlighted: true)
    }
}

/// Asks for the name shown in parties. Used the first time multiplayer is
/// opened, and whenever the player wants to change it.
private struct NameSheet: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void = {}

    @State private var text = ""
    @State private var showsProblem = false

    private var isValid: Bool { DisplayName.isValid(text) }

    var body: some View {
        ZStack {
            FLTheme.Palette.abyss.ignoresSafeArea()
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your name")
                        .font(FLTheme.Typeface.title(26))
                        .foregroundStyle(FLTheme.Palette.parchment)
                    Text("This is what your party sees. It is not unique, and you can change it whenever you like.")
                        .font(FLTheme.Typeface.body(14))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Up to \(DisplayName.maxLength) characters, all of them visible.")
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    FLField(label: "Name", caption: showsProblem && !isValid ? "That name cannot be used." : nil) {
                        TextField("Wanderer", text: $text)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(save)
                    }
                    Button("Save Name", action: save)
                        .buttonStyle(.flPrimary)
                        .disabled(text.isEmpty)
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.flSecondaryCompact)
                }
                .frame(width: 320)
            }
            .padding(FLTheme.Metrics.screenPadding)
        }
        .onAppear { text = services.multiplayer.suggestedName }
        .presentationDetents([.large])
    }

    private func save() {
        guard services.multiplayer.setDisplayName(text) else {
            showsProblem = true
            return
        }
        services.haptics.play(.uiTap)
        onSaved()
        dismiss()
    }
}

// MARK: - The menu

struct MultiplayerMenuView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var namePrompt: NamePromptPurpose?

    private enum NamePromptPurpose: Identifiable {
        case host
        case join
        case change

        var id: Int {
            switch self {
            case .host: return 0
            case .join: return 1
            case .change: return 2
            }
        }
    }

    private var hub: MultiplayerHub { services.multiplayer }
    private var client: PartyClient { hub.client }

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 20)

            VStack(alignment: .leading, spacing: 10) {
                FLScreenHeader(title: "Multiplayer",
                               subtitle: "Share your fate.") {
                    services.audio.play(.uiBack)
                    router.show(.mainMenu)
                }

                if let notice = client.notice {
                    NoticeBanner(text: notice.message) { client.clearNotice() }
                }

                HStack(alignment: .top, spacing: 24) {
                    identityPanel
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        if client.isInParty {
                            returnButton
                        }
                        Button("Host Game") {
                            begin(.host)
                        }
                        .buttonStyle(.flPrimary)

                        Button("Join Game") {
                            begin(.join)
                        }
                        .buttonStyle(.flSecondary)
                    }
                    .frame(width: 280)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
            .padding(.vertical, FLTheme.Metrics.screenPaddingVertical)
        }
        .sheet(item: $namePrompt) { purpose in
            NameSheet {
                switch purpose {
                case .host: router.show(.hostGame)
                case .join: router.show(.joinGame)
                case .change: break
                }
            }
        }
        .onAppear { hub.resumeIfPossible() }
    }

    private func begin(_ purpose: NamePromptPurpose) {
        services.haptics.play(.uiTap)
        services.audio.play(.uiConfirm)
        client.clearNotice()
        if hub.displayName == nil {
            // The first time, ask who they are.
            namePrompt = purpose
        } else {
            router.show(purpose == .host ? .hostGame : .joinGame)
        }
    }

    private var identityPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HeroPortrait(look: services.hero, height: 74)
                VStack(alignment: .leading, spacing: 3) {
                    FLSectionLabel(text: "Your name")
                    Text(hub.displayName ?? "Not chosen yet")
                        .font(FLTheme.Typeface.heading(24))
                        .foregroundStyle(hub.displayName == nil ? FLTheme.Palette.parchmentDim : FLTheme.Palette.parchment)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Button("Change name") {
                        services.haptics.play(.uiTap)
                        namePrompt = .change
                    }
                    .font(FLTheme.Typeface.body(13))
                    .foregroundStyle(FLTheme.Palette.emberBright)
                }
            }

            Divider().overlay(FLTheme.Palette.rim.opacity(0.5))

            VStack(alignment: .leading, spacing: 4) {
                FLSectionLabel(text: "Fate ID")
                Text(hub.identity.fateID)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(FLTheme.Palette.parchment)
                Text("A label for this installation, safe to share when asking for help. It cannot be used to join as you.")
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .flPanel()
    }

    private var returnButton: some View {
        Button {
            services.haptics.play(.uiTap)
            services.audio.play(.uiConfirm)
            if client.room != nil {
                router.show(.lobby)
            }
        } label: {
            VStack(spacing: 2) {
                Text("Return to Your Party")
                if let code = client.room?.code {
                    Text(RoomCode.spaced(code))
                        .font(FLTheme.Typeface.number(13))
                } else {
                    Text("Reconnecting…")
                        .font(FLTheme.Typeface.body(12))
                }
            }
        }
        .buttonStyle(.flPrimaryCompact)
        .disabled(client.room == nil)
    }
}

// MARK: - Hosting

struct HostGameView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var password = ""
    @State private var busy = false
    @State private var problem: String?

    private var hub: MultiplayerHub { services.multiplayer }

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 20)

            VStack(alignment: .leading, spacing: 10) {
                FLScreenHeader(title: "Host a Game",
                               subtitle: "You get a six-character code to share. There is no public list.") {
                    services.audio.play(.uiBack)
                    router.show(.multiplayer)
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            HeroPortrait(look: services.hero, height: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                FLSectionLabel(text: "Playing as")
                                Text(hub.displayName ?? "")
                                    .font(FLTheme.Typeface.heading(20))
                                    .foregroundStyle(FLTheme.Palette.parchment)
                            }
                        }
                        FLField(label: "Password (optional)",
                                caption: "Leave it empty for an open party: anyone with the code can join. A password is stored only as a salted hash.") {
                            SecureField("No password", text: $password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: password) { _, value in
                                    if value.count > PartyProtocol.passwordMaxLength {
                                        password = String(value.prefix(PartyProtocol.passwordMaxLength))
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(spacing: 12) {
                        if let problem {
                            NoticeBanner(text: problem)
                        }
                        Button {
                            create()
                        } label: {
                            if busy {
                                ProgressView().tint(FLTheme.Palette.abyss)
                            } else {
                                Text("Create Party")
                            }
                        }
                        .buttonStyle(.flPrimary)
                        .disabled(busy)
                    }
                    .frame(width: 300)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
            .padding(.vertical, FLTheme.Metrics.screenPaddingVertical)
        }
    }

    private func create() {
        services.haptics.play(.uiTap)
        services.audio.play(.uiConfirm)
        busy = true
        problem = nil
        Task {
            do {
                try await hub.host(password: password.isEmpty ? nil : password)
            } catch let error as PartyError {
                problem = error.message
            } catch {
                problem = PartyError.network.message
            }
            busy = false
        }
    }
}

// MARK: - Joining

struct JoinGameView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var code = ""
    @State private var password = ""
    @State private var needsPassword = false
    @State private var busy = false
    @State private var problem: String?
    @FocusState private var codeFocused: Bool

    private var hub: MultiplayerHub { services.multiplayer }
    private var normalisedCode: String? { RoomCode.normalise(code) }

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 20)

            VStack(alignment: .leading, spacing: 10) {
                FLScreenHeader(title: "Join a Game",
                               subtitle: "Ask the host for their six-character code.") {
                    services.audio.play(.uiBack)
                    router.show(.multiplayer)
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 14) {
                        FLField(label: "Party code") {
                            TextField("F7K 2Q9", text: $code)
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .focused($codeFocused)
                                .onChange(of: code) { _, value in
                                    let filtered = value.uppercased().filter { character in
                                        PartyProtocol.roomCodeAlphabet.contains(character)
                                    }
                                    let trimmed = String(filtered.prefix(PartyProtocol.roomCodeLength))
                                    if trimmed != value { code = trimmed }
                                    problem = nil
                                }
                        }
                        if needsPassword {
                            FLField(label: "Password", caption: "This party is protected.") {
                                SecureField("Password", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(spacing: 12) {
                        if let problem {
                            NoticeBanner(text: problem)
                        }
                        Button {
                            join()
                        } label: {
                            if busy {
                                ProgressView().tint(FLTheme.Palette.abyss)
                            } else {
                                Text("Join Party")
                            }
                        }
                        .buttonStyle(.flPrimary)
                        .disabled(busy || normalisedCode == nil)
                    }
                    .frame(width: 300)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
            .padding(.vertical, FLTheme.Metrics.screenPaddingVertical)
        }
        .onAppear { codeFocused = true }
    }

    private func join() {
        guard let target = normalisedCode else {
            problem = PartyError.invalidCode.message
            return
        }
        services.haptics.play(.uiTap)
        services.audio.play(.uiConfirm)
        busy = true
        problem = nil
        Task {
            do {
                try await hub.join(code: target, password: password.isEmpty ? nil : password)
            } catch let error as PartyError {
                if error == .passwordRequired {
                    needsPassword = true
                    problem = "This party needs a password."
                } else {
                    problem = error.message
                }
            } catch {
                problem = PartyError.network.message
            }
            busy = false
        }
    }
}

// MARK: - The lobby

struct LobbyView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var confirmingClose = false
    @State private var copied = false

    private var hub: MultiplayerHub { services.multiplayer }
    private var client: PartyClient { hub.client }

    var body: some View {
        ZStack {
            EmberBackground(emberCount: 16)

            VStack(alignment: .leading, spacing: 8) {
                header

                if let banner = connectionBanner {
                    NoticeBanner(text: banner.text, systemImage: banner.icon)
                }
                if let error = client.lastError {
                    NoticeBanner(text: error.message) { client.clearError() }
                }

                if let room = client.room {
                    HStack(alignment: .top, spacing: 16) {
                        infoColumn(room)
                            .frame(width: 250)
                        memberColumn(room)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                } else {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView("Finding your party…").tint(FLTheme.Palette.ember)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, FLTheme.Metrics.screenPadding)
            .padding(.vertical, FLTheme.Metrics.screenPaddingVertical)
        }
        .alert("Close this lobby?", isPresented: $confirmingClose) {
            Button("Close Lobby", role: .destructive) {
                hub.leaveParty(closing: true)
            }
            Button("Keep It Open", role: .cancel) {}
        } message: {
            Text("Everyone is sent back to the menu and the code stops working.")
        }
        .onChange(of: client.state) { _, state in
            if state == .idle, !client.isInParty { router.show(.multiplayer) }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 12) {
            Text("Party Lobby")
                .font(FLTheme.Typeface.title(26))
                .foregroundStyle(FLTheme.Palette.parchment)
            Spacer()
            if let room = client.room {
                Text(room.runNumber == 0 ? "No runs yet" : "Run \(room.runNumber) done")
                    .font(FLTheme.Typeface.label(12))
                    .tracking(1.5)
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
        }
    }

    private var connectionBanner: (text: String, icon: String)? {
        switch client.state {
        case .connecting:
            return ("Connecting…", "antenna.radiowaves.left.and.right")
        case .reconnecting(let attempt):
            return ("Connection lost. Reconnecting (try \(attempt))…", "arrow.triangle.2.circlepath")
        case .failed(let error):
            return (error.message, "wifi.exclamationmark")
        default:
            if let until = client.hostAwayUntil, client.room?.phase == .lobby {
                _ = until
                return ("The host has dropped out. Waiting for them to return.", "person.fill.questionmark")
            }
            return nil
        }
    }

    private func infoColumn(_ room: LobbyRoom) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    FLSectionLabel(text: "Party code")
                    Text(RoomCode.spaced(room.code))
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(FLTheme.Palette.emberBright)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityLabel("Party code \(room.code.map(String.init).joined(separator: " "))")
                    if room.hasPassword {
                        Label("Password protected", systemImage: "lock.fill")
                            .font(FLTheme.Typeface.body(12))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                    }
                    HStack(spacing: 8) {
                        Button {
                            UIPasteboard.general.string = room.code
                            services.haptics.play(.uiTap)
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(1.6))
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Copied" : "Copy Code", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.flSecondaryCompact)

                        ShareLink(item: "Join my Fate Lost party! Code: \(room.code)") {
                            Label("Invite", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.flSecondaryCompact)
                    }
                }
                .padding(12)
                .flPanel()

                realmPanel(room)
                weaponPanel
                lastRunPanel(room)
            }
        }
    }

    private func realmPanel(_ room: LobbyRoom) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FLSectionLabel(text: "Realm")
            let unlocked = RealmCatalog.all.filter { services.isRealmUnlocked($0) }
            if client.isHost {
                Menu {
                    ForEach(unlocked) { realm in
                        Button(realm.name) { client.setRealm(realm.id.rawValue) }
                    }
                } label: {
                    HStack {
                        Text(realmName(room.realm))
                            .font(FLTheme.Typeface.heading(17))
                            .foregroundStyle(FLTheme.Palette.parchment)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(FLTheme.Palette.parchmentDim)
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(FLTheme.Palette.abyss))
                }
            } else {
                Text(realmName(room.realm))
                    .font(FLTheme.Typeface.heading(17))
                    .foregroundStyle(FLTheme.Palette.parchment)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flPanel()
    }

    private func realmName(_ raw: String) -> String {
        RealmID(rawValue: raw).map { RealmCatalog.realm($0).name } ?? raw
    }

    /// The weapon this player brings, chosen from a menu like the realm's: one
    /// clear card showing what is held, rather than a strip of small tiles.
    private var weaponPanel: some View {
        let chosen = StarterWeapons.definition(for: hub.partyWeaponID) ?? StarterWeapons.sword
        return VStack(alignment: .leading, spacing: 6) {
            FLSectionLabel(text: "Your weapon")
            Menu {
                ForEach(hub.availableWeapons) { weapon in
                    Button {
                        services.haptics.play(.uiTap)
                        hub.partyWeaponID = weapon.id
                    } label: {
                        Label(weapon.name, systemImage: WeaponGlyph.symbol(for: weapon))
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    WeaponIcon(weapon: chosen, size: 34)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(FLTheme.Palette.abyss.opacity(0.8)))
                        .overlay(Circle().strokeBorder(FLTheme.Palette.ember, lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(chosen.name)
                            .font(FLTheme.Typeface.heading(17))
                            .foregroundStyle(FLTheme.Palette.parchment)
                            .lineLimit(1)
                        Text(chosen.damageType.displayName)
                            .font(FLTheme.Typeface.label(11))
                            .tracking(1.5)
                            .foregroundStyle(FLTheme.Palette.emberBright)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 10).fill(FLTheme.Palette.abyss))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(FLTheme.Palette.rim.opacity(0.6), lineWidth: 1))
            }
            .accessibilityLabel("Your weapon: \(chosen.name). Tap to change.")
            Text(chosen.summary)
                .font(FLTheme.Typeface.body(12))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flPanel()
    }

    @ViewBuilder
    private func lastRunPanel(_ room: LobbyRoom) -> some View {
        if let last = room.lastRun {
            VStack(alignment: .leading, spacing: 4) {
                FLSectionLabel(text: "Last run")
                Text(PartyRunSummary.headline(for: last))
                    .font(FLTheme.Typeface.heading(16))
                    .foregroundStyle(FLTheme.Palette.parchment)
                if let detail = PartyRunSummary.detail(for: last) {
                    Text(detail)
                        .font(FLTheme.Typeface.body(12))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .flPanel()
        }
    }

    private func memberColumn(_ room: LobbyRoom) -> some View {
        VStack(spacing: 8) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(0..<room.maxPlayers, id: \.self) { slot in
                        if let member = room.members.first(where: { $0.slot == slot }) {
                            memberRow(member, room: room)
                        } else {
                            openSlot
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            actions(room)
        }
    }

    private func memberRow(_ member: LobbyMember, room: LobbyRoom) -> some View {
        let isMe = member.id == client.myID
        return HStack(spacing: 10) {
            HeroPortrait(look: PartyLoadout.appearance(from: member.hero), height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(member.name + (isMe ? " (you)" : ""))
                    .font(FLTheme.Typeface.heading(17))
                    .foregroundStyle(FLTheme.Palette.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(StarterWeapons.definition(for: member.weapon)?.name ?? "")
                    .font(FLTheme.Typeface.body(11))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
            Spacer(minLength: 4)
            if member.host {
                StatusChip(text: "HOST", tone: .host)
            }
            if !member.connected {
                StatusChip(text: "OFFLINE", tone: .offline)
            } else if !member.host {
                StatusChip(text: member.ready ? "READY" : "NOT READY", tone: member.ready ? .ready : .waiting)
            }
            if client.isHost, !member.host {
                Button {
                    services.haptics.play(.uiTap)
                    client.kick(member.id)
                } label: {
                    Image(systemName: "person.fill.xmark")
                        .font(.system(size: 14))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Remove \(member.name)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .flPanel(highlighted: isMe)
    }

    private var openSlot: some View {
        HStack {
            Image(systemName: "person.badge.plus")
                .foregroundStyle(FLTheme.Palette.locked)
            Text("OPEN SLOT")
                .font(FLTheme.Typeface.label(13))
                .tracking(2)
                .foregroundStyle(FLTheme.Palette.locked)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(RoundedRectangle(cornerRadius: FLTheme.Metrics.cornerRadius, style: .continuous)
            .strokeBorder(FLTheme.Palette.locked.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }

    @ViewBuilder
    private func actions(_ room: LobbyRoom) -> some View {
        if client.isHost {
            VStack(spacing: 6) {
                if let blocker = client.startBlocker {
                    Text(blocker)
                        .font(FLTheme.Typeface.body(13))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
                HStack(spacing: 8) {
                    Button("Start Run") {
                        services.haptics.play(.uiTap)
                        services.audio.play(.uiConfirm)
                        hub.pushLoadout()
                        client.startRun()
                    }
                    .buttonStyle(.flPrimary)
                    .disabled(!client.canStart)

                    Button("Leave") {
                        services.audio.play(.uiBack)
                        hub.leaveParty()
                    }
                    .buttonStyle(.flSecondaryCompact)
                    .frame(width: 92)

                    Button("Close") {
                        confirmingClose = true
                    }
                    .buttonStyle(FLButtonStyle(kind: .destructive, compact: true))
                    .frame(width: 92)
                }
            }
        } else {
            let ready = client.me?.ready ?? false
            HStack(spacing: 8) {
                Button(ready ? "Not Ready" : "Ready") {
                    services.haptics.play(.uiTap)
                    services.audio.play(.uiConfirm)
                    hub.pushLoadout()
                    client.setReady(!ready)
                }
                .buttonStyle(ready ? FLButtonStyle(kind: .secondary) : FLButtonStyle(kind: .primary))

                Button("Leave") {
                    services.audio.play(.uiBack)
                    hub.leaveParty()
                }
                .buttonStyle(.flSecondaryCompact)
                .frame(width: 110)
            }
        }
    }
}

/// How a finished run is worded in the lobby.
enum PartyRunSummary {
    static func headline(for run: LobbyRoom.LastRun) -> String {
        switch run.outcome {
        case "conquered": return "Realm conquered"
        case "defeated": return "The party fell"
        case "aborted":
            if run.summary?["reason"]?.stringValue == "hostLost" { return "The host was lost" }
            if run.summary?["reason"]?.stringValue == "hostLeft" { return "The host left" }
            return "The run was called off"
        default: return "Run finished"
        }
    }

    static func detail(for run: LobbyRoom.LastRun) -> String? {
        guard let summary = run.summary, let wave = summary["wave"]?.intValue else { return nil }
        var parts = ["Wave \(wave)"]
        if let seconds = summary["secondsSurvived"]?.intValue {
            parts.append(String(format: "%d:%02d", seconds / 60, seconds % 60))
        }
        if let kills = summary["kills"]?.intValue {
            parts.append("\(kills) slain")
        }
        return parts.joined(separator: " · ")
    }
}
