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
                                Text("Approval Required")
                                    .font(.title2.weight(.bold))
                                Text(store.session(id: approval.sessionId)?.title ?? approval.sessionId)
                                    .foregroundStyle(.secondary)
                                Text(approval.summary)
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Changed files", systemImage: "doc.on.doc")
                                    .font(.headline)
                                if approval.files.isEmpty {
                                    Text("No changed files detected.")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(approval.files, id: \.self) { file in
                                        Text(file)
                                            .font(.caption.monospaced())
                                    }
                                }
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Diff", systemImage: "plus.forwardslash.minus")
                                    .font(.headline)
                                ScrollView(.horizontal) {
                                    Text(approval.diff.isEmpty ? "No diff available." : approval.diff)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
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
                    .tint(.purple)
                }
                .padding()
                .background(Color.black)
            } else {
                EmptyState(title: "No approval pending", detail: "Approval requests from Codex sessions appear here.", systemImage: "checkmark.shield")
                    .padding()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Approval")
    }
}
