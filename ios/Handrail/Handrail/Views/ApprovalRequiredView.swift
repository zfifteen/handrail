import SwiftUI

struct ApprovalRequiredView: View {
    @Environment(HandrailStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            if let approval = store.latestApproval {
                ScrollView {
                    VStack(spacing: 14) {
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(approval.title.isEmpty ? "Approval required" : approval.title)
                                        .font(.title2.weight(.bold))
                                    Spacer(minLength: 8)
                                    if let badge = approvalKindBadge(for: approval) {
                                        Text(badge)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.2), in: Capsule())
                                            .foregroundStyle(.orange)
                                    }
                                }
                                if let chatTitle = chatTitle(for: approval) {
                                    Label(chatTitle, systemImage: "bubble.left.and.bubble.right")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text(approval.summary)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                        }
                        if !approval.files.isEmpty {
                            Card {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Changed files", systemImage: "doc.on.doc")
                                        .font(.headline)
                                    ForEach(approval.files, id: \.self) { file in
                                        Text(file)
                                            .font(.caption.monospaced())
                                    }
                                }
                            }
                        }
                        if !approval.diff.isEmpty {
                            Card {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Diff", systemImage: "plus.forwardslash.minus")
                                        .font(.headline)
                                    ScrollView(.horizontal) {
                                        Text(approval.diff)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                HStack {
                    Button(role: .destructive) {
                        store.deny(approval, reason: "Denied from Handrail.")
                    } label: {
                        Text("Deny")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.approve(approval)
                    } label: {
                        Text("Approve")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .background(Color.black)
            } else {
                EmptyState(title: "No approval pending", detail: "Tool approval requests from Grok chats appear here.", systemImage: "checkmark.shield")
                    .padding()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Approval")
    }

    private func chatTitle(for approval: ApprovalRequest) -> String? {
        guard let chat = store.chat(id: approval.chatId) else {
            return nil
        }
        let title = HandrailFormatters.strippedAssistantTitle(chat.title)
        return title.isEmpty ? chat.projectName : title
    }

    private func approvalKindBadge(for approval: ApprovalRequest) -> String? {
        let title = approval.title.lowercased()
        if title.contains("command") {
            return "Command"
        }
        if title.contains("file") {
            return "File"
        }
        if title.contains("tool") {
            return "Tool"
        }
        return nil
    }
}