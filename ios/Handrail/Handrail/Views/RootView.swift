import SwiftUI
import UIKit

struct RootView: View {
    @Environment(HandrailStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsLaunchSplash = true
    @State private var launchSplashOpacity = 1.0
    @State private var phoneRoute: PhoneRootRoute?
    @State private var phoneRouteToken = 0
    @State private var iPadSelection = IPadWorkspaceSelection()

    var body: some View {
        @Bindable var store = store

        ZStack {
            rootContent

            if showsLaunchSplash {
                LaunchSplashView()
                    .opacity(launchSplashOpacity)
                    .allowsHitTesting(true)
            }
        }
        .onChange(of: store.lastStartedChatId) { _, chatId in
            guard let chatId else { return }
            routeToStartedChat(chatId)
            store.consumeLastStartedChatId()
        }
        .onChange(of: store.notificationChatId) { _, chatId in
            guard let chatId else { return }
            routeToNotificationChat(chatId)
            store.consumeNotificationChatId()
        }
        .sheet(isPresented: $store.showsApprovalFromNotification) {
            NavigationStack {
                ApprovalRequiredView()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.5)) {
                launchSplashOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.5))
            showsLaunchSplash = false
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch HandrailRootLayoutResolver.mode(
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass
        ) {
        case .phone:
            PhoneRootView(route: $phoneRoute)
        case .iPadRegular:
            IPadWorkspaceRootView(selection: $iPadSelection)
        }
    }

    private func routeToStartedChat(_ chatId: String) {
        switch HandrailRootLayoutResolver.mode(
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass
        ) {
        case .phone:
            phoneRouteToken += 1
            phoneRoute = PhoneRootRoute(kind: .startedChat, chatId: chatId, token: phoneRouteToken)
        case .iPadRegular:
            iPadSelection.selectedSection = .chats
            iPadSelection.selectedChatId = chatId
        }
    }

    private func routeToNotificationChat(_ chatId: String) {
        switch HandrailRootLayoutResolver.mode(
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass
        ) {
        case .phone:
            phoneRouteToken += 1
            phoneRoute = PhoneRootRoute(kind: .notificationChat, chatId: chatId, token: phoneRouteToken)
        case .iPadRegular:
            iPadSelection.selectedSection = .chats
            iPadSelection.selectedChatId = chatId
        }
    }
}

enum HandrailRootLayoutMode: Equatable {
    case phone
    case iPadRegular
}

enum HandrailRootLayoutResolver {
    static func mode(
        userInterfaceIdiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> HandrailRootLayoutMode {
        guard userInterfaceIdiom == .pad, horizontalSizeClass == .regular else {
            return .phone
        }
        return .iPadRegular
    }
}

struct PhoneRootRoute: Equatable {
    enum Kind: Equatable {
        case startedChat
        case notificationChat
    }

    let kind: Kind
    let chatId: String
    let token: Int
}

struct PhoneRootView: View {
    @Binding var route: PhoneRootRoute?
    @State private var selectedTab: HandrailTab = .dashboard
    @State private var dashboardPath = NavigationPath()
    @State private var chatsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $dashboardPath) {
                DashboardView { chatId in
                    dashboardPath.append(chatId)
                }
            }
            .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }
            .tag(HandrailTab.dashboard)

            NavigationStack(path: $chatsPath) {
                ChatsView { chatId in
                    chatsPath.append(chatId)
                }
            }
            .tabItem { Label("Chats", systemImage: "rectangle.stack") }
            .tag(HandrailTab.chats)

            NavigationStack {
                AttentionView()
            }
            .tabItem { Label("Attention", systemImage: "exclamationmark.triangle") }
            .tag(HandrailTab.attention)

            NavigationStack {
                ActivityView()
            }
            .tabItem { Label("Activity", systemImage: "waveform.path.ecg") }
            .tag(HandrailTab.activity)

            NavigationStack {
                NotificationsView()
            }
            .tabItem { Label("Alerts", systemImage: "bell") }
            .tag(HandrailTab.alerts)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(HandrailTab.settings)
        }
        .tint(.purple)
        .onChange(of: route) { _, route in
            guard let route else { return }
            handle(route)
        }
    }

    private func handle(_ route: PhoneRootRoute) {
        switch route.kind {
        case .startedChat:
            switch selectedTab {
            case .chats:
                chatsPath.append(route.chatId)
            default:
                selectedTab = .dashboard
                dashboardPath.append(route.chatId)
            }
        case .notificationChat:
            selectedTab = .dashboard
            dashboardPath.append(route.chatId)
        }
    }
}

private enum HandrailTab {
    case dashboard
    case chats
    case attention
    case activity
    case alerts
    case settings
}

#Preview {
    RootView()
        .environment(PreviewData.store)
        .preferredColorScheme(.dark)
}
