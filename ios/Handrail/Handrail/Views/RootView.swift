import SwiftUI

struct RootView: View {
    @State private var sessionsPath = NavigationPath()

    var body: some View {
        TabView {
            NavigationStack(path: $sessionsPath) {
                SessionsView { sessionId in
                    sessionsPath.append(sessionId)
                }
            }
            .tabItem { Label("Sessions", systemImage: "rectangle.stack") }

            NavigationStack {
                ApprovalRequiredView()
            }
            .tabItem { Label("Approval", systemImage: "checkmark.shield") }

            NavigationStack {
                ActivityView()
            }
            .tabItem { Label("Activity", systemImage: "waveform.path.ecg") }

            NavigationStack {
                NotificationsView()
            }
            .tabItem { Label("Alerts", systemImage: "bell") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.purple)
    }
}

#Preview {
    RootView()
        .environment(PreviewData.store)
        .preferredColorScheme(.dark)
}
