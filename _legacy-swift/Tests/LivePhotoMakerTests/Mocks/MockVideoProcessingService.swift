import AVFoundation
import Foundation
@testable import LivePhotoMaker

final class MockVideoProcessingService: VideoProcessingServiceProtocol, @unchecked Sendable {
    var stubDuration: Double = 5
    var shouldFail: Bool = false

    func duration(of _: URL) async throws -> Double {
        if shouldFail { throw AppError.videoUnsupported }
        return stubDuration
    }

    func prepare(
        sourceURL _: URL,
        timeRange _: CMTimeRange?,
        quality _: ExportQuality,
        workingDirectory: URL
    ) async throws -> PreparedVideo {
        if shouldFail { throw AppError.exportFailed(underlying: "mock failure") }
        return PreparedVideo(
            movURL: workingDirectory.appendingPathComponent("mock.mov"),
            stillURL: workingDirectory.appendingPathComponent("mock.jpg"),
            durationSeconds: stubDuration
        )
    }
}

final class MockLivePhotoExportService: LivePhotoExportServiceProtocol, @unchecked Sendable {
    var shouldFail: Bool = false

    func buildPair(from prepared: PreparedVideo, workingDirectory _: URL) async throws -> LivePhotoPair {
        if shouldFail { throw AppError.exportFailed(underlying: "mock pair failure") }
        return LivePhotoPair(
            stillURL: prepared.stillURL,
            pairedVideoURL: prepared.movURL,
            assetIdentifier: "MOCK-ID"
        )
    }
}

final class MockPhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {
    var shouldGrantPermission: Bool = true
    var saveShouldFail: Bool = false
    var saveCount: Int = 0

    func requestAddOnlyAuthorization() async -> Bool { shouldGrantPermission }

    func saveLivePhoto(pair _: LivePhotoPair) async throws {
        if !shouldGrantPermission { throw AppError.photoPermissionDenied }
        if saveShouldFail { throw AppError.exportFailed(underlying: "mock save failure") }
        saveCount += 1
    }
}

final class MockAnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) { events.append(event) }
    func track(_ event: AnalyticsEvent, parameters _: [String: String]) { events.append(event) }
}
