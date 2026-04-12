import Foundation
import StoreKit
@testable import LivePhotoMaker

final class MockPurchaseService: PurchaseServiceProtocol, @unchecked Sendable {
    var premium: Bool = false
    var purchaseShouldSucceed: Bool = true
    var purchaseWasCalled: Bool = false
    var restoreWasCalled: Bool = false

    func loadProducts() async throws -> [Product] { [] }

    func purchase(productID _: String) async throws -> Bool {
        purchaseWasCalled = true
        if purchaseShouldSucceed {
            premium = true
            return true
        }
        return false
    }

    func restore() async throws {
        restoreWasCalled = true
    }

    func isPremiumUnlocked() async -> Bool { premium }

    func startTransactionListener(onChange _: @escaping @Sendable () async -> Void) async {
        // no-op for tests
    }
}
