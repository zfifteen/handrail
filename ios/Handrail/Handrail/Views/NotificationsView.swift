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
                    if let chatId = item.chatId {
                        NavigationLink(value: chatId) {
                            notificationContent(item)
                        }
                    } else {
                        notificationContent(item)
                    }
                }
                .onDelete(perform: store.deleteNotifications)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear All") {
                    store.clearNotifications()
                }
                .disabled(store.notifications.isEmpty)
            }
        }
        .navigationDestination(for: String.self) { chatId in
            ChatDetailView(chatId: chatId)
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
