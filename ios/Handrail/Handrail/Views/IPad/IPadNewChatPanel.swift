import SwiftUI

struct IPadNewChatPanel: View {
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
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    composerCard
                        .frame(maxWidth: .infinity)
                    optionsCard
                        .frame(width: 340)
                }
                VStack(spacing: 16) {
                    composerCard
                    optionsCard
                }
            }
            .padding(20)
            .safeAreaPadding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.clearNewChatError()
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
                    .keyboardShortcut(.cancelAction)
                    .hoverEffect(.highlight)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Start") {
                    isStarting = true
                    store.startChat(payload)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canStart || isStarting)
                .hoverEffect(.highlight)
            }
        }
    }

    private var composerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $prompt)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(minHeight: 260)
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

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                    optionChip("folder", selectedProject?.name ?? "No project")
                    optionChip("laptopcomputer", workModeTitle(workMode))
                    if selectedProject?.path != nil {
                        optionChip("point.3.connected.trianglepath.dotted", createsBranch ? trimmedNewBranch ?? "New branch" : branchLabel)
                    }
                    optionChip("shield", accessTitle(accessPreset))
                    optionChip("cpu", model)
                    optionChip("speedometer", reasoningTitle(reasoningEffort))
                }

                statusFooter
            }
        }
    }

    private var optionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                optionRow("Project", systemImage: "folder", selection: $projectId, values: projectIds) { id in
                    projects.first { $0.id == id }?.name ?? id
                }
                selectedProjectPath
                Divider()
                optionRow("Work mode", systemImage: "laptopcomputer", selection: $workMode, values: workModes, title: workModeTitle)
                Divider()
                branchOptions
                optionRow("Access", systemImage: "shield", selection: $accessPreset, values: accessPresets, title: accessTitle)
                Divider()
                optionRow("Model", systemImage: "cpu", selection: $model, values: models, title: { $0 })
                Divider()
                optionRow("Reasoning", systemImage: "speedometer", selection: $reasoningEffort, values: reasoningEfforts, title: reasoningTitle)
            }
        }
    }

    @ViewBuilder
    private var selectedProjectPath: some View {
        if let path = selectedProject?.path {
            Label(path, systemImage: "externaldrive")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var branchOptions: some View {
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
        .hoverEffect(.highlight)
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
            .hoverEffect(.highlight)
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

#Preview {
    NavigationStack {
        IPadNewChatPanel()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
