import SwiftUI

struct ChatDetailView: View {
    @Environment(HandrailStore.self) private var store
    let chatId: String
    @State private var input = ""
    @State private var showJumpToLatest = false
    @State private var pendingContinuePrompt: String?
    @State private var expandedThinkingRounds: Set<Int> = []
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            chatSurface
            if canControlChat {
                if canSendInput {
                    composer(placeholder: "Send input") { text in
                        store.sendInput(chatId: chatId, text: text)
                    }
                }
            } else if canStartFollowUp {
                followUpComposer
            } else if store.chat(id: chatId) != nil {
                readOnlyNotice(store.pairedMachine?.isOnline == true ? "This Codex chat cannot receive input right now." : "Connect to your Mac to keep chatting.")
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(displayTitle(store.chat(id: chatId)?.title ?? "Chat"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.enterChat(chatId: chatId)
            if store.pairedMachine?.isOnline == true {
                store.refreshChats()
            }
        }
        .onDisappear {
            store.leaveChat(chatId: chatId)
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
                        store.stop(chatId: chatId)
                    } label: {
                        Image(systemName: "stop.fill")
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
            HStack(alignment: .center, spacing: 8) {
                StatusBadge(status: chat.status)
                if chat.status != .running && chat.status != .waitingForApproval {
                    Text("Ready for follow-up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
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
                        Label("Files to change", systemImage: "doc.text")
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

                    Button {
                        store.approve(approval)
                    } label: {
                        Text("Approve")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }
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

    private var chatMessages: some View {
        VStack(spacing: 14) {
            if chatBlocks.isEmpty {
                Text(emptyChatText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 48)
                if isChatWorking || !thinkingEntries.isEmpty {
                    thinkingDisclosure(round: latestRound, isWorking: isChatWorking)
                }
                if let error = chatError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(Array(chatBlocks.enumerated()), id: \.offset) { index, block in
                    if block.startsRound {
                        roundDivider(block.round)
                    }
                    if block.role == .codex && isFirstCodexBlock(index: index, round: block.round) {
                        thinkingDisclosure(round: block.round, isWorking: isChatWorking && block.round == latestRound)
                    }
                    ChatMessageBubble(block: block, isLatest: index == chatBlocks.count - 1)
                }
                chatErrorView
                if isChatWorking && !hasCodexBlock(round: latestRound) {
                    thinkingDisclosure(round: latestRound, isWorking: true)
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
                action(input)
                input = ""
                dismissComposerKeyboard()
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color.black)
    }

    private var followUpComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Ask for follow-up changes", text: $input, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .focused($isComposerFocused)
            Button {
                let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
                pendingContinuePrompt = prompt
                store.continueChat(chatId: chatId, prompt: prompt)
                dismissComposerKeyboard()
            } label: {
                Label(pendingContinuePrompt == nil ? "Send" : "Sending to Codex", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingContinuePrompt != nil)
        }
        .padding()
        .background(Color.black)
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

    private var latestRound: Int {
        chatBlocks.last?.round ?? thinkingEntries.last?.round ?? 1
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

    private func dismissComposerKeyboard() {
        isComposerFocused = false
    }

    private func thinkingEntries(round: Int) -> [ThinkingEntry] {
        thinkingEntries.filter { $0.round == round }
    }

    private func isFirstCodexBlock(index: Int, round: Int) -> Bool {
        !chatBlocks.prefix(index).contains { $0.role == .codex && $0.round == round }
    }

    private func hasCodexBlock(round: Int) -> Bool {
        chatBlocks.contains { $0.role == .codex && $0.round == round }
    }

    private func thinkingDisclosure(round: Int, isWorking: Bool) -> some View {
        ThinkingDisclosure(
            title: isWorking ? "Codex is working" : "Thinking",
            isWorking: isWorking,
            entries: thinkingEntries(round: round),
            isExpanded: Binding(
                get: { expandedThinkingRounds.contains(round) },
                set: { isExpanded in
                    if isExpanded {
                        expandedThinkingRounds.insert(round)
                    } else {
                        expandedThinkingRounds.remove(round)
                    }
                }
            )
        )
    }

    private var chatErrorView: some View {
        Group {
            if let error = chatError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func roundDivider(_ round: Int) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
            Text("Round \(round)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    private func displayTitle(_ title: String) -> String {
        if title.hasPrefix("Codex: ") {
            return String(title.dropFirst("Codex: ".count))
        }
        return title
    }
}

private struct ChatMessageBubble: View {
    let block: ChatBlock
    let isLatest: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            if block.role == .user {
                Spacer(minLength: 42)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(block.role.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(block.role == .user ? .white.opacity(0.82) : .secondary)
                    if isLatest {
                        Text("Latest")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                if block.isRawMarkupNoise {
                    RawOutputNotice(text: block.body)
                } else {
                    MarkdownBody(text: block.body)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(block.role.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(block.role.stroke, lineWidth: 1)
            )
            .frame(maxWidth: block.role == .user ? 330 : .infinity, alignment: block.role == .user ? .trailing : .leading)
            if block.role != .user {
                Spacer(minLength: 26)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ThinkingDisclosure: View {
    let title: String
    let isWorking: Bool
    let entries: [ThinkingEntry]
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if entries.isEmpty {
                    Text("No thinking messages yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(entries) { entry in
                        MarkdownBody(text: entry.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.green)
                }
                Image(systemName: "brain.head.profile")
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                if !entries.isEmpty {
                    Text("\(entries.count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.18), in: Capsule())
                }
            }
            .foregroundStyle(isWorking ? .green : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.green.opacity(isWorking ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .tint(.green)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChatBlock {
    let role: ChatRole
    let body: String
    let round: Int
    let startsRound: Bool

    var isRawMarkupNoise: Bool {
        ChatBlock.isRawMarkupNoise(body)
    }

    static func parse(_ text: String) -> [ChatBlock] {
        var result: [TranscriptBlock] = []
        var role: ChatRole = .codex
        var lines: [String] = []
        var round = 0

        func flush() {
            let body = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                result.append(TranscriptBlock(role: role, body: body))
            }
            lines.removeAll()
        }

        for line in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if let parsed = parseRole(line) {
                flush()
                role = parsed.role
                if role == .user {
                    round += 1
                } else if round == 0 {
                    round = 1
                }
                if !parsed.body.isEmpty {
                    lines.append(parsed.body)
                }
            } else {
                lines.append(line)
            }
        }
        flush()

        if result.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [ChatBlock(role: .codex, body: text, round: 1, startsRound: true)]
        }

        var rendered: [ChatBlock] = []
        var currentRound = 0
        for block in result {
            if block.role == .user {
                currentRound += 1
            } else if currentRound == 0 {
                currentRound = 1
            }
            rendered.append(ChatBlock(
                role: block.role,
                body: block.body,
                round: currentRound,
                startsRound: block.role == .user || rendered.isEmpty
            ))
        }
        return rendered
    }

    private static func parseRole(_ line: String) -> (role: ChatRole, body: String)? {
        for role in ChatRole.allCases {
            let prefix = "\(role.rawValue):"
            if line == prefix {
                return (role, "")
            }
            if line.hasPrefix("\(prefix) ") {
                return (role, String(line.dropFirst(prefix.count + 1)))
            }
        }
        return nil
    }

    static func failureSummary(from text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.contains(where: { $0.localizedCaseInsensitiveContains("Enable JavaScript and cookies to continue") }) {
            return "Codex received a browser challenge page instead of readable content."
        }
        if isRawMarkupNoise(text) {
            return "Codex produced raw markup output. The full raw response is contained below."
        }
        return lines.last ?? "This chat failed."
    }

    private static func isRawMarkupNoise(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("<!doctype")
            || lowercased.contains("<html")
            || lowercased.contains("<svg")
            || lowercased.contains("</svg>")
            || lowercased.contains("<div class=")
            || lowercased.contains("window._cf_chl_opt")
            || lowercased.contains("enable javascript and cookies to continue")
            || lowercased.contains("default profile:")
            || lowercased.contains(" process running for ")
            || lowercased.contains(" info ")
    }
}

private struct TranscriptBlock {
    let role: ChatRole
    let body: String
}

private enum ChatRole: String, CaseIterable {
    case user = "User"
    case codex = "Codex"

    var title: String {
        rawValue
    }

    var background: Color {
        switch self {
        case .user:
            Color.purple.opacity(0.52)
        case .codex:
            Color.white.opacity(0.075)
        }
    }

    var stroke: Color {
        switch self {
        case .user:
            Color.purple.opacity(0.35)
        case .codex:
            Color.white.opacity(0.08)
        }
    }
}

private struct RawOutputNotice: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Raw output", systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Handrail kept this output compact instead of rendering process logs or embedded markup as normal chat.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(preview)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(8)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var preview: String {
        let compact = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= 900 {
            return compact
        }
        return "\(String(compact.prefix(900)))\n..."
    }
}

private struct MarkdownBody: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.text.isEmpty {
                    Spacer()
                        .frame(height: 5)
                } else if line.isCode {
                    Text(line.text)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(markdown(for: line.text))
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var lines: [MarkdownLine] {
        var result: [MarkdownLine] = []
        var inCodeBlock = false
        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let trimmedFence = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmedFence.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }
            let visibleLine = rawLine.hasSuffix("  ") ? String(rawLine.dropLast(2)) : rawLine
            result.append(MarkdownLine(text: visibleLine, isCode: inCodeBlock))
        }
        return result
    }

    private func markdown(for text: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            return AttributedString(text)
        }
    }
}

private struct MarkdownLine {
    let text: String
    let isCode: Bool
}
