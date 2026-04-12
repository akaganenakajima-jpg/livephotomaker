import Foundation
import UIKit

/// Ad presentation result.
public enum AdResult: Equatable, Sendable {
    case rewarded
    case dismissedWithoutReward
    case failed
}

/// Abstract rewarded ad service. The concrete implementation is where the
/// actual ad SDK (e.g. Google Mobile Ads) is imported - no other layer of
/// the app should reference an ad SDK directly.
public protocol AdsServiceProtocol: Sendable {
    /// Whether ads are currently enabled. Returns `false` for premium users.
    func isEnabled(for entitlement: ExportEntitlement) -> Bool

    /// Preloads a rewarded ad. Safe to call many times.
    func preloadRewarded() async

    /// Presents the rewarded ad from the given view controller.
    /// The returned result indicates whether the user earned the reward.
    @MainActor
    func presentRewarded(from presenter: UIViewController) async -> AdResult
}

/// Default stub implementation. A real build links against Google Mobile Ads
/// or another SDK; that integration is intentionally kept behind a separate
/// target / Swift package so the core app stays SDK-agnostic.
public final class AdsService: AdsServiceProtocol {
    public init() {}

    public func isEnabled(for entitlement: ExportEntitlement) -> Bool {
        entitlement.shouldShowAds
    }

    public func preloadRewarded() async {
        // Stub: the real implementation calls into the SDK to preload.
    }

    @MainActor
    public func presentRewarded(from _: UIViewController) async -> AdResult {
        // Stub: without an ad SDK configured, we fail so the app falls back
        // to the standard-quality path. This keeps the MVP buildable and
        // honors the requirement "read failure falls back to standard".
        .failed
    }
}
