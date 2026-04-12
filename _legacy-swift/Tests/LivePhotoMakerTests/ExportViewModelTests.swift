import XCTest
@testable import LivePhotoMaker

@MainActor
final class ExportViewModelTests: XCTestCase {
    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment(
            videoProcessing: MockVideoProcessingService(),
            livePhotoExport: MockLivePhotoExportService(),
            photoLibrary: MockPhotoLibraryService(),
            purchase: MockPurchaseService(),
            ads: MockAdsService(),
            analytics: MockAnalyticsService()
        )
    }

    func test_resolveQuality_freeStandard_returnsStandard() {
        let env = makeEnvironment()
        let sut = ExportViewModel(sourceURL: URL(fileURLWithPath: "/tmp/x.mov"), timeRange: nil, environment: env)
        XCTAssertEqual(sut.resolveQuality(), .standard)
    }

    func test_resolveQuality_withTrial_returnsHigh() {
        let env = makeEnvironment()
        env.grantOneTimeHQTrial()
        let sut = ExportViewModel(sourceURL: URL(fileURLWithPath: "/tmp/x.mov"), timeRange: nil, environment: env)
        XCTAssertEqual(sut.resolveQuality(), .high)
    }

    func test_grantTrialAfterAd_rewarded_grantsTrial() {
        let env = makeEnvironment()
        let sut = ExportViewModel(sourceURL: URL(fileURLWithPath: "/tmp/x.mov"), timeRange: nil, environment: env)
        let granted = sut.grantTrialAfterAd(result: .rewarded)
        XCTAssertTrue(granted)
        XCTAssertEqual(env.entitlement, .oneTimeHQTrial)
    }

    func test_grantTrialAfterAd_dismissed_doesNotGrant() {
        let env = makeEnvironment()
        let sut = ExportViewModel(sourceURL: URL(fileURLWithPath: "/tmp/x.mov"), timeRange: nil, environment: env)
        let granted = sut.grantTrialAfterAd(result: .dismissedWithoutReward)
        XCTAssertFalse(granted)
        XCTAssertEqual(env.entitlement, .freeStandard)
    }

    func test_grantTrialAfterAd_failed_setsError() {
        let env = makeEnvironment()
        let sut = ExportViewModel(sourceURL: URL(fileURLWithPath: "/tmp/x.mov"), timeRange: nil, environment: env)
        _ = sut.grantTrialAfterAd(result: .failed)
        XCTAssertEqual(sut.error, .adUnavailable)
    }

    func test_startStandardExport_success_transitionsToPreview() async throws {
        let env = makeEnvironment()
        let sut = ExportViewModel(sourceURL: URL(fileURLWithPath: "/tmp/x.mov"), timeRange: nil, environment: env)
        await sut.startStandardExport()
        if case .preview = sut.route {
            // success
        } else {
            XCTFail("expected .preview, got \(sut.route)")
        }
    }

    func test_startHighQualityExport_consumesTrial() async throws {
        let env = makeEnvironment()
        env.grantOneTimeHQTrial()
        XCTAssertEqual(env.entitlement, .oneTimeHQTrial)
        let sut = ExportViewModel(sourceURL: URL(fileURLWithPath: "/tmp/x.mov"), timeRange: nil, environment: env)
        await sut.startHighQualityExport()
        XCTAssertEqual(env.entitlement, .freeStandard, "trial must be consumed after HQ export")
    }
}
