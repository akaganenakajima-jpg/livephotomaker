import Foundation
import UIKit
@testable import LivePhotoMaker

final class MockAdsService: AdsServiceProtocol, @unchecked Sendable {
    var nextResult: AdResult = .rewarded
    var presentedCount: Int = 0

    func isEnabled(for entitlement: ExportEntitlement) -> Bool {
        entitlement.shouldShowAds
    }

    func preloadRewarded() async {}

    @MainActor
    func presentRewarded(from _: UIViewController) async -> AdResult {
        presentedCount += 1
        return nextResult
    }
}
