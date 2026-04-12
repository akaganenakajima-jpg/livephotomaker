import Foundation
import os

/// Analytics event names. Add cases conservatively; every event is considered
/// part of the analytics contract and tracked in CI.
public enum AnalyticsEvent: String, Sendable {
    case appOpen = "app_open"
    case videoSelected = "video_selected"
    case exportStandardStarted = "export_standard_started"
    case rewardedTrialRequested = "rewarded_trial_requested"
    case rewardedTrialCompleted = "rewarded_trial_completed"
    case rewardedTrialFailed = "rewarded_trial_failed"
    case exportHQStarted = "export_hq_started"
    case exportCompleted = "export_completed"
    case exportFailed = "export_failed"
    case premiumPaywallViewed = "premium_paywall_viewed"
    case premiumPurchased = "premium_purchased"
    case restorePurchaseTapped = "restore_purchase_tapped"
}

/// Protocol-based analytics abstraction. Implementations must be side-effect
/// free in tests.
public protocol AnalyticsServiceProtocol: Sendable {
    func track(_ event: AnalyticsEvent)
    func track(_ event: AnalyticsEvent, parameters: [String: String])
}

/// Default implementation that logs via `os.Logger` in Debug builds only.
public final class AnalyticsService: AnalyticsServiceProtocol {
    private let logger = Logger(subsystem: "jp.example.livephotomaker", category: "analytics")

    public init() {}

    public func track(_ event: AnalyticsEvent) {
        track(event, parameters: [:])
    }

    public func track(_ event: AnalyticsEvent, parameters: [String: String]) {
        #if DEBUG
        if parameters.isEmpty {
            logger.debug("event=\(event.rawValue, privacy: .public)")
        } else {
            logger.debug("event=\(event.rawValue, privacy: .public) params=\(parameters, privacy: .public)")
        }
        #endif
        // TODO: forward to a production analytics backend when integrated.
    }
}
