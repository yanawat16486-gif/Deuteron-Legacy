import Foundation

private struct EngineLock: Decodable {
    struct Archive: Decodable {
        let version: String
        let url: URL
        let sha256: String
    }
    struct Components: Decodable {
        let wine: Archive
        let template: Archive
    }
    let schemaVersion: Int
    let engineId: String
    let components: Components
}

enum EngineInstaller {
    static let engineID = "sikarugir-wine-11.0_1"

    static var installed: Bool {
        FileManager.default.isExecutableFile(
            atPath: SupportPaths.runners.appending(path: engineID + "/bin/wine").path(percentEncoded: false))
    }

    static func install() async throws -> String {
        guard let lockURL = Bundle.module.url(forResource: "engine-lock", withExtension: "json") else {
            throw StepFailure(step: "Install Wine Engine", detail: "The engine lock file is missing from the app.")
        }
        let lock = try JSONDecoder().decode(EngineLock.self, from: Data(contentsOf: lockURL))
        guard lock.schemaVersion == 1, lock.engineId == engineID else {
            throw StepFailure(step: "Install Wine Engine", detail: "The engine lock file is not supported by this app.")
        }

        let fm = FileManager.default
        let target = SupportPaths.runners.appending(path: engineID)
        if installed { return try version(at: target) }
        guard !fm.fileExists(atPath: target.path(percentEncoded: false)) else {
            throw StepFailure(step: "Install Wine Engine", detail: "An incomplete engine folder already exists. Remove it before retrying.")
        }

        let downloads = SupportPaths.home.appending(path: "Library/Caches/notproton/engines")
        let wineArchive = try await obtain(lock.components.wine, into: downloads)
        let templateArchive = try await obtain(lock.components.template, into: downloads)

        try fm.createDirectory(at: SupportPaths.runners, withIntermediateDirectories: true)
        let work = SupportPaths.runners.appending(path: ".\(engineID)-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: work) }

        let wineExtract = work.appending(path: "wine-extract")
        let templateExtract = work.appending(path: "template-extract")
        let staged = work.appending(path: "runner")
        try fm.createDirectory(at: wineExtract, withIntermediateDirectories: false)
        try fm.createDirectory(at: templateExtract, withIntermediateDirectories: false)
        try Shell.check("/usr/bin/tar", ["-xJf", wineArchive.path(percentEncoded: false), "-C", wineExtract.path(percentEncoded: false)])
        try Shell.check("/usr/bin/tar", ["-xJf", templateArchive.path(percentEncoded: false), "-C", templateExtract.path(percentEncoded: false)])

        let source = wineExtract.appending(path: "wswine.bundle")
        let template = templateExtract.appending(path: "Template-\(lock.components.template.version).app/Contents")
        guard fm.isExecutableFile(atPath: source.appending(path: "bin/wine").path(percentEncoded: false)),
              fm.fileExists(atPath: template.appending(path: "Frameworks").path(percentEncoded: false)) else {
            throw StepFailure(step: "Install Wine Engine", detail: "The downloaded engine has an unexpected layout.")
        }
        try Shell.check("/usr/bin/ditto", [source.path(percentEncoded: false), staged.path(percentEncoded: false)])
        try Shell.check("/usr/bin/ditto", [template.appending(path: "Frameworks").path(percentEncoded: false), staged.appending(path: "Frameworks").path(percentEncoded: false)])
        let vulkan = template.appending(path: "Resources/vulkan")
        if fm.fileExists(atPath: vulkan.path(percentEncoded: false)) {
            try Shell.check("/usr/bin/ditto", [vulkan.path(percentEncoded: false), staged.appending(path: "vulkan").path(percentEncoded: false)])
        }
        let foundVersion = try version(at: staged)
        guard foundVersion.lowercased().contains("wine-11") else {
            throw StepFailure(step: "Install Wine Engine", detail: "The Wine version does not match the locked engine.")
        }
        guard !fm.fileExists(atPath: target.path(percentEncoded: false)) else {
            throw StepFailure(step: "Install Wine Engine", detail: "The engine was installed by another operation. Refresh and retry.")
        }
        try fm.moveItem(at: staged, to: target)
        return foundVersion
    }

    private static func obtain(_ archive: EngineLock.Archive, into downloads: URL) async throws -> URL {
        try await PinnedDownload.obtain(
            file: archive.url.lastPathComponent,
            sha256: archive.sha256,
            bases: [archive.url.deletingLastPathComponent()],
            into: downloads,
            step: "Download Wine Engine",
            from: "Sikarugir"
        )
    }

    static func version(at root: URL) throws -> String {
        let frameworks = root.appending(path: "Frameworks").path(percentEncoded: false)
        var environment = ProcessInfo.processInfo.environment
        environment["DYLD_FALLBACK_LIBRARY_PATH"] = [
            root.appending(path: "lib").path(percentEncoded: false),
            frameworks,
            frameworks + "/GStreamer.framework/Libraries",
            "/usr/lib"
        ].joined(separator: ":")
        return try Shell.check(root.appending(path: "bin/wine").path(percentEncoded: false), ["--version"], environment: environment)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
