import SwiftUI

struct IPadChatListWorkspaceView: View {
    @Binding var selection: IPadWorkspaceSelection

    var body: some View {
        ContentUnavailableView("iPad Chats", systemImage: "rectangle.stack", description: Text("Chat list workspace scaffold."))
            .navigationTitle("Chats")
    }
}

#Preview {
    NavigationStack {
        IPadChatListWorkspaceView(selection: .constant(IPadWorkspaceSelection(selectedSection: .chats)))
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
