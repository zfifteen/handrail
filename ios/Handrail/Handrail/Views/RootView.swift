import SwiftUI
import UIKit

struct RootView: View {
    @Environment(HandrailStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var iPadSelection: IPadWorkspaceSelection
    @Binding var showsIPadNewChat: Bool
    @Binding var focusesIPadChatSearch: Bool
    @State private var showsLaunchSplash = true
    @State private var launchSplashOpacity = 1.0
    @State private var phoneRoute: PhoneRootRoute?
    @State private var phoneRouteToken = 0

    init(
        iPadSelection: Binding<IPadWorkspaceSelection> = .constant(IPadWorkspaceSelection()),
        showsIPadNewChat: Binding<Bool> = .constant(false),
        focusesIPadChatSearch: Binding<Bool> = .constant(false)
    ) {
        self._iPadSelection = iPadSelection
        self._showsIPadNewChat = showsIPadNewChat
        self._focusesIPadChatSearch = focusesIPadChatSearch
    }

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
        .sheet(isPresented: $showsIPadNewChat) {
            NavigationStack {
                IPadNewChatPanel()
            }
            .environment(store)
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
            IPadWorkspaceRootView(
                selection: $iPadSelection,
                showsNewChat: $showsIPadNewChat,
                focusesChatSearch: $focusesIPadChatSearch
            )
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
            iPadSelection.selectChat(id: chatId)
            showsIPadNewChat = false
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
            iPadSelection.selectChat(id: chatId)
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
        .overlay(alignment: .bottom) {
            PhoneTabAccessibilityBar(selectedTab: $selectedTab)
        }
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

enum HandrailTab {
    case dashboard
    case chats
    case attention
    case activity
    case alerts
    case settings
}

enum PhoneTabBarMetrics {
    static let accessibilityHeight: CGFloat = 83
    static let contentBottomInset: CGFloat = 96
}

enum PhoneTabAccessibilityItem: String, CaseIterable, Identifiable, Equatable {
    case dashboard = "Dashboard"
    case chats = "Chats"
    case attention = "Attention"
    case activity = "Activity"
    case more = "More"

    var id: String { rawValue }

    var targetTab: HandrailTab {
        switch self {
        case .dashboard: .dashboard
        case .chats: .chats
        case .attention: .attention
        case .activity: .activity
        case .more: .alerts
        }
    }

    func isSelected(_ selectedTab: HandrailTab) -> Bool {
        switch self {
        case .dashboard:
            selectedTab == .dashboard
        case .chats:
            selectedTab == .chats
        case .attention:
            selectedTab == .attention
        case .activity:
            selectedTab == .activity
        case .more:
            selectedTab == .alerts || selectedTab == .settings
        }
    }
}

private struct PhoneTabAccessibilityBar: View {
    @Binding var selectedTab: HandrailTab

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(PhoneTabAccessibilityItem.allCases) { item in
                    Button {
                        selectedTab = item.targetTab
                    } label: {
                        Color.clear
                            .frame(
                                maxWidth: .infinity,
                                minHeight: PhoneTabBarMetrics.accessibilityHeight,
                                maxHeight: PhoneTabBarMetrics.accessibilityHeight
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.rawValue)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(item.isSelected(selectedTab) ? .isSelected : [])
                }
            }
            .frame(height: PhoneTabBarMetrics.accessibilityHeight)
            .offset(y: proxy.safeAreaInsets.bottom)
            .accessibilityElement(children: .contain)
        }
        .frame(height: PhoneTabBarMetrics.accessibilityHeight)
    }
}

#Preview {
    RootView()
        .environment(PreviewData.store)
        .preferredColorScheme(.dark)
}
