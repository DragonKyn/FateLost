import SwiftUI

@main
struct FateLostApp: App {
    @State private var services = AppServices()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .environment(router)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
