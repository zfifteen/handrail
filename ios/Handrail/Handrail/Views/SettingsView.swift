import SwiftUI

struct SettingsView: View {
    @Environment(HandrailStore.self) private var store
    @State private var showsScanner = false

    var body: some View {
        let metadata = AppBuildMetadata.current

        ScrollView {
            VStack(spacing: 14) {
                Card {
                    VStack(spacing: 0) {
                        NavigationLink {
                            PairingManagementView()
                        } label: {
                            settingsRow("Pairing", systemImage: "desktopcomputer")
                        }
                        Divider()
                        NavigationLink {
                            LocalNetworkHelpView()
                        } label: {
                            settingsRow("Local network", systemImage: "network")
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Paired machine", systemImage: "desktopcomputer")
                            .font(.headline)
                        if let machine = store.pairedMachine {
                            Text(machine.machineName)
                            Text(verbatim: machine.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(store.connectionText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(machine.isOnline ? .green : .secondary)
                        } else {
                            Text("No machine paired.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let pairingError = store.pairingError {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Pairing needs reset", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                            Text(pairingError)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button(role: .destructive) {
                                store.resetPairing()
                            } label: {
                                Label("Reset Pairing", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Pair new device", systemImage: "qrcode")
                            .font(.headline)
                        Text("Run this on your Mac:")
                            .foregroundStyle(.secondary)
                        Text("handrail pair")
                            .font(.system(.body, design: .monospaced))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        Button {
                            showsScanner = true
                        } label: {
                            Label("Scan QR", systemImage: "camera.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About", systemImage: "info.circle")
                            .font(.headline)
                        Text(metadata.versionText)
                            .foregroundStyle(.secondary)
                        Text(metadata.lastUpdatedText)
                            .foregroundStyle(.secondary)
                        Text("Works with OpenAI Codex Desktop. Not affiliated with OpenAI.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Settings")
        .sheet(isPresented: $showsScanner) {
            QRScannerView { payload in
                store.pair(with: payload)
                showsScanner = false
            }
        }
    }

    private func settingsRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct PairingManagementView: View {
    @Environment(HandrailStore.self) private var store
    @State private var showsScanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Pairing", systemImage: "desktopcomputer")
                            .font(.headline)
                        if let machine = store.pairedMachine {
                            Text(machine.machineName)
                                .font(.title3.weight(.semibold))
                            Text(store.connectionText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(machine.isOnline ? .green : .secondary)
                        } else {
                            Text("No machine paired.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    showsScanner = true
                } label: {
                    Label("Scan QR", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)

                Button(role: .destructive) {
                    store.resetPairing()
                } label: {
                    Label("Reset Pairing", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Pairing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsScanner) {
            QRScannerView { payload in
                store.pair(with: payload)
                showsScanner = false
            }
        }
    }
}

private struct LocalNetworkHelpView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Local network", systemImage: "network")
                            .font(.headline)
                        Text("Start the local Handrail server on your Mac, then pair this iPhone from the QR code.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                commandCard("handrail serve")
                commandCard("handrail pair")
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Local network")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func commandCard(_ command: String) -> some View {
        Card {
            Text(command)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
