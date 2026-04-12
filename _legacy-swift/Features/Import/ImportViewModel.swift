import Foundation
import PhotosUI
import SwiftUI

@MainActor
public final class ImportViewModel: ObservableObject {
    @Published public var pickerItem: PhotosPickerItem?
    @Published public var pickedVideoURL: URL?
    @Published public var error: AppError?

    private let analytics: AnalyticsServiceProtocol

    public init(analytics: AnalyticsServiceProtocol) {
        self.analytics = analytics
    }

    public func handlePicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let url = try await loadVideoURL(from: item) {
                pickedVideoURL = url
                analytics.track(.videoSelected)
            }
        } catch {
            self.error = .videoUnsupported
        }
    }

    private func loadVideoURL(from item: PhotosPickerItem) async throws -> URL? {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            return nil
        }
        let directory = try FileManager.default.makeUniqueTemporaryDirectory()
        let url = directory.appendingPathComponent("source.mov")
        try data.write(to: url, options: .atomic)
        return url
    }
}
