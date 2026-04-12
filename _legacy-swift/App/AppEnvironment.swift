import Foundation

/// Root dependency container. Views access services via `@EnvironmentObject`.
///
/// `AppEnvironment` owns the concrete service instances for the live app and
/// exposes them through protocol-typed properties so that tests and previews
/// can substitute mocks.
@MainActor
public final class AppEnvironment: ObservableObject {
    public let videoProcessing: VideoProcessingServiceProtocol
    public let livePhotoExport: LivePhotoExportServiceProtocol
    public let photoLibrary: PhotoLibraryServiceProtocol
    public let purchase: PurchaseServiceProtocol
    public let ads: AdsServiceProtocol
    public let analytics: AnalyticsServiceProtocol

    @Published public private(set) var entitlement: ExportEntitlement = .freeStandard

    public init(
        videoProcessing: VideoProcessingServiceProtocol,
        livePhotoExport: LivePhotoExportServiceProtocol,
        photoLibrary: PhotoLibraryServiceProtocol,
        purchase: PurchaseServiceProtocol,
        ads: AdsServiceProtocol,
        analytics: AnalyticsServiceProtocol
    ) {
        self.videoProcessing = videoProcessing
        self.livePhotoExport = livePhotoExport
        self.photoLibrary = photoLibrary
        self.purchase = purchase
        self.ads = ads
        self.analytics = analytics
    }

    /// Builds the production dependency graph.
    public static func live() -> AppEnvironment {
        AppEnvironment(
            videoProcessing: VideoProcessingService(),
            livePhotoExport: LivePhotoExportService(),
            photoLibrary: PhotoLibraryService(),
            purchase: PurchaseService(),
            ads: AdsService(),
            analytics: AnalyticsService()
        )
    }

    /// Called once on launch to prime services (StoreKit listener, etc.).
    public func bootstrap() async {
        analytics.track(.appOpen)
        await refreshEntitlement()
        await purchase.startTransactionListener { [weak self] in
            await self?.refreshEntitlement()
        }
    }

    /// Updates the published entitlement from the latest purchase state.
    public func refreshEntitlement() async {
        let isPremium = await purchase.isPremiumUnlocked()
        if isPremium {
            entitlement = .premiumUnlocked
        } else if entitlement == .premiumUnlocked {
            // Downgrade only if actually revoked.
            entitlement = .freeStandard
        }
    }

    /// Grants a one-time HQ trial after a successful rewarded ad view.
    public func grantOneTimeHQTrial() {
        guard entitlement == .freeStandard else { return }
        entitlement = .oneTimeHQTrial
        analytics.track(.rewardedTrialCompleted)
    }

    /// Consumes the trial after a successful HQ export.
    public func consumeTrialIfNeeded() {
        entitlement = entitlement.consumingTrial()
    }
}
