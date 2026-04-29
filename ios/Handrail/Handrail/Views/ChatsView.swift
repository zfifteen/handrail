import SwiftUI
import UIKit

struct ChatsView: View {
    @Environment(HandrailStore.self) private var store
    @State private var showsScanner = false
    @State private var showsStart = false
    @State private var listMode: ChatListMode = .chronological
    @State private var sortMode: ChatSortMode = .updated
    let navigateToChat: (String) -> Void

    init(navigateToChat: @escaping (String) -> Void = { _ in }) {
        self.navigateToChat = navigateToChat
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let machine = store.pairedMachine {
                    machineCard(machine)
                    SyncStatusRow(
                        isRefreshing: store.isRefreshingChats,
                        lastRefreshAt: store.lastChatRefreshAt,
                        isOnline: machine.isOnline,
                        refresh: store.refreshChats
                    )
                    Button {
                        showsStart = true
                    } label: {
                        Label("New chat", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)

                    if !activeChats.isEmpty {
                        chatSection(title: "Active chats", chats: activeChats, emptyTitle: "")
                    }
                    chatSection(title: "Pinned", chats: pinnedChats, emptyTitle: "No pinned chats")
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
            store.refreshChats()
        }
        .navigationTitle("Handrail")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button {
                showsScanner = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
            }
        }
        .navigationDestination(for: String.self) { id in
            ChatDetailView(chatId: id)
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
        .onChange(of: store.lastStartedChatId) { _, chatId in
            if chatId != nil {
                showsStart = false
            }
        }
    }

    private var pinnedChats: [CodexChat] {
        visibleChats
            .filter { store.isPinned(chatId: $0.id) }
            .sorted { pinnedSortKey(for: $0) < pinnedSortKey(for: $1) }
    }

    private var allChats: [CodexChat] {
        visibleChats
            .filter { !store.isPinned(chatId: $0.id) }
            .sorted { sortDate(for: $0) > sortDate(for: $1) }
    }

    private var visibleChats: [CodexChat] {
        store.chats 
    }

    private var activeChats: [CodexChat] {
        visibleChats
            .filter { $0.status == .running || $0.status == .waitingForApproval }
            .sorted { sortDate(for: $0) > sortDate(for: $1) }
    }

    private var allChatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("All chats")
                Spacer()
                Menu {
                    Section("Display") {
                        Picker("Display", selection: $listMode) {
                            ForEach(ChatListMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.systemImage).tag(mode)
                            }
                        }
                    }
                    Section("Sort by") {
                        Picker("Sort by", selection: $sortMode) {
                            ForEach(ChatSortMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.systemImage).tag(mode)
                            }
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
                ForEach(allChats) { chat in
                    chatRow(chat)
                }
            } else {
                ForEach(projectGroups, id: \.project) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(group.project, systemImage: "folder")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 2)
                        ForEach(group.chats) { chat in
                            chatRow(chat)
                        }
                    }
                }
            }
        }
    }

    private var projectGroups: [(project: String, chats: [CodexChat])] {
        let groups = Dictionary(grouping: allChats, by: projectName)
        return groups.map { project, chats in
            (project, chats.sorted { sortDate(for: $0) > sortDate(for: $1) })
        }.sorted { left, right in
            sortDate(for: left.chats[0]) > sortDate(for: right.chats[0])
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

    private func chatSection(title: String, chats: [CodexChat], emptyTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)

            if chats.isEmpty {
                Text(emptyTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(chats) { chat in
                    chatRow(chat)
                }
            }
        }
    }

    private func chatRow(_ chat: CodexChat) -> some View {
        NavigationLink(value: chat.id) {
            chatRowContent(chat)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Label(store.isPinned(chatId: chat.id) ? "Pinned in Codex Desktop" : "Pin in Codex Desktop", systemImage: "pin")
        }
    }

    private func chatRowContent(_ chat: CodexChat) -> some View {
        HStack(spacing: 10) {
            if store.isPinned(chatId: chat.id) {
                Image(systemName: "pin")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            Text(displayTitle(for: chat))
                .font(.body.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if chat.status != .idle {
                Image(systemName: statusIcon(for: chat.status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(for: chat.status))
            }

            Text(HandrailFormatters.relativeAge(since: sortDate(for: chat)))
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func displayTitle(for chat: CodexChat) -> String {
        if chat.title.hasPrefix("Codex: ") {
            return String(chat.title.dropFirst("Codex: ".count))
        }
        return chat.title
    }

    private func projectName(for chat: CodexChat) -> String {
        chat.projectName ?? URL(fileURLWithPath: chat.repo).lastPathComponent
    }

    private func sortDate(for chat: CodexChat) -> Date {
        switch sortMode {
        case .updated:
            chat.updatedAt ?? chat.endedAt ?? chat.startedAt
        case .created:
            chat.startedAt
        }
    }

    private func pinnedSortKey(for chat: CodexChat) -> Int {
        chat.pinnedOrder ?? Int.max
    }

    private func statusIcon(for status: ChatStatus) -> String {
        switch status {
        case .running: "play.fill"
        case .waitingForApproval: "exclamationmark.triangle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .stopped: "stop.fill"
        case .idle: "pause.circle"
        }
    }

    private func statusColor(for status: ChatStatus) -> Color {
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

private enum ChatListMode: String, CaseIterable, Identifiable {
    case chronological
    case project

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chronological: "Chronological list"
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

private enum ChatSortMode: String, CaseIterable, Identifiable {
    case updated
    case created

    var id: String { rawValue }

    var title: String {
        switch self {
        case .updated: "Updated"
        case .created: "Created"
        }
    }

    var systemImage: String {
        switch self {
        case .updated: "square.and.pencil"
        case .created: "plus.magnifyingglass"
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
    @FocusState private var promptFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    composerCard
                    optionsDrawer
                    statusFooter
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("New chat")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                store.newChatError = nil
                applyDefaults()
            }
            .onChange(of: store.newChatOptions) { _, _ in
                applyDefaults()
            }
            .onChange(of: projectId) { _, _ in
                branch = canSelectBranch ? options?.defaultBranch ?? branchNames.first ?? "" : ""
            }
            .onChange(of: store.newChatError) { _, error in
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $prompt)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(minHeight: 190)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.sentences)
                    .focused($promptFocused)
                    .padding(.horizontal, -4)
                    .padding(.vertical, -8)
                if trimmedPrompt.isEmpty {
                    Text("Ask Codex anything...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.16))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                optionChip("folder", selectedProject?.name ?? "No project")
                optionChip("laptopcomputer", workModeTitle(workMode))
                if selectedProject?.path != nil {
                    optionChip("point.3.connected.trianglepath.dotted", createsBranch ? trimmedNewBranch ?? "New branch" : branchLabel)
                }
                optionChip("shield", accessTitle(accessPreset))
                optionChip("cpu", model)
                optionChip("speedometer", reasoningTitle(reasoningEffort))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var optionsDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Options")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 4)

            optionRow("Project", systemImage: "folder", selection: $projectId, values: projectIds) { id in
                projects.first { $0.id == id }?.name ?? id
            }
            Divider()
            optionRow("Work mode", systemImage: "laptopcomputer", selection: $workMode, values: workModes, title: workModeTitle)
            Divider()
            if selectedProject?.path != nil {
                Toggle(isOn: $createsBranch) {
                    Label("Create branch", systemImage: "plus")
                }
                .padding(.vertical, 12)
                if createsBranch {
                    TextField("New branch name", text: $newBranch)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                } else if canSelectBranch {
                    optionRow("Branch", systemImage: "point.3.connected.trianglepath.dotted", selection: $branch, values: branchNames, title: { $0 })
                    Divider()
                }
            }
            optionRow("Access", systemImage: "shield", selection: $accessPreset, values: accessPresets, title: accessTitle)
            Divider()
            optionRow("Model", systemImage: "cpu", selection: $model, values: models, title: { $0 })
            Divider()
            optionRow("Reasoning", systemImage: "speedometer", selection: $reasoningEffort, values: reasoningEfforts, title: reasoningTitle)
        }
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .simultaneousGesture(TapGesture().onEnded(dismissPromptKeyboard))
    }

    private func optionRow(_ title: String, systemImage: String, selection: Binding<String>, values: [String], title titleForValue: @escaping (String) -> String) -> some View {
        Menu {
            ForEach(values, id: \.self) { value in
                Button {
                    selection.wrappedValue = value
                } label: {
                    if value == selection.wrappedValue {
                        Label(titleForValue(value), systemImage: "checkmark")
                    } else {
                        Text(titleForValue(value))
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(titleForValue(selection.wrappedValue))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded(dismissPromptKeyboard))
    }

    private func optionChip(_ systemImage: String, _ title: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.10), in: Capsule())
            .foregroundStyle(.secondary)
            .simultaneousGesture(TapGesture().onEnded(dismissPromptKeyboard))
    }

    private func dismissPromptKeyboard() {
        promptFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            if let error = store.newChatError {
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

    private var branchLabel: String {
        branch.isEmpty ? "Current branch" : branch
    }

    private var canSelectBranch: Bool {
        selectedProject?.path != nil && projectId == options?.defaultProjectId
    }

    private var workModes: [String] {
        let values = options?.workModes ?? ["local", "worktree"]
        return values.isEmpty ? ["local"] : values
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
            branch: canSelectBranch ? branch : "",
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
        if !workModes.contains(workMode) {
            workMode = workModes[0]
        }
        if canSelectBranch && branch.isEmpty {
            branch = options.defaultBranch.isEmpty ? branchNames.first ?? "" : options.defaultBranch
        } else if !canSelectBranch {
            branch = ""
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
