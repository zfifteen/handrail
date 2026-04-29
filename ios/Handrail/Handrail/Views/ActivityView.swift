import SwiftUI

struct ActivityView: View {
    @Environment(HandrailStore.self) private var store

    var body: some View {
        List {
            if store.activity.isEmpty {
                EmptyState(title: "No activity yet", detail: "Chat events will build a timeline here.", systemImage: "waveform.path.ecg")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(store.activity) { item in
                    if let chatId = item.chatId {
                        NavigationLink(value: chatId) {
                            activityContent(item)
                        }
                    } else {
                        activityContent(item)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Activity")
        .navigationDestination(for: String.self) { chatId in
            ChatDetailView(chatId: chatId)
        }
    }

    private func activityContent(_ item: ActivityItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title.capitalized)
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
