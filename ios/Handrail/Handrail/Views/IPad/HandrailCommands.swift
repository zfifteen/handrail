import SwiftUI

struct HandrailCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            EmptyView()
        }
    }
}
