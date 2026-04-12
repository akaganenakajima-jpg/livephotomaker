import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

/// A pair of files ready to be saved as a Live Photo asset.
public struct LivePhotoPair: Sendable {
    public let stillURL: URL
    public let pairedVideoURL: URL
    public let assetIdentifier: String
}

/// Builds the JPEG + MOV pair that PhotoKit accepts as a Live Photo.
///
/// Implementation notes:
/// - Both files must carry the same `assetIdentifier` (a UUID string).
/// - The JPEG stores it under the Maker Apple dictionary, key `17`.
/// - The MOV stores it as a top-level QuickTime metadata item with key
///   `com.apple.quicktime.content.identifier`, and also includes a
///   "still-image-time" timed metadata track so iOS knows which frame is the
///   still image.
public protocol LivePhotoExportServiceProtocol: Sendable {
    func buildPair(
        from prepared: PreparedVideo,
        workingDirectory: URL
    ) async throws -> LivePhotoPair
}

public final class LivePhotoExportService: LivePhotoExportServiceProtocol {
    private enum Keys {
        static let contentIdentifier = "com.apple.quicktime.content.identifier"
        static let stillImageTime = "com.apple.quicktime.still-image-time"
        static let quickTimeMetadata = "mdta"
    }

    public init() {}

    public func buildPair(
        from prepared: PreparedVideo,
        workingDirectory: URL
    ) async throws -> LivePhotoPair {
        let assetIdentifier = UUID().uuidString

        let taggedStillURL = workingDirectory.appendingPathComponent("still_tagged.jpg")
        try writeTaggedJPEG(
            sourceURL: prepared.stillURL,
            destinationURL: taggedStillURL,
            assetIdentifier: assetIdentifier
        )

        let taggedMOVURL = workingDirectory.appendingPathComponent("paired_tagged.mov")
        try await writeTaggedMOV(
            sourceURL: prepared.movURL,
            destinationURL: taggedMOVURL,
            assetIdentifier: assetIdentifier
        )

        return LivePhotoPair(
            stillURL: taggedStillURL,
            pairedVideoURL: taggedMOVURL,
            assetIdentifier: assetIdentifier
        )
    }

    // MARK: - JPEG tagging

    private func writeTaggedJPEG(
        sourceURL: URL,
        destinationURL: URL,
        assetIdentifier: String
    ) throws {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw AppError.exportFailed(underlying: "cannot read still image")
        }
        let type = CGImageSourceGetType(imageSource) ?? UTType.jpeg.identifier as CFString
        try? FileManager.default.removeItem(at: destinationURL)

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            type,
            1,
            nil
        ) else {
            throw AppError.exportFailed(underlying: "cannot create still destination")
        }

        // Embed the Live Photo identifier in the Maker Apple dictionary (key "17").
        let makerApple: [String: Any] = ["17": assetIdentifier]
        let properties: [String: Any] = [
            kCGImagePropertyMakerAppleDictionary as String: makerApple
        ]

        CGImageDestinationAddImageFromSource(destination, imageSource, 0, properties as CFDictionary)

        if !CGImageDestinationFinalize(destination) {
            throw AppError.exportFailed(underlying: "still finalize failed")
        }
    }

    // MARK: - MOV tagging

    private func writeTaggedMOV(
        sourceURL: URL,
        destinationURL: URL,
        assetIdentifier: String
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        try? FileManager.default.removeItem(at: destinationURL)

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mov)
        writer.metadata = [contentIdentifierMetadata(value: assetIdentifier)]

        let reader = try AVAssetReader(asset: asset)

        // --- Video track pass-through ---
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw AppError.exportFailed(underlying: "no video track")
        }

        let videoReaderOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        reader.add(videoReaderOutput)

        let naturalSize = try await videoTrack.load(.naturalSize)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(naturalSize.width),
            AVVideoHeightKey: Int(naturalSize.height)
        ]
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = false
        videoWriterInput.transform = try await videoTrack.load(.preferredTransform)
        writer.add(videoWriterInput)

        // --- Audio track pass-through (optional) ---
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        var audioReaderOutput: AVAssetReaderTrackOutput?
        var audioWriterInput: AVAssetWriterInput?
        if let audioTrack = audioTracks.first {
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            reader.add(output)
            audioReaderOutput = output

            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            audioWriterInput = input
        }

        // --- Still image time metadata track ---
        let stillImageAdaptor = makeStillImageTimeMetadataAdaptor()
        writer.add(stillImageAdaptor.assetWriterInput)

        guard writer.startWriting() else {
            throw AppError.exportFailed(underlying: writer.error?.localizedDescription ?? "writer start failed")
        }
        guard reader.startReading() else {
            throw AppError.exportFailed(underlying: reader.error?.localizedDescription ?? "reader start failed")
        }
        writer.startSession(atSourceTime: .zero)

        // Append the still-image-time marker at time zero.
        let stillImageMetadataItem = stillImageTimeMetadataItem()
        let timedGroup = AVTimedMetadataGroup(
            items: [stillImageMetadataItem],
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 600))
        )
        stillImageAdaptor.append(timedGroup)
        stillImageAdaptor.assetWriterInput.markAsFinished()

        // Video copy loop
        try await copyBuffers(from: videoReaderOutput, to: videoWriterInput, queueLabel: "video")

        // Audio copy loop
        if let audioReaderOutput, let audioWriterInput {
            try await copyBuffers(from: audioReaderOutput, to: audioWriterInput, queueLabel: "audio")
        }

        await writer.finishWriting()

        if writer.status != .completed {
            let message = writer.error?.localizedDescription ?? "writer did not complete"
            throw AppError.exportFailed(underlying: message)
        }
    }

    private func copyBuffers(
        from output: AVAssetReaderTrackOutput,
        to input: AVAssetWriterInput,
        queueLabel: String
    ) async throws {
        let queue = DispatchQueue(label: "livephoto.\(queueLabel).copy")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    if let sampleBuffer = output.copyNextSampleBuffer() {
                        if !input.append(sampleBuffer) {
                            input.markAsFinished()
                            continuation.resume(throwing: AppError.exportFailed(underlying: "append failed"))
                            return
                        }
                    } else {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }
    }

    // MARK: - Metadata helpers

    private func contentIdentifierMetadata(value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.keySpace = AVMetadataKeySpace(rawValue: Keys.quickTimeMetadata)
        item.key = Keys.contentIdentifier as (NSCopying & NSObjectProtocol)
        item.value = value as (NSCopying & NSObjectProtocol)
        item.dataType = "com.apple.metadata.datatype.UTF-8"
        return item
    }

    private func stillImageTimeMetadataItem() -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.keySpace = AVMetadataKeySpace(rawValue: Keys.quickTimeMetadata)
        item.key = Keys.stillImageTime as (NSCopying & NSObjectProtocol)
        item.value = 0 as (NSCopying & NSObjectProtocol)
        item.dataType = "com.apple.metadata.datatype.int8"
        return item
    }

    private func makeStillImageTimeMetadataAdaptor() -> AVAssetWriterInputMetadataAdaptor {
        let spec: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
                "\(Keys.quickTimeMetadata)/\(Keys.stillImageTime)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
                "com.apple.metadata.datatype.int8"
        ]

        var desc: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [spec] as CFArray,
            formatDescriptionOut: &desc
        )

        let input = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: desc
        )
        input.expectsMediaDataInRealTime = false
        return AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
    }
}
