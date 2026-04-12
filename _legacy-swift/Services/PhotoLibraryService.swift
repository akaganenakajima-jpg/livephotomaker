import Foundation
import Photos

/// Photo library access + Live Photo save abstraction.
public protocol PhotoLibraryServiceProtocol: Sendable {
    /// Requests `.addOnly` authorization. Returns `true` if granted.
    func requestAddOnlyAuthorization() async -> Bool

    /// Saves a Live Photo pair to the user's library. Throws on failure.
    func saveLivePhoto(pair: LivePhotoPair) async throws
}

public final class PhotoLibraryService: PhotoLibraryServiceProtocol {
    public init() {}

    public func requestAddOnlyAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    public func saveLivePhoto(pair: LivePhotoPair) async throws {
        let granted = await requestAddOnlyAuthorization()
        guard granted else {
            throw AppError.photoPermissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()

            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.shouldMoveFile = false
            creationRequest.addResource(
                with: .photo,
                fileURL: pair.stillURL,
                options: photoOptions
            )

            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.shouldMoveFile = false
            creationRequest.addResource(
                with: .pairedVideo,
                fileURL: pair.pairedVideoURL,
                options: videoOptions
            )
        }
    }
}
