import Foundation

/// Static registry of App Store product identifiers used by the app.
public enum ProductIdentifier {
    /// Non-consumable in-app purchase that permanently unlocks high-quality export
    /// and removes ads.
    public static let premiumHQUnlock = "jp.example.livephotomaker.premium.hq_unlock"

    /// All product ids managed by the app.
    public static let all: [String] = [premiumHQUnlock]
}
