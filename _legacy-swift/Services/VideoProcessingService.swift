import AVFoundation
import CoreImage
import Foundation
import UIKit

/// Result of preparing a source video for Live Photo export.
public struct PreparedVideo: Sendable {
    /// URL of the trimmed MOV that will become the Live Photo's paired video.
    public let movURL: URL
    /// URL of the extracted keyframe still image (JPEG).
    public let stillURL: URL
    /// Duration of the trimmed clip in seconds.
    public let durationSeconds: Double
}

/// Abstract video processing pipeline: trim → export MOV → extract keyframe JPEG.
public protocol VideoProcessingServiceProtocol: Sendable {
    /// Returns the duration of the source video in seconds.
    func duration(of sourceURL: URL) async throws -> Double

    /// Prepares a trimmed MOV and a still JPEG ready to be paired as a Live Photo.
    func prepare(
        sourceURL: URL,
        timeRange: CMTimeRange?,
        quality: ExportQuality,
        workingDirectory: URL
    ) async throws -> PreparedVideo
}

public final class VideoProcessingService: VideoProcessingServiceProtocol {
    /// Maximum accepted duration for a source clip (seconds). Longer clips are rejected.
    public static let maxAcceptedDurationSeconds: Double = 60

    public init() {}

    public func duration(of sourceURL: URL) async throws -> Double {
        let asset = AVURLAsset(url: sourceURL)
        return try await asset.durationSeconds()
    }

    public func prepare(
        sourceURL: URL,
        timeRange: CMTimeRange?,
        quality: ExportQuality,
        workingDirectory: URL
    ) async throws -> PreparedVideo {
        let asset = AVURLAsset(url: sourceURL)
        let totalDuration = try await asset.durationSeconds()

        if totalDuration > Self.maxAcceptedDurationSeconds {
            throw AppError.videoTooLong(maxSeconds: Int(Self.maxAcceptedDurationSeconds))
        }

        let movURL = workingDirectory.appendingPathComponent("paired.mov")
        try await exportTrimmedMOV(
            asset: asset,
            timeRange: timeRange,
            quality: quality,
            destinationURL: movURL
        )

        let stillURL = workingDirectory.appendingPathComponent("still.jpg")
        try await extractKeyframeJPEG(
            asset: asset,
            at: timeRange?.start ?? .zero,
            quality: quality,
            destinationURL: stillURL
        )

        let exportedAsset = AVURLAsset(url: movURL)
        let exportedDuration = try await exportedAsset.durationSeconds()

        return PreparedVideo(
            movURL: movURL,
            stillURL: stillURL,
            durationSeconds: exportedDuration
        )
    }

    // MARK: - Private helpers

    private func exportTrimmedMOV(
        asset: AVURLAsset,
        timeRange: CMTimeRange?,
        quality: ExportQuality,
        destinationURL: URL
    ) async throws {
        guard let exporter = AVAssetExportSession(asset: asset, presetName: quality.assetExportPreset) else {
            throw AppError.videoUnsupported
        }

        try? FileManager.default.removeItem(at: destinationURL)

        exporter.outputURL = destinationURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = true
        if let timeRange {
            exporter.timeRange = timeRange
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    let message = exporter.error?.localizedDescription ?? "export session failed"
                    continuation.resume(throwing: AppError.exportFailed(underlying: message))
                default:
                    continuation.resume(throwing: AppError.exportFailed(underlying: "unexpected status"))
                }
            }
        }
    }

    private func extractKeyframeJPEG(
        asset: AVAsset,
        at time: CMTime,
        quality: ExportQuality,
        destinationURL: URL
    ) async throws {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: quality.maxStillPixelWidth, height: .greatestFiniteMagnitude)

        let cgImage: CGImage = try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, result, error in
                if let error {
                    continuation.resume(throwing: AppError.exportFailed(underlying: error.localizedDescription))
                    return
                }
                guard result == .succeeded, let image else {
                    continuation.resume(throwing: AppError.exportFailed(underlying: "keyframe extraction failed"))
                    return
                }
                continuation.resume(returning: image)
            }
        }

        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: quality.jpegCompression) else {
            throw AppError.exportFailed(underlying: "jpeg encoding failed")
        }
        try data.write(to: destinationURL, options: .atomic)
    }
}
