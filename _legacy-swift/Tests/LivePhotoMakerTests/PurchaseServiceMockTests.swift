import XCTest
@testable import LivePhotoMaker

@MainActor
final class PurchaseServiceMockTests: XCTestCase {
    func test_mockPurchase_flipsPremium() async throws {
        let sut = MockPurchaseService()
        XCTAssertFalse(await sut.isPremiumUnlocked())

        _ = try await sut.purchase(productID: ProductIdentifier.premiumHQUnlock)
        XCTAssertTrue(await sut.isPremiumUnlocked())
    }

    func test_environmentReflectsPremium_afterRefresh() async {
        let mock = MockPurchaseService()
        mock.premium = true
        let env = AppEnvironment(
            videoProcessing: MockVideoProcessingService(),
            livePhotoExport: MockLivePhotoExportService(),
            photoLibrary: MockPhotoLibraryService(),
            purchase: mock,
            ads: MockAdsService(),
            analytics: MockAnalyticsService()
        )
        await env.refreshEntitlement()
        XCTAssertEqual(env.entitlement, .premiumUnlocked)
    }
}
