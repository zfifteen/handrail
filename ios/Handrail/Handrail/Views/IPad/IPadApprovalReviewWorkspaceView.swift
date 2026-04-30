import SwiftUI

struct IPadApprovalReviewWorkspaceView: View {
    @Environment(HandrailStore.self) private var store
    @Binding var selection: IPadWorkspaceSelection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let approval {
                    summaryCard(approval)
                    reviewBody(approval)
                } else {
                    EmptyState(
                        title: "No approval selected",
                        detail: "Approval requests from the paired Mac will appear here.",
                        systemImage: "checkmark.seal"
                    )
                }
            }
            .padding(22)
            .safeAreaPadding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Approval")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let approval {
                    Button(role: .destructive) {
                        deny(approval)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(!canDecide(approval))
                    .accessibilityLabel("Deny selected request")

                    Button {
                        approve(approval)
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!canDecide(approval))
                    .accessibilityLabel("Approve selected request")
                }
            }
        }
    }

    private func summaryCard(_ approval: ApprovalRequest) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(approval.title.isEmpty ? "Approval required" : approval.title)
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)
                            .textSelection(.enabled)
                        Text(approval.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Spacer(minLength: 16)
                }

                if store.pairedMachine?.isOnline != true {
                    Label("Connect to your Mac to approve or deny this request.", systemImage: "wifi.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        deny(approval)
                    } label: {
                        Label("Deny", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canDecide(approval))
                    .hoverEffect(.highlight)

                    Button {
                        approve(approval)
                    } label: {
                        Label("Approve", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(!canDecide(approval))
                    .hoverEffect(.highlight)
                }
            }
        }
    }

    private func reviewBody(_ approval: ApprovalRequest) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                changedFiles(approval.files)
                    .frame(width: 260)
                diffPanel(approval.diff)
            }
            VStack(alignment: .leading, spacing: 16) {
                changedFiles(approval.files)
                diffPanel(approval.diff)
            }
        }
    }

    private func changedFiles(_ files: [String]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Changed files", systemImage: "doc.text")
                    .font(.headline)
                if files.isEmpty {
                    Text("No changed files were reported.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(files, id: \.self) { file in
                        Text(file)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func diffPanel(_ diff: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Diff", systemImage: "plusminus")
                    .font(.headline)
                if diff.isEmpty {
                    Text("No diff text was provided.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        Text(diff)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var approval: ApprovalRequest? {
        guard let latestApproval = store.latestApproval else { return nil }
        if let selectedApprovalId = selection.selectedApprovalId {
            guard selectedApprovalId == latestApproval.approvalId else { return nil }
        }
        return latestApproval
    }

    private func canDecide(_ approval: ApprovalRequest) -> Bool {
        HandrailCommandAvailability.resolve(
            pairedMachine: store.pairedMachine,
            selectedChat: store.chat(id: approval.chatId),
            selectedApprovalId: approval.approvalId,
            latestApproval: approval
        ).canApproveSelectedRequest
    }

    private func approve(_ approval: ApprovalRequest) {
        store.approve(approval)
        selection.selectedApprovalId = nil
    }

    private func deny(_ approval: ApprovalRequest) {
        store.deny(approval, reason: "Denied from Handrail.")
        selection.selectedApprovalId = nil
    }
}

#Preview {
    NavigationStack {
        IPadApprovalReviewWorkspaceView(selection: .constant(IPadWorkspaceSelection(selectedSection: .attention, selectedApprovalId: "approval")))
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
