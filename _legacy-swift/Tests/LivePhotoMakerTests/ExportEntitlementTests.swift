import XCTest
@testable import LivePhotoMaker

final class ExportEntitlementTests: XCTestCase {
    func test_freeStandard_cannotExportHQ_and_showsAds() {
        let sut = ExportEntitlement.freeStandard
        XCTAssertFalse(sut.canExportHighQuality)
        XCTAssertTrue(sut.shouldShowAds)
    }

    func test_oneTimeHQTrial_canExportHQ_and_stillShowsAds() {
        let sut = ExportEntitlement.oneTimeHQTrial
        XCTAssertTrue(sut.canExportHighQuality)
        XCTAssertTrue(sut.shouldShowAds)
    }

    func test_premiumUnlocked_canExportHQ_and_hidesAds() {
        let sut = ExportEntitlement.premiumUnlocked
        XCTAssertTrue(sut.canExportHighQuality)
        XCTAssertFalse(sut.shouldShowAds)
    }

    func test_consumingTrial_fromOneTimeHQTrial_returnsFreeStandard() {
        XCTAssertEqual(ExportEntitlement.oneTimeHQTrial.consumingTrial(), .freeStandard)
    }

    func test_consumingTrial_fromFreeStandard_isIdempotent() {
        XCTAssertEqual(ExportEntitlement.freeStandard.consumingTrial(), .freeStandard)
    }

    func test_consumingTrial_fromPremium_keepsPremium() {
        XCTAssertEqual(ExportEntitlement.premiumUnlocked.consumingTrial(), .premiumUnlocked)
    }
}
