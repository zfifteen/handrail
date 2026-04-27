import SwiftUI

@main
struct HandrailApp: App {
    @State private var store = HandrailStore()

    init() {
        HandrailNotificationCoordinator.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .onAppear {
                    HandrailNotificationCoordinator.shared.attach(store: store)
                }
        }
    }
}
