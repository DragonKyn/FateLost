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

            // The breather is one small line at the top edge, out of the fight.
            VStack {
                restPill
                Spacer()
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity)

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
    }

    // MARK: Pieces

    /// The other heroes, in a corner: name, and how they are holding up.
    private var teammates: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(hud.party.filter { !$0.isMe }, id: \.slot) { member in
                        HStack(spacing: 6) {
                            // Their colour: the same as their arrow at the edge of the screen.
                            Image(systemName: member.isDefeated ? "cross.fill" : "circle.fill")
                                .font(.system(size: member.isDefeated ? 10 : 9, weight: .bold))
                                .foregroundStyle(PartyColor.color(slot: member.slot))
                                .overlay {
                                    if !member.isDefeated {
                                        Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1).frame(width: 11, height: 11)
                                    }
                                }
                                .frame(width: 12)
                            Text(member.name)
                                .font(FLTheme.Typeface.body(12))
                                .foregroundStyle(FLTheme.Palette.parchment)
                                .lineLimit(1)
                                .frame(maxWidth: 78, alignment: .leading)
                            HealthBar(current: member.isDefeated ? 0 : member.healthFraction, maximum: 1)
                                .frame(width: 54, height: 7)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(PartyColor.color(slot: member.slot)).frame(width: 3, height: 9).offset(x: -4)
                                }
                            if !member.isConnected {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(FLTheme.Palette.parchmentDim)
                            }
                        }
                        .shadow(color: .black, radius: 2)
                        .opacity(member.isConnected ? 1 : 0.55)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(PartyColor.name(slot: member.slot)), \(member.name), \(member.isDefeated ? "fallen" : "\(Int(member.healthFraction * 100)) percent health")")
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

    /// The breather between waves, as small as it can be: the time left and a
    /// way to go on early. It appears only once the wave's last enemy is down.
    @ViewBuilder
    private var restPill: some View {
        if let seconds = hud.restSeconds {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FLTheme.Palette.emberBright)
                Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                    .font(FLTheme.Typeface.number(13))
                    .foregroundStyle(FLTheme.Palette.parchment)
                Button {
                    services.haptics.play(.uiTap)
                    session.scene.voteToProceed()
                } label: {
                    Text(hud.votedToProceed ? "Waiting \(hud.restVotes)/\(hud.restVoters)"
                                            : "Next wave \(hud.restVotes)/\(hud.restVoters)")
                        .font(FLTheme.Typeface.label(11))
                        .foregroundStyle(hud.votedToProceed ? FLTheme.Palette.parchmentDim : FLTheme.Palette.abyss)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(hud.votedToProceed ? Color.white.opacity(0.1)
                                                                       : FLTheme.Palette.emberBright))
                }
                .buttonStyle(.plain)
                .disabled(hud.votedToProceed)
                .accessibilityLabel(hud.votedToProceed ? "Waiting for the rest of the party" : "Ready for the next wave")
            }
            .padding(.leading, 10)
            .padding(.trailing, 5)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .overlay(Capsule().strokeBorder(FLTheme.Palette.rim.opacity(0.7), lineWidth: 1))
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
