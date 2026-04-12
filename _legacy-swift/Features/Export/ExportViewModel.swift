import AVFoundation
import Foundation

public enum ExportRoute: Equatable, Sendable {
    case options
    case progress
    case preview(pair: LivePhotoPair)
    case success
}

@MainActor
public final class ExportViewModel: ObservableObject {
    @Published public var route: ExportRoute = .options
    @Published public var progressMessage: String = ""
    @Published public var error: AppError?

    public let sourceURL: URL
    public let timeRange: CMTimeRange?

    private let environment: AppEnvironment

    public init(
        sourceURL: URL,
        timeRange: CMTimeRange?,
        environment: AppEnvironment
    ) {
        self.sourceURL = sourceURL
        self.timeRange = timeRange
        self.environment = environment
    }

    // MARK: - Quality resolution

    /// Resolves which quality to use based on the current entitlement.
    /// This is the single source of truth tested in ExportViewModelTests.
    public func resolveQuality() -> ExportQuality {
        switch environment.entitlement {
        case .premiumUnlocked, .oneTimeHQTrial:
            return .high
        case .freeStandard:
            return .standard
        }
    }

    // MARK: - Standard export

    public func startStandardExport() async {
        environment.analytics.track(.exportStandardStarted)
        await runExport(quality: .standard)
    }

    // MARK: - HQ export (after rewarded or with premium)

    public func startHighQualityExport() async {
        environment.analytics.track(.exportHQStarted)
        await runExport(quality: .high)
    }

    // MARK: - Rewarded trial

    /// Returns true if a HQ trial was granted. Caller presents the ad and
    /// calls this method with the result.
    public func grantTrialAfterAd(result: AdResult) -> Bool {
        switch result {
        case .rewarded:
            environment.grantOneTimeHQTrial()
            return true
        case .dismissedWithoutReward:
            return false
        case .failed:
            error = .adUnavailable
            environment.analytics.track(.rewardedTrialFailed)
            return false
        }
    }

    // MARK: - Export driver

    private func runExport(quality: ExportQuality) async {
        route = .progress
        progressMessage = NSLocalizedString("export.progress.title", comment: "")

        do {
            let workingDir = try FileManager.default.makeUniqueTemporaryDirectory()
            let prepared = try await environment.videoProcessing.prepare(
                sourceURL: sourceURL,
                timeRange: timeRange,
                quality: quality,
                workingDirectory: workingDir
            )
            let pair = try await environment.livePhotoExport.buildPair(
                from: prepared,
                workingDirectory: workingDir
            )
            try await environment.photoLibrary.saveLivePhoto(pair: pair)

            if quality == .high {
                environment.consumeTrialIfNeeded()
            }

            environment.analytics.track(.exportCompleted)
            route = .preview(pair: pair)
        } catch let appError as AppError {
            environment.analytics.track(.exportFailed)
            error = appError
            route = .options
        } catch {
            environment.analytics.track(.exportFailed)
            self.error = .exportFailed(underlying: error.localizedDescription)
            route = .options
        }
    }
}
