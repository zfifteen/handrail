import SwiftUI

struct IPadActivityWorkspaceView: View {
    @Environment(HandrailStore.self) private var store
    @Binding var selection: IPadWorkspaceSelection

    var body: some View {
        List {
            if store.activity.isEmpty {
                EmptyState(
                    title: "No activity yet",
                    detail: "Chat events will build a timeline here.",
                    systemImage: "waveform.path.ecg"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.activity) { item in
                    if let chatId = item.chatId {
                        Button {
                            selection.selectChat(id: chatId)
                        } label: {
                            activityContent(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                        .listRowBackground(chatId == selection.selectedChatId ? Color.accentColor.opacity(0.16) : Color.clear)
                        .accessibilityLabel("\(item.title), \(item.detail)")
                    } else {
                        activityContent(item)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Activity")
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

#Preview {
    NavigationStack {
        IPadActivityWorkspaceView(selection: .constant(IPadWorkspaceSelection(selectedSection: .activity, selectedChatId: "preview-chat")))
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
