import SwiftUI

struct IPadSidebarView: View {
    @Binding var selection: IPadWorkspaceSelection

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(HandrailSection.allCases) { section in
                    sidebarButton(for: section)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .navigationTitle("Handrail")
    }

    private func sidebarButton(for section: HandrailSection) -> some View {
        Button {
            selection.selectSection(section)
        } label: {
            Label(section.title, systemImage: systemImage(for: section))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selection.selectedSection == section ? Color.accentColor : Color.primary)
        .background(selection.selectedSection == section ? Color.accentColor.opacity(0.16) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .hoverEffect(.highlight)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selection.selectedSection == section ? .isSelected : [])
    }

    private func systemImage(for section: HandrailSection) -> String {
        switch section {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .chats: "rectangle.stack"
        case .attention: "exclamationmark.triangle"
        case .activity: "waveform.path.ecg"
        case .alerts: "bell"
        case .settings: "gearshape"
        }
    }
}

#Preview {
    NavigationStack {
        IPadSidebarView(selection: .constant(IPadWorkspaceSelection()))
    }
    .preferredColorScheme(.dark)
}
