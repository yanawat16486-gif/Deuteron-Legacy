import Foundation

enum SikarugirSetup {
    static let step = "Connect Sikarugir Wine to Steam"
    static let toolName = "notproton-sikarugir11"
    static let patchedNtdllSHA256 = "5429ba1fcd340b4f9bd39e19c9fed38771578203e8574421b44c806a8f6da529"

    static let tool = InstalledTool(
        tool: CompatTool(name: toolName, flavor: .rosetta, display: "NotProton Wine 11 (Sikarugir)"),
        build: EngineInstaller.engineID)

    static let builtins = [
        (arch: "i386-windows", name: "lsteamclient.dll"),
        (arch: "x86_64-windows", name: "lsteamclient.dll"),
        (arch: "x86_64-unix", name: "lsteamclient.so"),
    ]

    static func isReady(runners: URL = SupportPaths.runners, bridge: URL = SupportPaths.bridge) -> Bool {
        let root = runners.appending(path: EngineInstaller.engineID)
        let ntdll = root.appending(path: "lib/wine/x86_64-windows/ntdll.dll")
        let staged = bridge.appending(path: "wine/\(EngineInstaller.engineID)/x86_64-windows/ntdll.dll")
        guard FileManager.default.isExecutableFile(atPath: root.appending(path: "bin/wine").path(percentEncoded: false)),
              Digest.sha256IfPresent(ntdll) == patchedNtdllSHA256,
              Digest.sha256IfPresent(staged) == patchedNtdllSHA256 else { return false }
        return builtins.allSatisfy { builtin in
            let path = "\(builtin.arch)/\(builtin.name)"
            guard let source = Digest.sha256IfPresent(bridge.appending(path: path)) else { return false }
            return Digest.sha256IfPresent(root.appending(path: "lib/wine/\(path)")) == source
        }
    }

    static func connect(report: @escaping @Sendable (String) -> Void = { _ in }) async throws -> String {
        guard SikarugirNtdllPatcher.state() == .patched else {
            throw StepFailure(step: step, detail: "Patch the Sikarugir Wine 11 ntdll.dll before connecting to Steam.")
        }
        let root = SupportPaths.runners.appending(path: EngineInstaller.engineID)
        guard try EngineInstaller.version(at: root).lowercased().contains("wine-11") else {
            throw StepFailure(step: step, detail: "The locked Sikarugir Wine 11 engine is not installed.")
        }
        guard !RunnerInstaller.isRunning(from: root) else {
            throw StepFailure(step: step, detail: "Wine 11 is running. Quit the game or Wine tool before connecting to Steam.")
        }
        let payload = try InstallPayload.locate()
        let bridgePayload = try BridgePayload.locate()
        let lock = try DeploymentContent.acquireInstallationLock()
        defer { lock.release() }

        report("Installing NotProton into Steam")
        let installation = try SteamInstaller.run(
            payload: payload, bridgePayload: bridgePayload, holdingInstallationLock: true,
            report: { report($0.label) })

        let manifest = try ValvePackageManifest.bundled()
        if manifest.files.contains(where: {
            Digest.sha256IfPresent(SupportPaths.bridge.appending(path: $0.bridgePath)) != $0.sha256
        }) {
            report("Downloading Steam bridge files")
            _ = try await ValveFetcher.run(manifest: manifest) { report($0.label) }
        }

        report("Connecting Wine 11")
        for builtin in builtins {
            let path = "\(builtin.arch)/\(builtin.name)"
            let source = SupportPaths.bridge.appending(path: path)
            let destination = root.appending(path: "lib/wine/\(path)")
            guard Digest.sha256IfPresent(source) != nil else {
                throw StepFailure(step: step, detail: "The Steam bridge is missing \(path).")
            }
            if Digest.sha256IfPresent(source) != Digest.sha256IfPresent(destination) {
                try atomicReplace(destination, from: source, step: step)
            }
        }

        let ntdll = root.appending(path: "lib/wine/x86_64-windows/ntdll.dll")
        guard Digest.sha256IfPresent(ntdll) == patchedNtdllSHA256 else {
            throw StepFailure(step: step, detail: "The patched Wine 11 ntdll.dll changed. No compatibility tool was registered.")
        }
        let staged = SupportPaths.bridge.appending(path: "wine/\(EngineInstaller.engineID)/x86_64-windows/ntdll.dll")
        if Digest.sha256IfPresent(staged) != patchedNtdllSHA256 {
            try atomicReplace(staged, from: ntdll, step: step)
        }
        guard isReady() else {
            throw StepFailure(step: step, detail: "Wine 11 and the Steam bridge did not pass the final check.")
        }

        let toolFolder = SupportPaths.Steam.compatTools.appending(path: toolName)
        let run = toolFolder.appending(path: "run")
        try atomicReplace(run, from: payload.run, step: step)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: run.path(percentEncoded: false))
        _ = try CompatToolList.sync()

        try SteamInstaller.finish(installation)
        return installation.stoppedClient
            ? "Wine 11 is connected. Start Steam again and choose NotProton Wine 11 (Sikarugir) for a game."
            : "Wine 11 is connected. Restart Steam to see NotProton Wine 11 (Sikarugir)."
    }
}
