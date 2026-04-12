import SwiftUI

@main
struct LivePhotoMakerApp: App {
    @StateObject private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(environment)
                .task {
                    await environment.bootstrap()
                }
        }
    }
}
