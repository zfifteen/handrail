import SwiftUI

struct IPadNewChatPanel: View {
    var body: some View {
        ContentUnavailableView("New Chat", systemImage: "square.and.pencil", description: Text("iPad New Chat panel scaffold."))
            .navigationTitle("New Chat")
    }
}

#Preview {
    NavigationStack {
        IPadNewChatPanel()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
