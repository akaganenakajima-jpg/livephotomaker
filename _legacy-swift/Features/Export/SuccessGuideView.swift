import SwiftUI

public struct SuccessGuideView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("success.title")
                    .font(.title.bold())
                Text("success.body")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                guideStep(textKey: "success.step1", systemImage: "gear")
                guideStep(textKey: "success.step2", systemImage: "photo.on.rectangle")
                guideStep(textKey: "success.step3", systemImage: "plus.rectangle")
                guideStep(textKey: "success.step4", systemImage: "livephoto")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            Spacer()

            Button("success.done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
    }

    private func guideStep(textKey: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 24)
                .foregroundStyle(.tint)
            Text(textKey)
                .font(.callout)
        }
    }
}
