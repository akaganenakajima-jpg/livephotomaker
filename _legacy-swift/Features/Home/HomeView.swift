import SwiftUI

public struct HomeView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showImport = false
    @State private var showSettings = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "livephoto")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .foregroundStyle(.tint)

                    Text("home.title")
                        .font(.largeTitle.bold())

                    Text("home.subtitle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button {
                    showImport = true
                } label: {
                    Text("home.start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)

                Button("home.settings") {
                    showSettings = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
            .fullScreenCover(isPresented: $showImport) {
                VideoPickerView()
                    .environmentObject(environment)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(environment)
            }
        }
    }
}
