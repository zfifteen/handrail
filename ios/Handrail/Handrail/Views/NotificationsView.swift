import SwiftUI

struct NotificationsView: View {
    @Environment(HandrailStore.self) private var store

    var body: some View {
        List {
            if store.notifications.isEmpty {
                EmptyState(title: "No notifications", detail: "Approvals, failed tests, and completed tasks appear here.", systemImage: "bell")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(store.notifications) { item in
                    if let sessionId = item.sessionId {
                        NavigationLink(value: sessionId) {
                            notificationContent(item)
                        }
                    } else {
                        notificationContent(item)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationDestination(for: String.self) { sessionId in
            SessionDetailView(sessionId: sessionId)
        }
    }

    private func notificationContent(_ item: HandrailNotification) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
            Text(item.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(HandrailFormatters.time.string(from: item.date))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}
