import SwiftUI

public struct PaywallView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PurchaseViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: PurchaseViewModel(environment: AppEnvironment.live()))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .padding(.top, 32)

                Text("paywall.title")
                    .font(.largeTitle.bold())

                Text("paywall.body")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let product = viewModel.product {
                    VStack(spacing: 4) {
                        Text(product.displayPrice)
                            .font(.title2.bold())
                        Text("買い切り・追加課金なし")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("paywall.cta.buy") {
                    Task { await viewModel.buy() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 24)

                Button("paywall.cta.restore") {
                    Task { await viewModel.restore() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.didPurchase) { _, didPurchase in
                if didPurchase { dismiss() }
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
