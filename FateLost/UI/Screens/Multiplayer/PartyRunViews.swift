import SwiftUI

/// Everything a party run shows on top of the ordinary HUD: who else is in the
/// fight, that you have fallen, that a friend is near enough to revive, and
/// that the connection needs a moment.
struct PartyRunOverlay: View {
    let session: GameSession

    @Environment(AppServices.self) private var services

    private var hud: GameplayHUDState { session.hud }

    var body: some View {
        ZStack {
            teammates
                .allowsHitTesting(false)

            VStack(spacing: 8) {
                if let note = session.party?.statusNote {
                    banner(note, icon: "antenna.radiowaves.left.and.right")
                }
                if session.party?.contentMismatch == true {
                    banner("Your game and the host's do not match. Update Fate Lost.", icon: "exclamationmark.triangle.fill")
                }
                if hud.isFallen {
                    fallenBanner
                }
                if hud.isClearing {
                    banner("The horde has stopped. Finish the last of them.", icon: "flag.fill")
                }
                restBanner
                Spacer()
                reviveControl
                    .padding(.bottom, 26)
            }
            .padding(.top, 62)
            .frame(maxWidth: .infinity)
        }
        .animation(.easeOut(duration: 0.2), value: hud.reviveTarget)
        .animation(.easeOut(duration: 0.2), value: hud.isFallen)
        .animation(.easeOut(duration: 0.25), value: hud.restSeconds == nil)
        .animation(.easeOut(duration: 0.25), value: hud.isClearing)
    }

    // MARK: Pieces

    /// The other heroes, in a corner: name, and how they are holding up.
    private var teammates: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(hud.party.filter { !$0.isMe }, id: \.slot) { member in
                        HStack(spacing: 6) {
                            Image(systemName: member.isDefeated ? "cross.fill" : "person.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(member.isDefeated ? Color(red: 0.78, green: 0.7, blue: 0.94)
                                                                    : FLTheme.Palette.parchmentDim)
                                .frame(width: 12)
                            Text(member.name)
                                .font(FLTheme.Typeface.body(12))
                                .foregroundStyle(FLTheme.Palette.parchment)
                                .lineLimit(1)
                                .frame(maxWidth: 78, alignment: .leading)
                            HealthBar(current: member.isDefeated ? 0 : member.healthFraction, maximum: 1)
                                .frame(width: 54, height: 7)
                            if !member.isConnected {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                            }
                        }
                        .shadow(color: .black, radius: 2)
                        .opacity(member.isConnected ? 1 : 0.55)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(member.name), \(member.isDefeated ? "fallen" : "\(Int(member.healthFraction * 100)) percent health")")
                    }
                }
                Spacer()
            }
            Spacer()
        }
        .padding(.top, 132)
        .padding(.leading, 20)
    }

    private func banner(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(FLTheme.Palette.emberBright)
            Text(text)
                .font(FLTheme.Typeface.body(13))
                .foregroundStyle(FLTheme.Palette.parchment)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.65)))
        .overlay(Capsule().strokeBorder(FLTheme.Palette.rim, lineWidth: 1))
        .allowsHitTesting(false)
    }

    /// The breather between waves: a countdown, and a way to go on early.
    @ViewBuilder
    private var restBanner: some View {
        if let seconds = hud.restSeconds {
            VStack(spacing: 6) {
                Text("THE HORDE PAUSES")
                    .font(FLTheme.Typeface.title(16))
                    .tracking(4)
                    .foregroundStyle(FLTheme.Palette.parchment)
                Text("Raise the fallen and spend your points. Next wave in \(seconds)s.")
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                Button {
                    services.haptics.play(.uiTap)
                    session.scene.voteToProceed()
                } label: {
                    Text(hud.votedToProceed ? "Waiting for the party \(hud.restVotes)/\(hud.restVoters)"
                                            : "Next Wave \(hud.restVotes)/\(hud.restVoters)")
                }
                .buttonStyle(.flPrimaryCompact)
                .frame(width: 230)
                .disabled(hud.votedToProceed)
                .accessibilityLabel(hud.votedToProceed ? "Waiting for the rest of the party" : "Ready for the next wave")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.6)))
            .transition(.opacity)
        }
    }

    private var fallenBanner: some View {
        VStack(spacing: 4) {
            Text("YOU HAVE FALLEN")
                .font(FLTheme.Typeface.title(20))
                .tracking(4)
                .foregroundStyle(Color(red: 0.86, green: 0.8, blue: 0.97))
            if let progress = hud.beingRevivedProgress {
                ProgressView(value: progress)
                    .tint(Color(red: 0.6, green: 0.9, blue: 0.54))
                    .frame(width: 180)
                Text("A friend is reviving you…")
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchment)
            } else {
                Text(hud.spectating.map { "Watching \($0). A friend can revive you at your marker." }
                     ?? "A friend can revive you at your marker.")
                    .font(FLTheme.Typeface.body(12))
                    .foregroundStyle(FLTheme.Palette.parchmentDim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.6)))
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var reviveControl: some View {
        if let target = hud.reviveTarget, !hud.isFallen {
            if let progress = hud.reviveProgress {
                VStack(spacing: 4) {
                    Text("Reviving \(target)…")
                        .font(FLTheme.Typeface.heading(15))
                        .foregroundStyle(FLTheme.Palette.parchment)
                    ProgressView(value: progress)
                        .tint(Color(red: 0.6, green: 0.9, blue: 0.54))
                        .frame(width: 200)
                    Text("Stay close. Being struck breaks it.")
                        .font(FLTheme.Typeface.body(11))
                        .foregroundStyle(FLTheme.Palette.parchmentDim)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.6)))
                .allowsHitTesting(false)
            } else {
                Button {
                    services.haptics.play(.uiTap)
                    session.scene.pressInteract()
                } label: {
                    Label("Revive \(target)", systemImage: "cross.fill")
                }
                .buttonStyle(.flPrimaryCompact)
                .frame(width: 230)
                .accessibilityLabel("Revive \(target)")
            }
        }
    }
}
