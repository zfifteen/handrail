import SwiftUI

struct IPadChatDetailWorkspaceView: View {
    @Environment(HandrailStore.self) private var store
    @Binding var selection: IPadWorkspaceSelection
    @State private var input = ""
    @State private var showJumpToLatest = false
    @State private var pendingContinuePrompt: String?
    @State private var expandedThinkingRounds: Set<Int> = []
    @State private var enteredChatId: String?
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            detailSurface
            composerSurface
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if commandAvailability.canStopSelectedChat, let chatId = selectedChat?.id {
                    Button(role: .destructive) {
                        store.stop(chatId: chatId)
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .keyboardShortcut(".", modifiers: .command)
                    .hoverEffect(.highlight)
                    .accessibilityLabel("Stop selected chat")
                }
                if commandAvailability.canContinueSelectedChat {
                    Button {
                        isComposerFocused = true
                    } label: {
                        Image(systemName: "text.bubble")
                    }
                    .hoverEffect(.highlight)
                    .accessibilityLabel("Focus follow-up composer")
                }
            }
        }
        .background(dismissComposerShortcut)
        .onAppear {
            enterVisibleChatIfNeeded()
        }
        .onDisappear {
            leaveEnteredChatIfNeeded()
        }
        .onChange(of: selection.selectedChatId) { _, _ in
            leaveEnteredChatIfNeeded()
            input = ""
            pendingContinuePrompt = nil
            expandedThinkingRounds.removeAll()
            enterVisibleChatIfNeeded()
        }
        .task(id: selection.selectedChatId) {
            await refreshVisibleChatUntilCancelled()
        }
    }

    private var detailSurface: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let chat = selectedChat {
                            header(chat)
                            attentionSummary(chat)
                            filesSection(chat.files ?? [])
                            ChatTranscriptView(
                                blocks: chatBlocks,
                                thinkingEntries: thinkingEntries,
                                isWorking: chat.status == .running,
                                error: chatError,
                                emptyText: emptyChatText(for: chat),
                                expandedThinkingRounds: $expandedThinkingRounds
                            )
                        } else {
                            EmptyState(
                                title: "No chat selected",
                                detail: "Select a chat from the list to review its transcript and controls.",
                                systemImage: "text.bubble"
                            )
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(bottomId)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { _ in isComposerFocused = false })
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    scrollToLatest(proxy, animated: false)
                }
                .onChange(of: transcriptText) { _, _ in
                    clearCompletedContinuePromptIfNeeded()
                    scrollToLatest(proxy, animated: true)
                }
                .onChange(of: thinkingSignature) { _, _ in
                    scrollToLatest(proxy, animated: true)
                }
                .onChange(of: chatError) { _, error in
                    if error != nil {
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
                    .tint(.purple)
                    .hoverEffect(.highlight)
                    .padding(.trailing, 22)
                    .padding(.bottom, 14)
                    .accessibilityLabel("Jump to latest message")
                }
            }
        }
    }

    @ViewBuilder
    private var composerSurface: some View {
        if let chat = selectedChat {
            if canSendInput(chat) {
                composer(placeholder: "Send input") { text in
                    store.sendInput(chatId: chat.id, text: text)
                }
            } else if canStartFollowUp(chat) {
                followUpComposer(chat)
            } else {
                readOnlyNotice(readOnlyText(for: chat))
            }
        }
    }

    private func header(_ chat: CodexChat) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(IPadChatListQuery.displayTitle(for: chat))
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)
                            .textSelection(.enabled)
                        Text(IPadChatListQuery.projectName(for: chat))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }

                    Spacer(minLength: 16)

                    VStack(alignment: .trailing, spacing: 8) {
                        StatusBadge(status: chat.status)
                        Text("Updated \(HandrailFormatters.relativeAge(since: sortDate(for: chat)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                HStack(spacing: 10) {
                    Label(chat.repo, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 10)

                    if commandAvailability.canStopSelectedChat {
                        Button(role: .destructive) {
                            store.stop(chatId: chat.id)
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .hoverEffect(.highlight)
                    }

                    if commandAvailability.canContinueSelectedChat {
                        Button {
                            isComposerFocused = true
                        } label: {
                            Label("Continue", systemImage: "text.bubble")
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        .hoverEffect(.highlight)
                    }
                }
            }
        }
    }

    private func filesSection(_ files: [String]) -> some View {
        Group {
            if !files.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Files changed", systemImage: "doc.text")
                            .font(.headline)
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
        let canDecide = store.pairedMachine?.isOnline == true

        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Approval required", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(approval.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

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
                        store.deny(approval, reason: "Denied from Handrail.")
                    } label: {
                        Text("Deny")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canDecide)
                    .hoverEffect(.highlight)

                    Button {
                        store.approve(approval)
                    } label: {
                        Text("Approve")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(!canDecide)
                    .hoverEffect(.highlight)
                }
            }
        }
    }

    private func composer(placeholder: String, action: @escaping (String) -> Void) -> some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($isComposerFocused)
            Button {
                let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
                action(text)
                input = ""
                isComposerFocused = false
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .hoverEffect(.highlight)
            .accessibilityLabel("Send")
        }
        .padding()
        .background(Color.black)
    }

    private func followUpComposer(_ chat: CodexChat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Ask for follow-up changes", text: $input, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .focused($isComposerFocused)
            Button {
                let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
                pendingContinuePrompt = prompt
                store.continueChat(chatId: chat.id, prompt: prompt)
                isComposerFocused = false
            } label: {
                Label(pendingContinuePrompt == nil ? "Send" : "Sending to Codex", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingContinuePrompt != nil)
            .hoverEffect(.highlight)
        }
        .padding()
        .background(Color.black)
    }

    private var dismissComposerShortcut: some View {
        Button("Dismiss Composer Focus") {
            isComposerFocused = false
        }
        .keyboardShortcut(.cancelAction)
        .hidden()
    }

    private func readOnlyNotice(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
    }

    private var selectedChat: CodexChat? {
        guard let selectedChatId = selection.selectedChatId else { return nil }
        return store.chat(id: selectedChatId)
    }

    private var navigationTitle: String {
        guard let chat = selectedChat else { return "Chat" }
        return IPadChatListQuery.displayTitle(for: chat)
    }

    private var commandAvailability: HandrailCommandAvailability {
        HandrailCommandAvailability.resolve(
            pairedMachine: store.pairedMachine,
            selectedChat: selectedChat,
            selectedApprovalId: store.latestApproval?.chatId == selectedChat?.id ? store.latestApproval?.approvalId : selection.selectedApprovalId,
            latestApproval: store.latestApproval
        )
    }

    private var transcriptText: String {
        guard let chatId = selection.selectedChatId else { return "" }
        return (store.transcripts[chatId] ?? []).joined()
    }

    private var chatError: String? {
        guard let chatId = selection.selectedChatId else { return nil }
        return store.chatErrors[chatId]
    }

    private var chatBlocks: [ChatBlock] {
        ChatBlock.parse(transcriptText)
    }

    private var thinkingEntries: [ThinkingEntry] {
        selectedChat?.thinking ?? []
    }

    private var thinkingSignature: String {
        thinkingEntries.map { "\($0.id):\($0.round):\($0.text.count)" }.joined(separator: "|")
    }

    private var bottomId: String {
        "ipad-bottom-\(selection.selectedChatId ?? "empty")"
    }

    private func canSendInput(_ chat: CodexChat) -> Bool {
        store.pairedMachine?.isOnline == true && chat.status == .running && chat.acceptsInput == true
    }

    private func canStartFollowUp(_ chat: CodexChat) -> Bool {
        store.pairedMachine?.isOnline == true &&
            chat.status != .running &&
            chat.status != .waitingForApproval
    }

    private func readOnlyText(for chat: CodexChat) -> String {
        if store.pairedMachine?.isOnline != true {
            return "Connect to your Mac to keep chatting."
        }
        if chat.status == .running {
            return "This running Codex chat cannot receive input right now."
        }
        if chat.status == .waitingForApproval {
            return "Review the approval request before Codex can continue."
        }
        return "This Codex chat cannot receive input right now."
    }

    private func emptyChatText(for chat: CodexChat) -> String {
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

    private func sortDate(for chat: CodexChat) -> Date {
        chat.updatedAt ?? chat.endedAt ?? chat.startedAt
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

    private func enterVisibleChatIfNeeded() {
        guard let chatId = selection.selectedChatId else { return }
        if enteredChatId != chatId {
            leaveEnteredChatIfNeeded()
            store.enterChat(chatId: chatId)
            enteredChatId = chatId
        }
        if store.pairedMachine?.isOnline == true {
            store.refreshChats()
        }
    }

    private func leaveEnteredChatIfNeeded() {
        guard let enteredChatId else { return }
        store.leaveChat(chatId: enteredChatId)
        self.enteredChatId = nil
    }

    @MainActor
    private func refreshVisibleChatUntilCancelled() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let chatId = selection.selectedChatId else { continue }
            if store.pairedMachine?.isOnline == true && store.isViewingChat(chatId: chatId) {
                store.refreshChats()
            }
        }
    }
}

#Preview {
    NavigationStack {
        IPadChatDetailWorkspaceView(selection: .constant(IPadWorkspaceSelection(selectedSection: .chats, selectedChatId: "preview-chat")))
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}

#Preview("Empty Chat Detail") {
    NavigationStack {
        IPadChatDetailWorkspaceView(selection: .constant(IPadWorkspaceSelection(selectedSection: .chats)))
    }
    .environment(PreviewData.emptyStore)
    .preferredColorScheme(.dark)
}
