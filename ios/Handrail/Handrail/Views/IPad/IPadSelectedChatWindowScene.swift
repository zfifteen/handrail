import SwiftUI

struct IPadSelectedChatWindowScene: View {
    @Environment(HandrailStore.self) private var store
    @State private var selection: IPadWorkspaceSelection

    init(window: IPadSelectedChatWindow) {
        self._selection = State(initialValue: window.selection)
    }

    var body: some View {
        NavigationStack {
            IPadChatDetailWorkspaceView(selection: $selection)
        }
        .preferredColorScheme(.dark)
        .navigationTitle(IPadSelectedChatWindow.title(for: selectedChat))
    }

    private var selectedChat: CodexChat? {
        guard let selectedChatId = selection.selectedChatId else { return nil }
        return store.chat(id: selectedChatId)
    }
}

#Preview {
    IPadSelectedChatWindowScene(window: IPadSelectedChatWindow(chatId: "chat-running"))
        .environment(PreviewData.store)
}
