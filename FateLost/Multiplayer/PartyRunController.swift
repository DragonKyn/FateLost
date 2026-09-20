import Foundation
import Observation

/// One multiplayer run as this phone plays it. Placeholder until the run
/// netcode lands; the hub already drives it through this surface.
@MainActor
@Observable
final class PartyRunController {
    let info: RunStartInfo
    var runID: String { info.runId }

    @ObservationIgnored private weak var hub: MultiplayerHub?
    @ObservationIgnored private weak var services: AppServices?

    init(info: RunStartInfo, hub: MultiplayerHub, services: AppServices) {
        self.info = info
        self.hub = hub
        self.services = services
    }

    func resumed(_ info: RunStartInfo) {}
    func serviceEndedRun(_ info: RunEndInfo) {}
    func stop() {}
}
