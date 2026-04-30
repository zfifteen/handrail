import SwiftUI

struct IPadChatListWorkspaceView: View {
    @Environment(HandrailStore.self) private var store
    @Binding var selection: IPadWorkspaceSelection
    @Binding var focusesSearch: Bool
    @State private var searchText = ""
    @State private var filter: ChatListFilter = .all
    @State private var sort: ChatListSort = .updated
    @State private var groupsByProject = false
    @FocusState private var searchFocused: Bool

    init(
        selection: Binding<IPadWorkspaceSelection>,
        focusesSearch: Binding<Bool> = .constant(false)
    ) {
        self._selection = selection
        self._focusesSearch = focusesSearch
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if groupsByProject {
                groupedList
            } else {
                flatList
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Chats")
        .background(dismissSearchShortcut)
        .onChange(of: focusesSearch) { _, shouldFocus in
            guard shouldFocus else { return }
            searchFocused = true
            focusesSearch = false
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    searchFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)
                .hoverEffect(.highlight)
                .accessibilityLabel("Search chats")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.refreshChats()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.pairedMachine == nil)
                .hoverEffect(.highlight)
                .accessibilityLabel("Refresh chats")
            }
        }
    }

    private var dismissSearchShortcut: some View {
        Button("Dismiss Search") {
            searchFocused = false
        }
        .keyboardShortcut(.cancelAction)
        .hidden()
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                searchField
                    .frame(maxWidth: 280)
                filterMenu
                sortPicker
                    .frame(maxWidth: 260)
                Spacer()
                groupToggle(showTitle: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                searchField
                HStack(spacing: 8) {
                    filterMenu
                    sortMenu
                    groupToggle(showTitle: false)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search chats", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .submitLabel(.search)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(searchFocused ? Color.purple.opacity(0.7) : Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var filterMenu: some View {
        Menu {
            Picker("Status", selection: $filter) {
                ForEach(ChatListFilter.allCases) { filter in
                    Label(filterTitle(filter), systemImage: filterIcon(filter)).tag(filter)
                }
            }
        } label: {
            Label(filterTitle(filter), systemImage: "line.3.horizontal.decrease.circle")
        }
        .buttonStyle(.bordered)
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $sort) {
            ForEach(ChatListSort.allCases) { sort in
                Text(sortTitle(sort)).tag(sort)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(ChatListSort.allCases) { sort in
                    Text(sortTitle(sort)).tag(sort)
                }
            }
        } label: {
            Label(sortTitle(sort), systemImage: "arrow.up.arrow.down")
        }
        .buttonStyle(.bordered)
    }

    private func groupToggle(showTitle: Bool) -> some View {
        Toggle(isOn: $groupsByProject) {
            if showTitle {
                Label("Group by project", systemImage: "folder")
            } else {
                Image(systemName: "folder")
            }
        }
        .toggleStyle(.button)
        .accessibilityLabel("Group by project")
    }

    private var flatList: some View {
        List(rows) { row in
            chatRow(row)
                .listRowBackground(row.id == selection.selectedChatId ? Color.accentColor.opacity(0.16) : Color.clear)
        }
        .listStyle(.plain)
        .overlay {
            if rows.isEmpty {
                ContentUnavailableView("No Chats", systemImage: "rectangle.stack", description: Text("No chats match the current search and filter."))
            }
        }
    }

    private var groupedList: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.rows) { row in
                        chatRow(row)
                            .listRowBackground(row.id == selection.selectedChatId ? Color.accentColor.opacity(0.16) : Color.clear)
                    }
                } header: {
                    Label(group.project, systemImage: "folder")
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView("No Chats", systemImage: "rectangle.stack", description: Text("No chats match the current search and filter."))
            }
        }
    }

    private func chatRow(_ row: IPadChatListRow) -> some View {
        Button {
            selection.selectChat(id: row.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: rowIcon(row))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(row.isPinned ? .secondary : statusColor(row.chat.status))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.displayTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(row.projectName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusBadge(status: row.chat.status)

                Text(HandrailFormatters.relativeAge(since: row.sortDate))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .contextMenu {
            Label(row.isPinned ? "Pinned in Codex Desktop" : "Pin in Codex Desktop", systemImage: "pin")
        }
    }

    private var rows: [IPadChatListRow] {
        IPadChatListQuery.rows(from: store.chats, searchText: searchText, filter: filter, sort: sort)
    }

    private var groups: [IPadChatListProjectGroup] {
        IPadChatListQuery.groupedRows(from: store.chats, searchText: searchText, filter: filter, sort: sort)
    }

    private func rowIcon(_ row: IPadChatListRow) -> String {
        row.isPinned ? "pin.fill" : statusIcon(row.chat.status)
    }

    private func filterTitle(_ filter: ChatListFilter) -> String {
        switch filter {
        case .all: "All"
        case .running: "Running"
        case .waitingForApproval: "Waiting"
        case .failed: "Failed"
        case .completed: "Completed"
        case .stopped: "Stopped"
        case .idle: "Idle"
        }
    }

    private func filterIcon(_ filter: ChatListFilter) -> String {
        switch filter {
        case .all: "rectangle.stack"
        case .running: "play.fill"
        case .waitingForApproval: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .completed: "checkmark.circle.fill"
        case .stopped: "stop.fill"
        case .idle: "pause.circle"
        }
    }

    private func sortTitle(_ sort: ChatListSort) -> String {
        switch sort {
        case .updated: "Updated"
        case .created: "Created"
        }
    }

    private func statusIcon(_ status: ChatStatus) -> String {
        switch status {
        case .running: "play.fill"
        case .waitingForApproval: "exclamationmark.triangle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .stopped: "stop.fill"
        case .idle: "pause.circle"
        }
    }

    private func statusColor(_ status: ChatStatus) -> Color {
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

#Preview {
    NavigationStack {
        IPadChatListWorkspaceView(selection: .constant(IPadWorkspaceSelection(selectedSection: .chats)))
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}

#Preview("Empty Chat List") {
    NavigationStack {
        IPadChatListWorkspaceView(selection: .constant(IPadWorkspaceSelection(selectedSection: .chats)))
    }
    .environment(PreviewData.emptyStore)
    .preferredColorScheme(.dark)
}
