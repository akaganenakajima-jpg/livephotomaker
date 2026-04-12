import AVFoundation
import Foundation

extension AVAsset {
    /// Async-friendly duration accessor that prefers the modern load API.
    func durationSeconds() async throws -> Double {
        let duration = try await load(.duration)
        return CMTimeGetSeconds(duration)
    }
}
