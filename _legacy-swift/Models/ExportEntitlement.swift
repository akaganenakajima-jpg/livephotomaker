import Foundation

/// Represents the user's current entitlement for export quality and ads.
///
/// State transitions:
/// - `freeStandard` → `oneTimeHQTrial` : user completed a rewarded ad view
/// - `oneTimeHQTrial` → `freeStandard` : user successfully exported once in HQ
/// - `freeStandard` / `oneTimeHQTrial` → `premiumUnlocked` : successful IAP purchase or restore
/// - `premiumUnlocked` is terminal and always keeps ads hidden.
public enum ExportEntitlement: Equatable, Sendable {
    case freeStandard
    case oneTimeHQTrial
    case premiumUnlocked

    /// Whether the user may currently export in high quality.
    public var canExportHighQuality: Bool {
        switch self {
        case .premiumUnlocked, .oneTimeHQTrial:
            return true
        case .freeStandard:
            return false
        }
    }

    /// Whether ads should be shown at all.
    public var shouldShowAds: Bool {
        switch self {
        case .premiumUnlocked:
            return false
        case .freeStandard, .oneTimeHQTrial:
            return true
        }
    }

    /// Returns the entitlement after consuming a one-time HQ trial.
    /// Premium stays premium. Free stays free.
    public func consumingTrial() -> ExportEntitlement {
        switch self {
        case .oneTimeHQTrial:
            return .freeStandard
        case .freeStandard, .premiumUnlocked:
            return self
        }
    }
}
