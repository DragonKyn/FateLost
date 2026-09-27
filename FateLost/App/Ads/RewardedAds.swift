import Foundation
import Observation
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// Identifiers for the advert network, in one place.
enum AdConfiguration {
    /// The app as AdMob knows it. Must also be `GADApplicationIdentifier` in
    /// Config/Info.plist, or the SDK stops the app at launch.
    static let applicationID = "ca-app-pub-6085748649825153~2883746766"
    /// The rewarded placement every reward is paid for with.
    static let rewardedUnitID = "ca-app-pub-6085748649825153/6753699855"
    /// Google's own always-fills test unit for rewarded adverts.
    static let testRewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    /// True in any build meant for development or testing: debug builds and
    /// the sideloaded builds with developer tools. Serving live adverts to
    /// yourself while testing is against AdMob policy and can close the
    /// account, so only a store build (neither flag) asks for real ones.
    static var usesTestAds: Bool {
        #if DEBUG || FATELOST_DEVTOOLS
        return true
        #else
        return false
        #endif
    }

    static var activeRewardedUnitID: String {
        usesTestAds ? testRewardedUnitID : rewardedUnitID
    }
}

/// What a request to watch an advert came to.
enum AdOutcome: Equatable {
    /// The SDK confirmed the reward, and the advert has closed.
    case earned
    /// The advert was closed before the reward was earned.
    case closedEarly
    /// No advert could be loaded or shown; the message says why.
    case failed(String)
    /// Another advert is already on screen (a repeated tap): nothing was done.
    case busy
}

/// Every rewarded advert in the game goes through here.
///
/// Loading, showing, dismissal, reward and failure are separate states, and
/// the reward is only ever reported from the SDK's earned-reward callback,
/// once, after the advert has closed. The rest of the game never imports an
/// advert SDK, and a build without it compiles and reports adverts as
/// unavailable.
@MainActor
@Observable
final class RewardedAds {
    enum Phase: Equatable {
        /// Not started yet (consent and the SDK start at launch).
        case idle
        /// Waiting on the consent check or the SDK to start.
        case starting
        /// Adverts cannot be offered: not in this build, or not allowed.
        case unavailable(String)
        /// Fetching an advert.
        case loading
        /// An advert is loaded and can be shown straight away.
        case ready
        /// The last load failed; asking again tries again.
        case loadFailed(String)
        /// An advert is on screen.
        case showing
    }

    private(set) var phase: Phase = .idle
    /// Whether the privacy-options entry point must be offered (UMP).
    private(set) var privacyOptionsRequired = false

    /// Whether this build can show adverts at all.
    var isSupported: Bool {
        #if canImport(GoogleMobileAds)
        return true
        #else
        return false
        #endif
    }

    /// Whether a watch button should be tappable: adverts are allowed, and
    /// none is on screen. (A failed load is tappable: the tap tries again.)
    var canOffer: Bool {
        switch phase {
        case .ready, .loading, .loadFailed, .starting, .idle: return isSupported
        case .unavailable, .showing: return false
        }
    }

    /// One plain line for under a watch button.
    var statusLine: String {
        switch phase {
        case .idle, .starting: return "Preparing adverts…"
        case .unavailable(let reason): return reason
        case .loading: return "Fetching an ad…"
        case .ready: return "An ad is ready."
        case .loadFailed(let reason): return reason
        case .showing: return "Ad playing."
        }
    }

    #if canImport(GoogleMobileAds)
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var loaded: RewardedAd?
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    /// Held for as long as an advert is on screen: the SDK keeps only a weak
    /// reference to its delegate.
    @ObservationIgnored private var presenter: AdPresenter?
    #endif

    /// Tests host the app; adverts are never started under XCTest.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: Starting

    /// Called once at launch: gathers consent where the law asks for it, then
    /// starts the SDK and preloads the first advert. Safe to call again.
    func start() {
        #if canImport(GoogleMobileAds)
        guard !hasStarted, !Self.isRunningTests else { return }
        hasStarted = true
        phase = .starting
        Task { await gatherConsentThenStart() }
        #else
        phase = .unavailable("Ads are not part of this build.")
        #endif
    }

