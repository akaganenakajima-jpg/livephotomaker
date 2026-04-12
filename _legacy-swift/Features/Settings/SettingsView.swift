import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(environment: AppEnvironment.live()))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("ステータス") {
                    HStack {
                        Text("高画質解放")
                        Spacer()
                        Text(viewModel.isPremium ? "購入済み" : "未購入")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("購入") {
                    Button("購入を復元") {
                        Task { await viewModel.restore() }
                    }
                }

                Section("このアプリについて") {
                    Text("本アプリは動画をLive Photoへ変換して写真ライブラリへ保存します。壁紙の設定はiPhone標準の「設定」Appから行ってください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.refresh() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
