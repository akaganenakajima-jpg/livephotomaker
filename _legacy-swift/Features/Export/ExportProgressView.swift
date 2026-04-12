import SwiftUI

public struct ExportProgressView: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
            Text(message.isEmpty ? String(localized: "export.progress.title") : message)
                .font(.headline)
            Text("export.progress.hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden(true)
    }
}
