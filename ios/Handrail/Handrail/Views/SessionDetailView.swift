import SwiftUI

struct SessionDetailView: View {
    @Environment(HandrailStore.self) private var store
    let sessionId: String
    @State private var input = ""
    @State private var showJumpToLatest = false
    @State private var pendingContinuePrompt: String?

    var body: some View {
        VStack(spacing: 0) {
            chatSurface
            if canControlSession {
                if canSendInput {
                    composer(placeholder: "Send input") { text in
                        store.sendInput(sessionId: sessionId, text: text)
                    }
                } else {
                    readOnlyNotice("This session is running without live text input.")
                }
            } else if canContinueArchivedChat {
                continueComposer
            } else if store.session(id: sessionId)?.source == "codex" {
                readOnlyNotice(store.pairedMachine?.isOnline == true ? "Archived Codex chat" : "Connect to your Mac to continue this chat.")
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(displayTitle(store.session(id: sessionId)?.title ?? "Session"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if canDismissAttention {
                    Button {
                        store.dismissAttention(sessionId: sessionId)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("Dismiss attention item")
                }
                if canControlSession {
                    Button(role: .destructive) {
                        store.stop(sessionId: sessionId)
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
                        if let session = store.session(id: sessionId) {
                            chatHeader(session)
                            attentionSummary(session)
                            files(session.files ?? [])
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
                .onAppear {
                    scrollToLatest(proxy, animated: false)
                }
                .onChange(of: transcriptText) { _, _ in
                    clearCompletedContinuePromptIfNeeded()
                    scrollToLatest(proxy, animated: true)
                }
                .onChange(of: store.lastError) { _, error in
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

    private var canControlSession: Bool {
        guard let session = store.session(id: sessionId) else { return false }
        return store.pairedMachine?.isOnline == true &&
            (session.status == .running || session.status == .waitingForApproval)
    }

    private var canSendInput: Bool {
        store.session(id: sessionId)?.acceptsInput == true
    }

    private var canContinueArchivedChat: Bool {
        guard let session = store.session(id: sessionId) else { return false }
        return session.source == "codex" &&
            store.pairedMachine?.isOnline == true &&
            session.status != .running &&
            session.status != .waitingForApproval
    }

    private var canDismissAttention: Bool {
        guard let session = store.session(id: sessionId) else { return false }
        return store.needsAttention(session) && !store.isAttentionDismissed(sessionId: sessionId)
    }

    private func chatHeader(_ session: HandrailSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                StatusBadge(status: session.status)
                if session.source == "codex" && session.status != .running && session.status != .waitingForApproval {
                    Text("Can continue")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(session.repo)
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

    private func attentionSummary(_ session: HandrailSession) -> some View {
        Group {
            if store.needsAttention(session) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(session.status == .failed ? "Needs attention" : "Approval required", systemImage: session.status == .failed ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(session.status == .failed ? .red : .orange)
                        Text(attentionDetail(for: session))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func attentionDetail(for session: HandrailSession) -> String {
        if session.status == .waitingForApproval {
            return "Codex is waiting for a decision before it can continue."
        }
        let text = transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return "This session failed before Handrail received readable output."
        }
        return ChatBlock.failureSummary(from: text)
    }

    private var chatMessages: some View {
        VStack(spacing: 14) {
            if chatBlocks.isEmpty {
                Text(emptyTranscriptText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 48)
                if let error = store.lastError {
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
                    ChatMessageBubble(block: block, isLatest: index == chatBlocks.count - 1)
                }
                sessionErrorView
            }
        }
    }

    private func composer(placeholder: String, action: @escaping (String) -> Void) -> some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
            Button {
                action(input)
                input = ""
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

    private var continueComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Continue this Codex chat", text: $input, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            Button {
                let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
                pendingContinuePrompt = prompt
                store.continueSession(sessionId: sessionId, prompt: prompt)
            } label: {
                Label(pendingContinuePrompt == nil ? "Continue Chat" : "Sending to Desktop", systemImage: "arrow.turn.down.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingContinuePrompt != nil)
            sessionErrorView
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

    private var emptyTranscriptText: String {
        guard let session = store.session(id: sessionId) else {
            return "Session not found."
        }
        switch session.status {
        case .running:
            return "Codex is starting. Output will appear here."
        case .waitingForApproval:
            return "Waiting for approval."
        case .completed:
            return "Completed with no transcript output."
        case .failed:
            return "Failed before transcript output was received."
        case .stopped:
            return "Stopped before transcript output was received."
        case .idle:
            return "No transcript is available for this chat."
        }
    }

    private var transcriptText: String {
        (store.transcripts[sessionId] ?? []).joined()
    }

    private var chatBlocks: [ChatBlock] {
        ChatBlock.parse(transcriptText)
    }

    private var bottomId: String {
        "bottom-\(sessionId)"
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

    private var sessionErrorView: some View {
        Group {
            if let error = store.lastError {
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
        return lines.last ?? "This session failed."
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
            Label("Raw browser response", systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Handrail kept this output readable instead of rendering the embedded HTML/SVG as chat.")
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
