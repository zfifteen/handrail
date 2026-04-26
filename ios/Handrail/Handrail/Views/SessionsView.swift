import SwiftUI

struct SessionsView: View {
    @Environment(HandrailStore.self) private var store
    @State private var showsScanner = false
    @State private var showsStart = false
    @State private var listMode: SessionListMode = .chronological
    let navigateToSession: (String) -> Void

    init(navigateToSession: @escaping (String) -> Void = { _ in }) {
        self.navigateToSession = navigateToSession
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let machine = store.pairedMachine {
                    machineCard(machine)
                    Button {
                        showsStart = true
                    } label: {
                        Label("Start New Session", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)

                    if !activeSessions.isEmpty {
                        sessionSection(title: "Active sessions", sessions: activeSessions, emptyTitle: "")
                    }
                    sessionSection(title: "Pinned", sessions: pinnedSessions, emptyTitle: "No pinned chats")
                    allChatsSection
                } else {
                    Card {
                        EmptyState(
                            title: "No machine paired",
                            detail: "Run handrail pair on your Mac, then scan the QR code here.",
                            systemImage: "qrcode.viewfinder"
                        )
                        Button {
                            showsScanner = true
                        } label: {
                            Label("Scan Pairing QR", systemImage: "camera.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .safeAreaPadding(.bottom, 96)
        }
        .background(Color.black.ignoresSafeArea())
        .refreshable {
            store.refreshSessions()
        }
        .navigationTitle("Handrail")
        .toolbar {
            Button {
                showsScanner = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
            }
        }
        .navigationDestination(for: String.self) { id in
            SessionDetailView(sessionId: id)
        }
        .sheet(isPresented: $showsScanner) {
            QRScannerView { payload in
                store.pair(with: payload)
                showsScanner = false
            }
        }
        .sheet(isPresented: $showsStart) {
            StartSessionView()
        }
        .onChange(of: store.lastStartedSessionId) { _, sessionId in
            guard let sessionId else { return }
            showsStart = false
            navigateToSession(sessionId)
            store.consumeLastStartedSessionId()
        }
    }

    private var pinnedSessions: [HandrailSession] {
        chatSessions.filter { store.isPinned(sessionId: $0.id) }
    }

    private var allChats: [HandrailSession] {
        chatSessions.filter { !store.isPinned(sessionId: $0.id) }
    }

    private var chatSessions: [HandrailSession] {
        store.sessions.filter { $0.source != "handrail" }
    }

    private var activeSessions: [HandrailSession] {
        store.sessions.filter {
            $0.source == "handrail" &&
            ($0.status == .running || $0.status == .waitingForApproval)
        }
    }

    private var allChatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("All chats")
                Spacer()
                Menu {
                    Picker("Display", selection: $listMode) {
                        ForEach(SessionListMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                } label: {
                    Label(listMode.title, systemImage: "line.3.horizontal.decrease")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 32)
                }
                .accessibilityLabel("Filter chats")
            }

            if allChats.isEmpty {
                Text("No chats yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else if listMode == .chronological {
                ForEach(allChats) { session in
                    sessionRow(session)
                }
            } else {
                ForEach(projectGroups, id: \.project) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(group.project, systemImage: "folder")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 2)
                        ForEach(group.sessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
    }

    private var projectGroups: [(project: String, sessions: [HandrailSession])] {
        let groups = Dictionary(grouping: allChats, by: projectName)
        return groups.map { project, sessions in
            (project, sessions.sorted { sortDate(for: $0) > sortDate(for: $1) })
        }.sorted { left, right in
            sortDate(for: left.sessions[0]) > sortDate(for: right.sessions[0])
        }
    }

    private func machineCard(_ machine: PairedMachine) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(machine.machineName)
                        .font(.headline)
                    Text("\(machine.host):\(machine.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(store.connectionText, systemImage: machine.isOnline ? "wifi" : "wifi.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(machine.isOnline ? .green : .secondary)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
    }

    private func sessionSection(title: String, sessions: [HandrailSession], emptyTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)

            if sessions.isEmpty {
                Text(emptyTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(sessions) { session in
                    sessionRow(session)
                }
            }
        }
    }

    private func sessionRow(_ session: HandrailSession) -> some View {
        NavigationLink(value: session.id) {
            sessionRowContent(session)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.togglePin(sessionId: session.id)
            } label: {
                Label(store.isPinned(sessionId: session.id) ? "Unpin" : "Pin", systemImage: store.isPinned(sessionId: session.id) ? "pin.slash" : "pin")
            }
        }
    }

    private func sessionRowContent(_ session: HandrailSession) -> some View {
        HStack(spacing: 10) {
            if store.isPinned(sessionId: session.id) {
                Image(systemName: "pin")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            Text(displayTitle(for: session))
                .font(.body.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if session.status != .idle {
                Image(systemName: statusIcon(for: session.status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(for: session.status))
            }

            Text(HandrailFormatters.relativeAge(since: sortDate(for: session)))
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func displayTitle(for session: HandrailSession) -> String {
        if session.title.hasPrefix("Codex: ") {
            return String(session.title.dropFirst("Codex: ".count))
        }
        return session.title
    }

    private func projectName(for session: HandrailSession) -> String {
        URL(fileURLWithPath: session.repo).lastPathComponent
    }

    private func sortDate(for session: HandrailSession) -> Date {
        session.updatedAt ?? session.endedAt ?? session.startedAt
    }

    private func statusIcon(for status: SessionStatus) -> String {
        switch status {
        case .running: "play.fill"
        case .waitingForApproval: "exclamationmark.triangle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .stopped: "stop.fill"
        case .idle: "pause.circle"
        }
    }

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .running: .green
        case .waitingForApproval: .purple
        case .completed: .blue
        case .failed: .red
        case .stopped: .orange
        case .idle: .secondary
        }
    }
}

private enum SessionListMode: String, CaseIterable, Identifiable {
    case chronological
    case project

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chronological: "Recent"
        case .project: "Project"
        }
    }

    var systemImage: String {
        switch self {
        case .chronological: "clock"
        case .project: "folder"
        }
    }
}

struct StartSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HandrailStore.self) private var store
    @State private var repo = ""
    @State private var title = "Handrail Session"
    @State private var prompt = ""
    @State private var isStarting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Title", text: $title)
                    TextField("Repository path", text: $repo)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Prompt", text: $prompt, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
                Section {
                    Label(store.pairedMachine?.isOnline == true ? "Mac online" : "Mac offline", systemImage: store.pairedMachine?.isOnline == true ? "wifi" : "wifi.slash")
                        .foregroundStyle(store.pairedMachine?.isOnline == true ? .green : .red)
                    if isStarting {
                        Label("Starting session...", systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    }
                    if let error = store.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Start Session")
            .onAppear {
                if repo.isEmpty {
                    repo = store.defaultRepo
                }
            }
            .onChange(of: store.lastError) { _, error in
                if error != nil {
                    isStarting = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        isStarting = true
                        store.startSession(repo: trimmedRepo, title: trimmedTitle, prompt: trimmedPrompt)
                    }
                    .disabled(!canStart || isStarting)
                }
            }
        }
    }

    private var trimmedRepo: String {
        repo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canStart: Bool {
        store.pairedMachine?.isOnline == true &&
        !trimmedRepo.isEmpty &&
        !trimmedTitle.isEmpty &&
        !trimmedPrompt.isEmpty
    }
}
