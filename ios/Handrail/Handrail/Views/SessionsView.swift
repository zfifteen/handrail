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
                    SyncStatusRow(
                        isRefreshing: store.isRefreshingSessions,
                        lastRefreshAt: store.lastSessionRefreshAt,
                        isOnline: machine.isOnline,
                        reconnect: store.reconnect
                    )
                    Button {
                        showsStart = true
                    } label: {
                        Label("New chat", systemImage: "square.and.pencil")
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
            NewChatView()
        }
        .onChange(of: store.lastStartedSessionId) { _, sessionId in
            if sessionId != nil {
                showsStart = false
            }
        }
    }

    private var pinnedSessions: [HandrailSession] {
        chatSessions
            .filter { store.isPinned(sessionId: $0.id) }
            .sorted { pinnedSortKey(for: $0) < pinnedSortKey(for: $1) }
    }

    private var allChats: [HandrailSession] {
        chatSessions.filter { !store.isPinned(sessionId: $0.id) }
    }

    private var chatSessions: [HandrailSession] {
        store.sessions.filter { $0.source != "handrail" }
    }

    private var activeSessions: [HandrailSession] {
        chatSessions.filter { $0.status == .running || $0.status == .waitingForApproval }
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
            if session.source == "codex" {
                Label(store.isPinned(sessionId: session.id) ? "Pinned in Codex Desktop" : "Pin in Codex Desktop", systemImage: "pin")
            } else {
                Button {
                    store.togglePin(sessionId: session.id)
                } label: {
                    Label(store.isPinned(sessionId: session.id) ? "Unpin" : "Pin", systemImage: store.isPinned(sessionId: session.id) ? "pin.slash" : "pin")
                }
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

    private func pinnedSortKey(for session: HandrailSession) -> Int {
        session.pinnedOrder ?? Int.max
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

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HandrailStore.self) private var store
    @State private var prompt = ""
    @State private var projectId = "no-project"
    @State private var workMode = "local"
    @State private var branch = ""
    @State private var newBranch = ""
    @State private var createsBranch = false
    @State private var accessPreset = "on_request"
    @State private var model = "gpt-5.5"
    @State private var reasoningEffort = "high"
    @State private var isStarting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                promptEditor
                optionsCard
                statusFooter
            }
            .padding(16)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("New chat")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: applyDefaults)
            .onChange(of: store.newChatOptions) { _, _ in
                applyDefaults()
            }
            .onChange(of: projectId) { _, _ in
                branch = selectedProject?.path == nil ? "" : options?.defaultBranch ?? ""
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
                        store.startChat(payload)
                    }
                    .disabled(!canStart || isStarting)
                }
            }
        }
    }

    private var promptEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))
            TextField("", text: $prompt, axis: .vertical)
                .font(.title3)
                .lineLimit(8, reservesSpace: true)
                .textInputAutocapitalization(.sentences)
                .padding(16)
            if trimmedPrompt.isEmpty {
                Text("Ask Codex anything...")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
        }
    }

    private var optionsCard: some View {
        VStack(spacing: 0) {
            optionPicker("Project", systemImage: "folder", selection: $projectId, values: projectIds) { id in
                projects.first { $0.id == id }?.name ?? id
            }
            Divider()
            optionPicker("Work", systemImage: "laptopcomputer", selection: $workMode, values: ["local", "worktree"], title: workModeTitle)
            Divider()
            if selectedProject?.path != nil {
                Toggle(isOn: $createsBranch) {
                    Label("Create branch", systemImage: "plus")
                }
                .padding(.vertical, 12)
                if createsBranch {
                    TextField("New branch name", text: $newBranch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.bottom, 12)
                } else {
                    optionPicker("Branch", systemImage: "point.3.connected.trianglepath.dotted", selection: $branch, values: branchNames, title: { $0 })
                    Divider()
                }
            }
            optionPicker("Access", systemImage: "shield", selection: $accessPreset, values: accessPresets, title: accessTitle)
            Divider()
            optionPicker("Model", systemImage: "cpu", selection: $model, values: models, title: { $0 })
            Divider()
            optionPicker("Reasoning", systemImage: "speedometer", selection: $reasoningEffort, values: reasoningEfforts, title: reasoningTitle)
        }
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func optionPicker(_ title: String, systemImage: String, selection: Binding<String>, values: [String], title titleForValue: @escaping (String) -> String) -> some View {
        Picker(selection: selection) {
            ForEach(values, id: \.self) { value in
                Text(titleForValue(value)).tag(value)
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(store.pairedMachine?.isOnline == true ? "Mac online" : "Mac offline", systemImage: store.pairedMachine?.isOnline == true ? "wifi" : "wifi.slash")
                .foregroundStyle(store.pairedMachine?.isOnline == true ? .green : .red)
            if isStarting {
                Label("Starting chat...", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            } else if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = store.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var options: NewChatOptions? {
        store.newChatOptions
    }

    private var projects: [NewChatProject] {
        options?.projects ?? [NewChatProject(id: "no-project", name: "No project", path: nil)]
    }

    private var selectedProject: NewChatProject? {
        projects.first { $0.id == projectId }
    }

    private var projectIds: [String] {
        projects.map(\.id)
    }

    private var branchNames: [String] {
        let names = options?.branches.map(\.name).filter { !$0.isEmpty } ?? []
        if names.isEmpty {
            return branch.isEmpty ? ["main"] : [branch]
        }
        return names
    }

    private var accessPresets: [String] {
        options?.accessPresets ?? ["full_access", "on_request", "read_only"]
    }

    private var models: [String] {
        options?.models ?? ["gpt-5.5"]
    }

    private var reasoningEfforts: [String] {
        options?.reasoningEfforts ?? ["low", "medium", "high", "xhigh"]
    }

    private var payload: StartChatPayload {
        StartChatPayload(
            prompt: trimmedPrompt,
            projectId: projectId,
            projectPath: selectedProject?.path,
            workMode: workMode,
            branch: selectedProject?.path == nil ? "" : branch,
            newBranch: createsBranch ? trimmedNewBranch : nil,
            accessPreset: accessPreset,
            model: model,
            reasoningEffort: reasoningEffort
        )
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewBranch: String? {
        let value = newBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var canStart: Bool {
        store.pairedMachine?.isOnline == true &&
        !trimmedPrompt.isEmpty &&
        (!createsBranch || trimmedNewBranch != nil)
    }

    private var validationMessage: String? {
        if store.pairedMachine?.isOnline != true {
            return "Connect to your Mac before starting a chat."
        }
        if trimmedPrompt.isEmpty {
            return "Add a prompt."
        }
        if createsBranch && trimmedNewBranch == nil {
            return "Enter a branch name."
        }
        return nil
    }

    private func applyDefaults() {
        guard let options else { return }
        if !projectIds.contains(projectId) {
            projectId = options.defaultProjectId
        }
        if branch.isEmpty {
            branch = options.defaultBranch.isEmpty ? branchNames.first ?? "" : options.defaultBranch
        }
        if !accessPresets.contains(accessPreset) {
            accessPreset = options.defaultAccessPreset
        }
        if !models.contains(model) {
            model = options.defaultModel
        }
        if !reasoningEfforts.contains(reasoningEffort) {
            reasoningEffort = options.defaultReasoningEffort
        }
    }

    private func workModeTitle(_ value: String) -> String {
        switch value {
        case "worktree": "New worktree"
        default: "Work locally"
        }
    }

    private func accessTitle(_ value: String) -> String {
        switch value {
        case "full_access": "Full access"
        case "read_only": "Read only"
        default: "Ask when needed"
        }
    }

    private func reasoningTitle(_ value: String) -> String {
        switch value {
        case "low": "Low"
        case "medium": "Medium"
        case "xhigh": "Extra High"
        default: "High"
        }
    }
}
