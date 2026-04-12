import Foundation
import StoreKit

@MainActor
public final class PurchaseViewModel: ObservableObject {
    @Published public var product: Product?
    @Published public var isLoading: Bool = false
    @Published public var error: AppError?
    @Published public var didPurchase: Bool = false

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await environment.purchase.loadProducts()
            product = products.first
            environment.analytics.track(.premiumPaywallViewed)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .purchaseFailed(underlying: error.localizedDescription)
        }
    }

    public func buy() async {
        guard let product else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let success = try await environment.purchase.purchase(productID: product.id)
            if success {
                environment.analytics.track(.premiumPurchased)
                await environment.refreshEntitlement()
                didPurchase = true
            }
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .purchaseFailed(underlying: error.localizedDescription)
        }
    }

    public func restore() async {
        isLoading = true
        defer { isLoading = false }
        environment.analytics.track(.restorePurchaseTapped)
        do {
            try await environment.purchase.restore()
            await environment.refreshEntitlement()
            didPurchase = environment.entitlement == .premiumUnlocked
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .purchaseFailed(underlying: error.localizedDescription)
        }
    }
}
