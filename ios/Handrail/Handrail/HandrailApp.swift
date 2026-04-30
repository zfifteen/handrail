import SwiftUI
import UIKit

final class HandrailAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            HandrailNotificationCoordinator.shared.updateRemotePushToken(
                deviceToken,
                environment: Self.apnsEnvironment
            )
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {}

    private static var apnsEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

@main
struct HandrailApp: App {
    @UIApplicationDelegateAdaptor(HandrailAppDelegate.self) private var appDelegate
    @State private var store = HandrailStore()
    @State private var iPadSelection = IPadWorkspaceSelection()
    @State private var showsIPadNewChat = false

    init() {
        HandrailNotificationCoordinator.shared.configure(remotePushEnabled: Self.remotePushEnabled)
    }

    var body: some Scene {
        WindowGroup {
            RootView(iPadSelection: $iPadSelection, showsIPadNewChat: $showsIPadNewChat)
                .environment(store)
                .preferredColorScheme(.dark)
                .onAppear {
                    HandrailNotificationCoordinator.shared.attach(store: store)
                }
        }
        .commands {
            HandrailCommands(store: store, selection: $iPadSelection, showsNewChat: $showsIPadNewChat)
        }
    }

    private static var remotePushEnabled: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }
}
