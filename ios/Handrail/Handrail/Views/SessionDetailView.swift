import SwiftUI

struct SessionDetailView: View {
    @Environment(HandrailStore.self) private var store
    let sessionId: String
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    if let session = store.session(id: sessionId) {
                        header(session)
                        files(session.files ?? [])
                    }
                    transcript
                }
                .padding()
            }
            if canControlSession {
                if canSendInput {
                    composer(placeholder: "Send input") { text in
                        store.sendInput(sessionId: sessionId, text: text)
                    }
                } else {
                    readOnlyNotice("This session is running without live text input.")
                }
            } else if canContinueArchivedChat {
                composer(placeholder: "Continue chat") { text in
                    store.continueSession(sessionId: sessionId, prompt: text)
                }
            } else if store.session(id: sessionId)?.source == "codex" {
                readOnlyNotice("Archived Codex chat")
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(displayTitle(store.session(id: sessionId)?.title ?? "Session"))
        .toolbar {
            if canControlSession {
                Button(role: .destructive) {
                    store.stop(sessionId: sessionId)
                } label: {
                    Image(systemName: "stop.fill")
                }
            }
        }
    }

    private var canControlSession: Bool {
        guard let session = store.session(id: sessionId), session.source != "codex" else {
            return false
        }
        return session.status == .running || session.status == .waitingForApproval
    }

    private var canSendInput: Bool {
        store.session(id: sessionId)?.acceptsInput == true
    }

    private var canContinueArchivedChat: Bool {
        guard let session = store.session(id: sessionId) else { return false }
        return session.source == "codex" && store.pairedMachine?.isOnline == true
    }

    private func header(_ session: HandrailSession) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle(session.title))
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(store.pairedMachine?.machineName ?? "Mac")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    StatusBadge(status: session.status)
                    if session.source == "codex" {
                        Text("Can continue")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text(session.repo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

    private var transcript: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Transcript", systemImage: "terminal")
                    .font(.headline)
                let lines = store.transcripts[sessionId] ?? []
                if lines.isEmpty {
                    Text(emptyTranscriptText)
                        .foregroundStyle(.secondary)
                    if let error = store.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                } else {
                    MarkdownTranscript(text: lines.joined())
                }
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

    private func displayTitle(_ title: String) -> String {
        if title.hasPrefix("Codex: ") {
            return String(title.dropFirst("Codex: ".count))
        }
        return title
    }
}

private struct MarkdownTranscript: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                VStack(alignment: .leading, spacing: 6) {
                    if let role = block.role {
                        Text(role)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(role == "User" ? .purple : .secondary)
                    }
                    MarkdownBody(text: block.body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blocks: [TranscriptBlock] {
        var result: [TranscriptBlock] = []
        var role: String?
        var lines: [String] = []

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
                if !parsed.body.isEmpty {
                    lines.append(parsed.body)
                }
            } else {
                lines.append(line)
            }
        }
        flush()

        if result.isEmpty {
            return [TranscriptBlock(role: nil, body: text)]
        }
        return result
    }

    private func parseRole(_ line: String) -> (role: String, body: String)? {
        for role in ["User", "Codex"] {
            let prefix = "\(role):"
            if line == prefix {
                return (role, "")
            }
            if line.hasPrefix("\(prefix) ") {
                return (role, String(line.dropFirst(prefix.count + 1)))
            }
        }
        return nil
    }

}

private struct TranscriptBlock {
    let role: String?
    let body: String
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
