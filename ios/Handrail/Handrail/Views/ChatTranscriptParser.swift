import SwiftUI

struct ChatBlock {
    let role: ChatRole
    let body: String
    let round: Int
    let startsRound: Bool

    var isRawMarkupNoise: Bool {
        ChatBlock.isRawMarkupNoise(body)
    }

    static func parse(_ text: String) -> [ChatBlock] {
        var result: [TranscriptBlock] = []
        var role: ChatRole = .grok
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
            return [ChatBlock(role: .grok, body: text, round: 1, startsRound: true)]
        }

        var rendered: [ChatBlock] = []
        var turnIndex = 0
        for block in result {
            if block.role == .user {
                turnIndex += 1
            } else if turnIndex == 0 {
                turnIndex = 1
            }
            rendered.append(ChatBlock(
                role: block.role,
                body: block.body,
                round: turnIndex,
                startsRound: block.role == .user || rendered.isEmpty
            ))
        }
        return rendered
    }

    private static func parseRole(_ line: String) -> (role: ChatRole, body: String)? {
        if let parsed = parseLabel(line, role: .user) {
            return parsed
        }
        if let parsed = parseLabel(line, role: .grok) {
            return parsed
        }
        return parseLabel(line, role: .grok, label: "Codex")
    }

    private static func parseLabel(_ line: String, role: ChatRole, label: String? = nil) -> (role: ChatRole, body: String)? {
        let prefix = "\(label ?? role.rawValue):"
        if line == prefix {
            return (role, "")
        }
        if line.hasPrefix("\(prefix) ") {
            return (role, String(line.dropFirst(prefix.count + 1)))
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
            return "Grok received a browser challenge page instead of readable content."
        }
        if isRawMarkupNoise(text) {
            return "Grok produced raw markup output. The full raw response is contained below."
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

enum ChatRole: String, CaseIterable {
    case user = "User"
    case grok = "Grok"

    var title: String {
        rawValue
    }

    var background: Color {
        switch self {
        case .user:
            Color.white.opacity(0.09)
        case .grok:
            Color.clear
        }
    }

    var stroke: Color {
        switch self {
        case .user:
            Color.white.opacity(0.14)
        case .grok:
            Color.clear
        }
    }
}