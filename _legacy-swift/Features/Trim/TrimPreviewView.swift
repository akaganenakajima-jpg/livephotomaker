import AVKit
import SwiftUI

public struct TrimPreviewView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: TrimViewModel

    public init(sourceURL: URL) {
        _viewModel = StateObject(
            wrappedValue: TrimViewModel(
                sourceURL: sourceURL,
                videoProcessing: VideoProcessingService()
            )
        )
    }

    public var body: some View {
        VStack(spacing: 16) {
            VideoPlayer(player: AVPlayer(url: viewModel.sourceURL))
                .frame(maxHeight: 360)
                .cornerRadius(12)
                .padding(.horizontal, 16)

            if viewModel.isLoading {
                ProgressView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("長さ: \(String(format: "%.1f", viewModel.durationSeconds)) 秒")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: $viewModel.endSeconds,
                        in: 1...max(1, viewModel.durationSeconds)
                    )
                    Text("使う範囲: 0 〜 \(String(format: "%.1f", viewModel.endSeconds)) 秒")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
            }

            NavigationLink("書き出し方法を選ぶ") {
                ExportOptionsView(
                    sourceURL: viewModel.sourceURL,
                    timeRange: viewModel.selectedTimeRange
                )
                .environmentObject(environment)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .disabled(viewModel.isLoading)

            Spacer()
        }
        .navigationTitle("プレビュー")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .alert(
            "エラー",
            isPresented: .constant(viewModel.error != nil),
            presenting: viewModel.error
        ) { _ in
            Button("OK") { viewModel.error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
