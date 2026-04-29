import SwiftUI

struct AttentionView: View {
    @Environment(HandrailStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if visibleAttentionChats.isEmpty {
                    Card {
                        EmptyState(
                            title: "Nothing needs attention",
                            detail: "Failures and approval requests will appear here.",
                            systemImage: "checkmark.shield"
                        )
                    }
                } else {
                    ForEach(visibleAttentionChats) { chat in
                        attentionRow(chat)
                            .contextMenu {
                                Button {
                                    store.dismissAttention(chatId: chat.id)
                                } label: {
                                    Label("Dismiss", systemImage: "xmark.circle")
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .safeAreaPadding(.bottom, 96)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Attention")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Dismiss All") {
                    store.dismissAllAttention()
                }
                .disabled(visibleAttentionChats.isEmpty)
            }
        }
        .navigationDestination(for: String.self) { id in
            ChatDetailView(chatId: id)
        }
    }

    private func attentionRow(_ chat: CodexChat) -> some View {
        NavigationLink(value: chat.id) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon(for: chat))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color(for: chat))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 5) {
                    Text(displayTitle(for: chat))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(projectName(for: chat))
                        Text("•")
                        Text(chat.status.title)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(HandrailFormatters.relativeAge(since: sortDate(for: chat)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(14)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var visibleAttentionChats: [CodexChat] {
        store.chats
            .filter(store.needsAttention)
            .filter { !store.isAttentionDismissed(chatId: $0.id) }
            .sorted { sortDate(for: $0) > sortDate(for: $1) }
    }

    private func displayTitle(for chat: CodexChat) -> String {
        if chat.title.hasPrefix("Codex: ") {
            return String(chat.title.dropFirst("Codex: ".count))
        }
        return chat.title
    }

    private func projectName(for chat: CodexChat) -> String {
        chat.projectName ?? URL(fileURLWithPath: chat.repo).lastPathComponent
    }

    private func sortDate(for chat: CodexChat) -> Date {
        chat.updatedAt ?? chat.endedAt ?? chat.startedAt
    }

    private func icon(for chat: CodexChat) -> String {
        chat.status == .failed ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    private func color(for chat: CodexChat) -> Color {
        chat.status == .failed ? .red : .orange
    }
}

#Preview {
    NavigationStack {
        AttentionView()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
