import SwiftUI

struct ChatTranscriptView: View {
    let blocks: [ChatBlock]
    let thinkingEntries: [ThinkingEntry]
    let isWorking: Bool
    let error: String?
    let emptyText: String
    @Binding var expandedThinkingRounds: Set<Int>

    var body: some View {
        VStack(spacing: 14) {
            if blocks.isEmpty {
                Text(emptyText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 48)
                if isWorking || !thinkingEntries.isEmpty {
                    thinkingDisclosure(round: latestRound, isWorking: isWorking)
                }
                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    if block.startsRound {
                        roundDivider(block.round)
                    }
                    if block.role == .codex && isFirstCodexBlock(index: index, round: block.round) {
                        thinkingDisclosure(round: block.round, isWorking: isWorking && block.round == latestRound)
                    }
                    ChatMessageBubble(block: block, isLatest: index == blocks.count - 1)
                }
                errorView
                if isWorking && !hasCodexBlock(round: latestRound) {
                    thinkingDisclosure(round: latestRound, isWorking: true)
                }
            }
        }
    }

    private var latestRound: Int {
        blocks.last?.round ?? thinkingEntries.last?.round ?? 1
    }

    private func thinkingEntries(round: Int) -> [ThinkingEntry] {
        thinkingEntries.filter { $0.round == round }
    }

    private func isFirstCodexBlock(index: Int, round: Int) -> Bool {
        !blocks.prefix(index).contains { $0.role == .codex && $0.round == round }
    }

    private func hasCodexBlock(round: Int) -> Bool {
        blocks.contains { $0.role == .codex && $0.round == round }
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

    private var errorView: some View {
        Group {
            if let error {
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
