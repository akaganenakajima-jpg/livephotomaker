import AVFoundation
import SwiftUI

public struct ExportOptionsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: ExportViewModel
    @State private var showPaywall = false

    public init(sourceURL: URL, timeRange: CMTimeRange?) {
        // StateObject initialization requires a placeholder; the real
        // environment is re-bound in `.task`.
        _viewModel = StateObject(
            wrappedValue: ExportViewModel(
                sourceURL: sourceURL,
                timeRange: timeRange,
                environment: AppEnvironment.live()
            )
        )
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("export.options.title")
                .font(.title2.bold())
                .padding(.top, 16)

            optionCard(
                titleKey: "export.options.standard",
                detailKey: "export.options.standard.detail",
                systemImage: "square.and.arrow.down",
                tint: .blue
            ) {
                Task { await viewModel.startStandardExport() }
            }

            if environment.entitlement != .premiumUnlocked {
                optionCard(
                    titleKey: "export.options.rewarded",
                    detailKey: "export.options.rewarded.detail",
                    systemImage: "play.rectangle",
                    tint: .orange
                ) {
                    Task { await runRewardedFlow() }
                }

                optionCard(
                    titleKey: "export.options.premium",
                    detailKey: "export.options.premium.detail",
                    systemImage: "sparkles",
                    tint: .purple
                ) {
                    showPaywall = true
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .navigationTitle("書き出し")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(environment)
        }
        .navigationDestination(
            isPresented: Binding(
                get: { viewModel.route == .progress },
                set: { _ in }
            )
        ) {
            ExportProgressView(message: viewModel.progressMessage)
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

    private func optionCard(
        titleKey: LocalizedStringKey,
        detailKey: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detailKey)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func runRewardedFlow() async {
        environment.analytics.track(.rewardedTrialRequested)
        // Without a real ad SDK this returns .failed and falls back naturally.
        let result = await environment.ads.presentRewarded(
            from: UIViewController()
        )
        let granted = viewModel.grantTrialAfterAd(result: result)
        if granted {
            await viewModel.startHighQualityExport()
        }
    }
}
