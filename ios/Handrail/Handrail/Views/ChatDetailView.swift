import SwiftUI

struct ChatDetailView: View {
    @Environment(HandrailStore.self) private var store
    let chatId: String
    @State private var input = ""
    @State private var showJumpToLatest = false
    @State private var pendingContinuePrompt: String?
    @State private var pendingSendInput: String?
    @State private var expandedThinkingRounds: Set<Int> = []
    @State private var showsStopConfirmation = false
    @State private var approvalResultText: String?
    @State private var deniedApproval: ApprovalRequest?
    @State private var denialReason = ""
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            chatSurface
            if canControlChat {
                if canSendInput {
                    sendingInputStatus
                    composer(placeholder: "Ask Codex", isPending: pendingSendInput != nil) { text in
                        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        pendingSendInput = prompt
                        if !store.usesStaticPreviewData {
                            store.sendInput(chatId: chatId, text: prompt)
                        }
                    }
                }
            } else if canStartFollowUp {
                composer(placeholder: "Ask Codex", isPending: pendingContinuePrompt != nil) { text in
                    let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    pendingContinuePrompt = prompt
                    store.continueChat(chatId: chatId, prompt: prompt)
                }
            } else if store.chat(id: chatId) != nil {
                readOnlyNotice(store.pairedMachine?.isOnline == true ? "This Codex chat cannot receive input right now." : "Connect to your Mac to keep chatting.")
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(displayTitle(store.chat(id: chatId)?.title ?? "Chat"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.clearChatError(chatId: chatId)
            store.enterChat(chatId: chatId)
            if store.pairedMachine?.isOnline == true && !store.usesStaticPreviewData {
                store.refreshChatDetail(chatId: chatId)
            }
        }
        .onDisappear {
            store.leaveChat(chatId: chatId)
        }
        .task(id: chatId) {
            await refreshVisibleChatUntilCancelled()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if canDismissAttention {
                    Button {
                        store.dismissAttention(chatId: chatId)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("Dismiss attention item")
                }
                if canControlChat {
                    Button(role: .destructive) {
                        showsStopConfirmation = true
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .accessibilityLabel("Stop")
                }
            }
        }
        .confirmationDialog("Stop Codex?", isPresented: $showsStopConfirmation, titleVisibility: .visible) {
            Button("Stop", role: .destructive) {
                store.stop(chatId: chatId)
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $deniedApproval) { approval in
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Reason")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Reason", text: $denialReason, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                }
                .padding()
                .background(Color.black.ignoresSafeArea())
                .navigationTitle("Deny")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            deniedApproval = nil
                            denialReason = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send denial") {
                            deny(approval, reason: denialReason.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                }
            }
        }
    }

    private var chatSurface: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 14) {
                        if let chat = store.chat(id: chatId) {
                            chatHeader(chat)
                            attentionSummary(chat)
                            files(chat.files ?? [])
                        }
                        chatMessages
                        Color.clear
                            .frame(height: 1)
                            .id(bottomId)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { _ in dismissComposerKeyboard() })
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    scrollToLatest(proxy, animated: false)
                }
                .onChange(of: transcriptText) { _, _ in
                    clearCompletedSendInputIfNeeded()
                    clearCompletedContinuePromptIfNeeded()
                    scrollToLatest(proxy, animated: true)
                }
                .onChange(of: thinkingSignature) { _, _ in
                    scrollToLatest(proxy, animated: true)
                }
                .onChange(of: chatError) { _, error in
                    if error != nil {
                        pendingSendInput = nil
                        pendingContinuePrompt = nil
                    }
                }
                .simultaneousGesture(
                    DragGesture().onChanged { value in
                        if value.translation.height < -12 {
                            showJumpToLatest = true
                        }
                    }
                )

                if showJumpToLatest {
                    Button {
                        scrollToLatest(proxy, animated: true)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.body.weight(.bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(.secondary)
                    .padding(.trailing, 18)
                    .padding(.bottom, 12)
                    .accessibilityLabel("Jump to latest message")
                }
            }
        }
    }

    private var canControlChat: Bool {
        guard let chat = store.chat(id: chatId) else { return false }
        return store.pairedMachine?.isOnline == true &&
            (chat.status == .running || chat.status == .waitingForApproval)
    }

    private var canSendInput: Bool {
        store.chat(id: chatId)?.acceptsInput == true
    }

    private var canStartFollowUp: Bool {
        guard let chat = store.chat(id: chatId) else { return false }
        return store.pairedMachine?.isOnline == true &&
            chat.status != .running &&
            chat.status != .waitingForApproval
    }

    private var canDismissAttention: Bool {
        guard let chat = store.chat(id: chatId) else { return false }
        return store.needsAttention(chat) && !store.isAttentionDismissed(chatId: chatId)
    }

    private func chatHeader(_ chat: CodexChat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusBadge(status: chat.status)
            Text(chat.repo)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func files(_ files: [String]) -> some View {
        Group {
            if !files.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Files", systemImage: "doc.text")
                            .font(.headline)
                        ForEach(files, id: \.self) { file in
                            Text(file)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func attentionSummary(_ chat: CodexChat) -> some View {
        Group {
            if let approval = store.latestApproval, approval.chatId == chat.id {
                approvalPanel(approval)
            } else if store.needsAttention(chat) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(chat.status == .failed ? "Needs attention" : "Approval required", systemImage: chat.status == .failed ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(chat.status == .failed ? .red : .orange)
                        Text(attentionDetail(for: chat))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func approvalPanel(_ approval: ApprovalRequest) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Approval required", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(approval.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if let approvalResultText {
                    Label(approvalResultText, systemImage: approvalResultText == "Approved" ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(approvalResultText == "Approved" ? .green : .red)
                }

                if !approval.files.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Changed files")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(approval.files, id: \.self) { file in
                            Text(file)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }

                if !approval.diff.isEmpty {
                    DisclosureGroup("Diff") {
                        ScrollView(.horizontal) {
                            Text(approval.diff)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }

                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        deniedApproval = approval
                        denialReason = ""
                    } label: {
                        Text("Deny")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        approve(approval)
                    } label: {
                        Text("Approve")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
        }
    }

    private func approve(_ approval: ApprovalRequest) {
        approvalResultText = "Approved"
        guard !store.usesStaticPreviewData else { return }
        store.approve(approval)
    }

    private func deny(_ approval: ApprovalRequest, reason: String) {
        approvalResultText = "Denied"
        deniedApproval = nil
        denialReason = ""
        guard !store.usesStaticPreviewData else { return }
        store.deny(approval, reason: reason.isEmpty ? "Denied from Handrail." : reason)
    }

    private func attentionDetail(for chat: CodexChat) -> String {
        if chat.status == .waitingForApproval {
            return "Codex is waiting for a decision before it can continue."
        }
        let text = transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return "This chat failed before readable output was received."
        }
        return ChatBlock.failureSummary(from: text)
    }

    private var chatMessages: some View {
        ChatTranscriptView(
            blocks: chatBlocks,
            thinkingEntries: thinkingEntries,
            isWorking: isChatWorking,
            error: chatError,
            emptyText: emptyChatText,
            expandedThinkingRounds: $expandedThinkingRounds
        )
    }

    private func composer(placeholder: String, isPending: Bool, action: @escaping (String) -> Void) -> some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($isComposerFocused)
            Button {
                action(input)
                input = ""
                dismissComposerKeyboard()
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .disabled(ChatDetailComposerState.isSendDisabled(input: input, isPending: isPending))
        }
        .padding()
        .background(Color.black)
    }

    @ViewBuilder
    private var sendingInputStatus: some View {
        if pendingSendInput != nil {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Sending...")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Stop", role: .destructive) {
                    showsStopConfirmation = true
                }
                .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black)
        }
    }

    private func readOnlyNotice(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
    }

    private var emptyChatText: String {
        guard let chat = store.chat(id: chatId) else {
            return "Chat not found."
        }
        switch chat.status {
        case .running:
            return "Codex is starting. Messages will appear here."
        case .waitingForApproval:
            return "Waiting for approval."
        case .completed:
            return "This chat completed without visible messages."
        case .failed:
            return "This chat failed before visible messages arrived."
        case .stopped:
            return "This chat stopped before visible messages arrived."
        case .idle:
            return "No messages are available for this chat yet."
        }
    }

    private var transcriptText: String {
        (store.transcripts[chatId] ?? []).joined()
    }

    private var chatError: String? {
        store.chatErrors[chatId]
    }

    private var isChatWorking: Bool {
        store.chat(id: chatId)?.status == .running
    }

    private var chatBlocks: [ChatBlock] {
        ChatBlock.parse(transcriptText)
    }

    private var thinkingEntries: [ThinkingEntry] {
        store.chat(id: chatId)?.thinking ?? []
    }

    private var thinkingSignature: String {
        thinkingEntries.map { "\($0.id):\($0.round):\($0.text.count)" }.joined(separator: "|")
    }

    private var bottomId: String {
        "bottom-\(chatId)"
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool) {
        let action = {
            proxy.scrollTo(bottomId, anchor: .bottom)
            showJumpToLatest = false
        }
        if animated {
            withAnimation(.easeOut(duration: 0.22), action)
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    private func clearCompletedContinuePromptIfNeeded() {
        guard let pendingContinuePrompt else { return }
        if transcriptText.contains(pendingContinuePrompt) {
            input = ""
            self.pendingContinuePrompt = nil
        }
    }

    private func clearCompletedSendInputIfNeeded() {
        guard let pendingSendInput else { return }
        if transcriptText.contains(pendingSendInput) {
            self.pendingSendInput = nil
        }
    }

    private func dismissComposerKeyboard() {
        isComposerFocused = false
    }

    @MainActor
    private func refreshVisibleChatUntilCancelled() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !store.usesStaticPreviewData else { continue }
            if store.pairedMachine?.isOnline == true && store.isViewingChat(chatId: chatId) {
                store.refreshChatDetail(chatId: chatId)
            }
        }
    }

    private func displayTitle(_ title: String) -> String {
        if title.hasPrefix("Codex: ") {
            return String(title.dropFirst("Codex: ".count))
        }
        return title
    }
}

enum ChatDetailComposerState {
    static func isSendDisabled(input: String, isPending: Bool) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPending
    }
}
