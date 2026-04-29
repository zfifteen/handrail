import SwiftUI

struct RootView: View {
    @Environment(HandrailStore.self) private var store
    @State private var selectedTab: HandrailTab = .dashboard
    @State private var dashboardPath = NavigationPath()
    @State private var chatsPath = NavigationPath()

    var body: some View {
        @Bindable var store = store

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
    }

    private func routeToStartedChat(_ chatId: String) {
        switch selectedTab {
        case .chats:
            chatsPath.append(chatId)
        default:
            selectedTab = .dashboard
            dashboardPath.append(chatId)
        }
    }

    private func routeToNotificationChat(_ chatId: String) {
        selectedTab = .dashboard
        dashboardPath.append(chatId)
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
