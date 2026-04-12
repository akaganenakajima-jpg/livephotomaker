import AVFoundation
import Foundation

/// Target export quality for the generated Live Photo pair.
public enum ExportQuality: String, Equatable, Sendable {
    case standard
    case high

    /// AVAssetExportSession preset for the MOV component.
    public var assetExportPreset: String {
        switch self {
        case .standard:
            return AVAssetExportPreset1280x720
        case .high:
            return AVAssetExportPresetHighestQuality
        }
    }

    /// Target still-image pixel width for the JPEG component.
    public var maxStillPixelWidth: CGFloat {
        switch self {
        case .standard:
            return 1280
        case .high:
            return 2160
        }
    }

    /// JPEG compression quality (0.0 - 1.0).
    public var jpegCompression: CGFloat {
        switch self {
        case .standard:
            return 0.85
        case .high:
            return 0.95
        }
    }
}
