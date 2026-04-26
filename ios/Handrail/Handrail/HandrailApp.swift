import SwiftUI

@main
struct HandrailApp: App {
    @State private var store = HandrailStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
