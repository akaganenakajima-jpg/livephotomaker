import AVFoundation
import Foundation

@MainActor
public final class TrimViewModel: ObservableObject {
    @Published public var durationSeconds: Double = 0
    @Published public var startSeconds: Double = 0
    @Published public var endSeconds: Double = 0
    @Published public var isLoading: Bool = true
    @Published public var error: AppError?

    public let sourceURL: URL
    private let videoProcessing: VideoProcessingServiceProtocol

    public init(sourceURL: URL, videoProcessing: VideoProcessingServiceProtocol) {
        self.sourceURL = sourceURL
        self.videoProcessing = videoProcessing
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let duration = try await videoProcessing.duration(of: sourceURL)
            durationSeconds = duration
            startSeconds = 0
            endSeconds = min(duration, 3.0)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .videoUnsupported
        }
    }

    public var selectedTimeRange: CMTimeRange {
        let start = CMTime(seconds: startSeconds, preferredTimescale: 600)
        let duration = CMTime(seconds: max(0.1, endSeconds - startSeconds), preferredTimescale: 600)
        return CMTimeRange(start: start, duration: duration)
    }
}
