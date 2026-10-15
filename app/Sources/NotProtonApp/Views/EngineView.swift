import SwiftUI
import AppKit

struct EngineView: View {
    @State private var busy = false
    @State private var message: String?
    @State private var settingsPane: URL?

    var body: some View {
        Form {
            Section("Sikarugir Wine 11") {
                LabeledContent("Status", value: EngineInstaller.installed ? "Installed" : "Not installed")
                Text("Downloads Wine and its runtime libraries, verifies both archives, then installs them in NotProton's support folder.")
                    .foregroundStyle(.secondary)
                Button(EngineInstaller.installed ? "Installed" : "Install Wine Engine") {
                    busy = true
                    message = "Downloading and checking engine files…"
                    Task {
                        do {
                            let version = try await Task.detached(priority: .userInitiated) {
                                try await EngineInstaller.install()
                            }.value
                            message = "Installed \(version)."
                        } catch {
                            message = error.localizedDescription
                        }
                        busy = false
                    }
                }
                .disabled(busy || EngineInstaller.installed)
                if EngineInstaller.installed {
                    LabeledContent("Steam patch", value: patchLabel)
                    Button("Patch Steam support") {
                        busy = true
                        message = "Checking and patching ntdll.dll…"
                        Task {
                            do {
                                message = try await Task.detached(priority: .userInitiated) {
                                    try SikarugirNtdllPatcher.apply()
                                }.value
                            } catch {
                                message = error.localizedDescription
                            }
                            busy = false
                        }
                    }
                    .disabled(busy || SikarugirNtdllPatcher.state() != .clean)
                    LabeledContent("Steam connection", value: SikarugirSetup.isReady() ? "Connected" : "Not connected")
                    Button(SikarugirSetup.isReady() ? "Reconnect to Steam" : "Connect to Steam") {
                        busy = true
                        message = "Preparing Steam and Wine 11…"
                        Task {
                            do {
                                message = try await SikarugirSetup.connect { progress in
                                    Task { @MainActor in message = progress }
                                }
                            } catch {
                                if let refused = error as? WriteRefused {
                                    message = "\(refused.localizedDescription) \(refused.remedy.advice)"
                                    settingsPane = refused.remedy.settingsPane
                                } else {
                                    message = error.localizedDescription
                                    settingsPane = nil
                                }
                            }
                            busy = false
                        }
                    }
                    .disabled(busy || SikarugirNtdllPatcher.state() != .patched)
                    if let settingsPane {
                        Button("Open App Management Settings") {
                            NSWorkspace.shared.open(settingsPane)
                        }
                    }
                }
                if busy { ProgressView() }
                if let message { Text(message).textSelection(.enabled) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Wine Engine")
    }

    private var patchLabel: String {
        switch SikarugirNtdllPatcher.state() {
        case .missing: "ntdll.dll missing"
        case .clean: "Ready to patch"
        case .patched: "Patched"
        case .unknown: "Unknown build"
        }
    }
}
