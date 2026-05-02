import SwiftUI

struct SettingsView: View {
    @Environment(HandrailStore.self) private var store
    @State private var showsScanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Paired machine", systemImage: "desktopcomputer")
                            .font(.headline)
                        if let machine = store.pairedMachine {
                            Text(machine.machineName)
                            Text("\(machine.host):\(machine.port)")
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
                        .tint(.purple)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About", systemImage: "info.circle")
                            .font(.headline)
                        Text("Version 0.1.0")
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
}
