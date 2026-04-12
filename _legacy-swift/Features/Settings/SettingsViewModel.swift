import Foundation

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var isPremium: Bool = false

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func refresh() async {
        await environment.refreshEntitlement()
        isPremium = environment.entitlement == .premiumUnlocked
    }

    public func restore() async {
        do {
            try await environment.purchase.restore()
            await refresh()
        } catch {
            // Non-fatal: let the UI surface this via its own error binding.
        }
    }
}
