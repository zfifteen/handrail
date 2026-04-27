import SwiftUI

struct RootView: View {
    @Environment(HandrailStore.self) private var store
    @State private var selectedTab: HandrailTab = .dashboard
    @State private var dashboardPath = NavigationPath()
    @State private var sessionsPath = NavigationPath()

    var body: some View {
        @Bindable var store = store

        TabView(selection: $selectedTab) {
            NavigationStack(path: $dashboardPath) {
                DashboardView { sessionId in
                    dashboardPath.append(sessionId)
                }
            }
            .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }
            .tag(HandrailTab.dashboard)

            NavigationStack(path: $sessionsPath) {
                SessionsView { sessionId in
                    sessionsPath.append(sessionId)
                }
            }
            .tabItem { Label("Sessions", systemImage: "rectangle.stack") }
            .tag(HandrailTab.sessions)

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
        .onChange(of: store.lastStartedSessionId) { _, sessionId in
            guard let sessionId else { return }
            routeToStartedSession(sessionId)
            store.consumeLastStartedSessionId()
        }
        .onChange(of: store.notificationSessionId) { _, sessionId in
            guard let sessionId else { return }
            routeToNotificationSession(sessionId)
            store.consumeNotificationSessionId()
        }
        .sheet(isPresented: $store.showsApprovalFromNotification) {
            NavigationStack {
                ApprovalRequiredView()
            }
        }
    }

    private func routeToStartedSession(_ sessionId: String) {
        switch selectedTab {
        case .sessions:
            sessionsPath.append(sessionId)
        default:
            selectedTab = .dashboard
            dashboardPath.append(sessionId)
        }
    }

    private func routeToNotificationSession(_ sessionId: String) {
        selectedTab = .dashboard
        dashboardPath.append(sessionId)
    }
}

private enum HandrailTab {
    case dashboard
    case sessions
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
