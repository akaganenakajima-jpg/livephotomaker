import PhotosUI
import SwiftUI

public struct VideoPickerView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ImportViewModel

    public init() {
        // Real environment injection happens in .task via onAppear-bound init.
        // For preview, we create a throwaway instance.
        _viewModel = StateObject(wrappedValue: ImportViewModel(analytics: AnalyticsService()))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(
                    selection: $viewModel.pickerItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    Label("動画を選ぶ", systemImage: "video.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)

                if let url = viewModel.pickedVideoURL {
                    NavigationLink("次へ") {
                        TrimPreviewView(sourceURL: url)
                            .environmentObject(environment)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(.top, 48)
            .navigationTitle("動画を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: viewModel.pickerItem) { _, newValue in
                Task { await viewModel.handlePicked(newValue) }
            }
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
}
