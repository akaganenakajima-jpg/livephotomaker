import Photos
import PhotosUI
import SwiftUI

/// Shows the freshly-saved Live Photo. Renders the JPEG+MOV pair directly with
/// `PHLivePhoto.request(withResourceFileURLs:)`, wrapped in a
/// `UIViewRepresentable` around `PHLivePhotoView`.
public struct LivePhotoPreviewView: View {
    public let pair: LivePhotoPair
    public let onContinue: () -> Void

    public init(pair: LivePhotoPair, onContinue: @escaping () -> Void) {
        self.pair = pair
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 16) {
            LivePhotoRepresentable(pair: pair)
                .frame(maxWidth: .infinity, maxHeight: 420)
                .cornerRadius(12)
                .padding(.horizontal, 16)

            Text("preview.hint")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("次へ", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)

            Spacer()
        }
        .navigationTitle("preview.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LivePhotoRepresentable: UIViewRepresentable {
    let pair: LivePhotoPair

    func makeUIView(context _: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context _: Context) {
        PHLivePhoto.request(
            withResourceFileURLs: [pair.stillURL, pair.pairedVideoURL],
            placeholderImage: nil,
            targetSize: .zero,
            contentMode: .aspectFit
        ) { livePhoto, _ in
            if let livePhoto {
                uiView.livePhoto = livePhoto
            }
        }
    }
}
