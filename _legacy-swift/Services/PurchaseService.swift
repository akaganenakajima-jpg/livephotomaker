import Foundation
import StoreKit

/// StoreKit 2 based purchase abstraction.
///
/// The live implementation uses `Transaction.updates` to listen for purchases
/// made outside the app (parental approval, subscription restore, etc.) and
/// reports entitlement changes via a callback.
public protocol PurchaseServiceProtocol: Sendable {
    /// Loads products from the App Store for display on the paywall.
    func loadProducts() async throws -> [Product]

    /// Kicks off a purchase for the given product id.
    func purchase(productID: String) async throws -> Bool

    /// Restores previous purchases.
    func restore() async throws

    /// Returns `true` if the user currently holds the premium entitlement.
    func isPremiumUnlocked() async -> Bool

    /// Starts the long-running transaction listener. The closure fires
    /// whenever entitlement may have changed.
    func startTransactionListener(onChange: @escaping @Sendable () async -> Void) async
}

public final class PurchaseService: PurchaseServiceProtocol, @unchecked Sendable {
    private var listenerTask: Task<Void, Never>?

    public init() {}

    public func loadProducts() async throws -> [Product] {
        do {
            return try await Product.products(for: ProductIdentifier.all)
        } catch {
            throw AppError.purchaseFailed(underlying: error.localizedDescription)
        }
    }

    public func purchase(productID: String) async throws -> Bool {
        let products: [Product]
        do {
            products = try await Product.products(for: [productID])
        } catch {
            throw AppError.purchaseFailed(underlying: error.localizedDescription)
        }
        guard let product = products.first else {
            throw AppError.purchaseFailed(underlying: "product not found")
        }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                return true
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            throw AppError.purchaseFailed(underlying: error.localizedDescription)
        }
    }

    public func restore() async throws {
        do {
            try await AppStore.sync()
        } catch {
            throw AppError.purchaseFailed(underlying: error.localizedDescription)
        }
    }

    public func isPremiumUnlocked() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            if transaction.productID == ProductIdentifier.premiumHQUnlock,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    public func startTransactionListener(onChange: @escaping @Sendable () async -> Void) async {
        listenerTask?.cancel()
        listenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case let .verified(transaction) = result {
                    await transaction.finish()
                    _ = self
                }
                await onChange()
            }
        }
    }

    // MARK: - Private

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw AppError.purchaseFailed(underlying: "transaction not verified")
        case let .verified(value):
            return value
        }
    }
}
