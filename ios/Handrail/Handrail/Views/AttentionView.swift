import SwiftUI

struct AttentionView: View {
    @Environment(HandrailStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if visibleAttentionSessions.isEmpty {
                    Card {
                        EmptyState(
                            title: "Nothing needs attention",
                            detail: "Failures and approval requests will appear here.",
                            systemImage: "checkmark.shield"
                        )
                    }
                } else {
                    ForEach(visibleAttentionSessions) { session in
                        attentionRow(session)
                            .contextMenu {
                                Button {
                                    store.dismissAttention(sessionId: session.id)
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
                .disabled(visibleAttentionSessions.isEmpty)
            }
        }
        .navigationDestination(for: String.self) { id in
            SessionDetailView(sessionId: id)
        }
    }

    private func attentionRow(_ session: HandrailSession) -> some View {
        NavigationLink(value: session.id) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon(for: session))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color(for: session))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 5) {
                    Text(displayTitle(for: session))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(projectName(for: session))
                        Text("•")
                        Text(session.status.title)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(HandrailFormatters.relativeAge(since: sortDate(for: session)))
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

    private var visibleAttentionSessions: [HandrailSession] {
        store.sessions
            .filter(store.needsAttention)
            .filter { !store.isAttentionDismissed(sessionId: $0.id) }
            .sorted { sortDate(for: $0) > sortDate(for: $1) }
    }

    private func displayTitle(for session: HandrailSession) -> String {
        if session.title.hasPrefix("Codex: ") {
            return String(session.title.dropFirst("Codex: ".count))
        }
        return session.title
    }

    private func projectName(for session: HandrailSession) -> String {
        URL(fileURLWithPath: session.repo).lastPathComponent
    }

    private func sortDate(for session: HandrailSession) -> Date {
        session.updatedAt ?? session.endedAt ?? session.startedAt
    }

    private func icon(for session: HandrailSession) -> String {
        session.status == .failed ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    private func color(for session: HandrailSession) -> Color {
        session.status == .failed ? .red : .orange
    }
}

#Preview {
    NavigationStack {
        AttentionView()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
