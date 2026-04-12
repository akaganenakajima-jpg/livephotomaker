import Foundation

/// Errors that surface to the user. Each case maps to a localized message key.
public enum AppError: LocalizedError, Equatable, Sendable {
    case photoPermissionDenied
    case videoUnsupported
    case videoTooLong(maxSeconds: Int)
    case exportFailed(underlying: String)
    case adUnavailable
    case purchaseFailed(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .photoPermissionDenied:
            return NSLocalizedString("error.photo_permission", comment: "")
        case .videoUnsupported:
            return NSLocalizedString("error.video_unsupported", comment: "")
        case .videoTooLong:
            return NSLocalizedString("error.video_too_long", comment: "")
        case .exportFailed:
            return NSLocalizedString("error.export_failed", comment: "")
        case .adUnavailable:
            return NSLocalizedString("error.ad_unavailable", comment: "")
        case .purchaseFailed:
            return NSLocalizedString("error.purchase_failed", comment: "")
        }
    }
}