    #if canImport(GoogleMobileAds)
    private func gatherConsentThenStart() async {
        #if canImport(UserMessagingPlatform)
        // Asked on every launch, as Google requires. The form only appears
        // where a consent law applies and the player has not yet answered.
        let parameters = RequestParameters()
        let updateError: Error? = await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                continuation.resume(returning: error)
            }
        }
        if updateError == nil {
            do {
                try await ConsentForm.loadAndPresentIfRequired(from: Self.topViewController)
            } catch {
                // A form that could not be shown is asked again next launch.
            }
        }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        // A previous session's consent still counts if this launch's check failed.
        guard ConsentInformation.shared.canRequestAds else {
            phase = .unavailable("Ads are off until you choose your privacy settings.")
            return
        }
        #endif
        startSDK()
    }

    private func startSDK() {
        MobileAds.shared.start { [weak self] _ in
            // Only once the SDK has started: a request made sooner is failed
            // outright rather than queued.
            Task { @MainActor in await self?.load() }
        }
    }
    #endif

    /// Shows Google's privacy options form, from Settings.
    func presentPrivacyOptions() async {
        #if canImport(UserMessagingPlatform)
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: Self.topViewController)
        } catch {}
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #if canImport(GoogleMobileAds)
        if ConsentInformation.shared.canRequestAds, case .unavailable = phase {
            startSDK()
        }
        #endif
        #endif
    }

    /// Apple's tracking question, asked once, at a moment adverts are what
    /// the player is looking at (the boons panel), never at launch. Every
    /// answer is fine: a refusal only makes adverts less relevant.
    func requestTrackingPermissionIfNeeded() async {
        #if canImport(AppTrackingTransparency)
        guard !Self.isRunningTests, isSupported,
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
        #endif
    }

    // MARK: Loading

    /// Makes sure an advert is on its way and returns once the answer is
    /// known. Callers share one request.
    func load() async {
        #if canImport(GoogleMobileAds)
        guard hasStarted else { return }
        if loaded != nil {
            if phase != .showing { phase = .ready }
            return
        }
        if case .unavailable = phase { return }
        if let running = inFlight {
            await running.value
            return
        }
        let task = Task { @MainActor [weak self] in
            await self?.request()
        }
        inFlight = task
        await task.value
        inFlight = nil
        #endif
    }

    #if canImport(GoogleMobileAds)
    /// One request, tried a few times: an empty exchange is ordinary and
    /// usually clears within moments.
    private func request() async {
        if phase != .showing { phase = .loading }
        var failure: Error?
        for attempt in 1...3 {
            do {
                let ad = try await RewardedAd.load(with: AdConfiguration.activeRewardedUnitID, request: Request())
                loaded = ad
                if phase != .showing { phase = .ready }
                return
            } catch {
                failure = error
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                }
            }
        }
        loaded = nil
        if phase != .showing {
            phase = .loadFailed(Self.explain(failure))
        }
    }

    /// The SDK's error in words a player can act on, with the code kept for reports.
    private static func explain(_ error: Error?) -> String {
        guard let error else { return "No ad is available right now. Try again in a moment." }
        let failure = error as NSError
        let detail: String
        switch failure.code {
        case 1, 9: detail = "No ad is available right now. Try again in a moment."
        case 2, 5: detail = "Couldn't reach the ad service. Check your connection."
        case 3, 11: detail = "The ad service had a problem. Try again shortly."
        default: detail = "The ad couldn't load."
        }
        return "\(detail) (code \(failure.code))"
    }
    #endif

    // MARK: Showing

    /// Shows an advert and resolves once it has closed. `.earned` only when
    /// the SDK's earned-reward callback fired: closing early, any failure, or
    /// a second tap while one is already showing, all report otherwise, and
    /// nothing is granted for them.
    func show() async -> AdOutcome {
        #if canImport(GoogleMobileAds)
        if case .showing = phase { return .busy }
        if !hasStarted { start() }
        if case .unavailable(let reason) = phase { return .failed(reason) }
        // Claim the screen before waiting on a load, so a second tap in the
        // meantime is turned away rather than queuing a second advert.
        phase = .showing
        await load()
        guard let ad = loaded else {
            phase = .loadFailed("No ad is available right now. Try again in a moment.")
            Task { await load() }
            return .failed("No ad is available right now. Try again in a moment.")
        }
        guard let root = Self.topViewController else {
            phase = .ready
            return .failed("There's nowhere to show the ad.")
        }
        loaded = nil
        let presenter = AdPresenter()
        self.presenter = presenter
        let outcome = await presenter.present(ad, from: root)
        self.presenter = nil
        phase = .loading
        // The next one is fetched straight away, so a second helping (or a
        // later revive) is not left waiting.
        Task { await load() }
        return outcome
        #else
        return .failed("Ads are not part of this build.")
        #endif
    }

    /// The controller an advert is shown over: the topmost one, since UIKit
    /// refuses to present over a controller that is already presenting (a
    /// sheet such as Settings).
    static var topViewController: UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

#if canImport(GoogleMobileAds)
/// Joins the SDK's callbacks into one answer.
///
/// The reward callback fires while the advert is still up; the outcome is
/// only final when it is dismissed (or fails to show). Each is guarded so the
/// answer is given exactly once, whatever order or number the callbacks
/// arrive in.
private final class AdPresenter: NSObject, FullScreenContentDelegate {
    private var finish: ((AdOutcome) -> Void)?
    private var earned = false

    func present(_ ad: RewardedAd, from root: UIViewController) async -> AdOutcome {
        await withCheckedContinuation { continuation in
            finish = { continuation.resume(returning: $0) }
            ad.fullScreenContentDelegate = self
            // Presented on the main queue explicitly: the SDK refuses to
            // present from anywhere else (code 21), and this class is not
            // actor-isolated.
            DispatchQueue.main.async { [weak self] in
                ad.present(from: root) {
                    self?.earned = true
                }
            }
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let failure = error as NSError
        complete(.failed("The ad couldn't be shown. (code \(failure.code))"))
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        complete(earned ? .earned : .closedEarly)
    }

    /// Resuming a continuation twice is a crash; only the first answer counts.
    private func complete(_ outcome: AdOutcome) {
        let handler = finish
        finish = nil
        handler?(outcome)
    }
}
#endif
