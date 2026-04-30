import SwiftUI

struct IPadChatDetailWorkspaceView: View {
    @Binding var selection: IPadWorkspaceSelection

    var body: some View {
        ContentUnavailableView("iPad Chat Detail", systemImage: "text.bubble", description: Text("Chat detail workspace scaffold."))
            .navigationTitle("Chat")
    }
}

#Preview {
    NavigationStack {
        IPadChatDetailWorkspaceView(selection: .constant(IPadWorkspaceSelection(selectedSection: .chats, selectedChatId: "preview-chat")))
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
