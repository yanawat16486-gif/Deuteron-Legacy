import Darwin
import Foundation

private struct SikarugirPatchProfile: Decodable {
    struct Range: Decodable {
        let offset: Int
        let bytes: String
    }
    let engine: String
    let file: String
    let cleanSha256: String
    let patchedSha256: String
    let ranges: [Range]
}

enum SikarugirNtdllPatcher {
    enum State {
        case missing, clean, patched, unknown
    }

    static let step = "Patch Sikarugir ntdll"
    private static let expectedEngine = "WS12WineSikarugir11.0_1"
    private static let expectedFile = "lib/wine/x86_64-windows/ntdll.dll"

    static func state() -> State {
        guard let profile = try? loadProfile(),
              let hash = Digest.sha256IfPresent(target(for: profile)) else { return .missing }
        if hash == profile.cleanSha256 { return .clean }
        if hash == profile.patchedSha256 { return .patched }
        return .unknown
    }

    static func apply() throws -> String {
        let profile = try loadProfile()
        let root = SupportPaths.runners.appending(path: EngineInstaller.engineID)
        guard FileManager.default.isExecutableFile(
            atPath: root.appending(path: "bin/wine").path(percentEncoded: false)),
              try EngineInstaller.version(at: root).lowercased().contains("wine-11") else {
            throw StepFailure(step: step, detail: "The locked Sikarugir Wine 11 engine is not installed.")
        }
        let target = target(for: profile)
        guard let existingHash = Digest.sha256IfPresent(target) else {
            throw StepFailure(step: step, detail: "The x86_64 ntdll.dll is missing.")
        }
        if existingHash == profile.patchedSha256 { return "Already patched" }
        guard existingHash == profile.cleanSha256 else {
            throw StepFailure(step: step, detail: "The ntdll.dll hash does not match the locked clean build. No file was changed.")
        }
        guard !RunnerInstaller.isRunning(from: root) else {
            throw StepFailure(step: step, detail: "Wine is running. Quit Wine and retry the patch.")
        }

        var data = try Data(contentsOf: target)
        for range in profile.ranges {
            guard range.offset >= 0, let bytes = Data(hex: range.bytes),
                  range.offset <= data.count - bytes.count else {
                throw StepFailure(step: step, detail: "The patch profile contains an invalid byte range.")
            }
            data.replaceSubrange(range.offset..<(range.offset + bytes.count), with: bytes)
        }
        guard Digest.sha256(of: data) == profile.patchedSha256 else {
            throw StepFailure(step: step, detail: "The patched bytes failed SHA-256 verification. No file was changed.")
        }

        let temporary = target.deletingLastPathComponent().appending(path: ".ntdll-\(UUID().uuidString).dll")
        let fm = FileManager.default
        try fm.copyItem(at: target, to: temporary)
        defer { try? fm.removeItem(at: temporary) }
        try data.write(to: temporary)
        guard Digest.sha256IfPresent(temporary) == profile.patchedSha256 else {
            throw StepFailure(step: step, detail: "The staged ntdll.dll failed SHA-256 verification. No file was changed.")
        }
        guard Digest.sha256IfPresent(target) == profile.cleanSha256 else {
            throw StepFailure(step: step, detail: "The original ntdll.dll changed while patching. No file was replaced.")
        }
        guard rename(temporary.path(percentEncoded: false), target.path(percentEncoded: false)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return "Patched Sikarugir Wine 11 ntdll.dll"
    }

    private static func loadProfile() throws -> SikarugirPatchProfile {
        guard let url = Bundle.module.url(forResource: "ntdll-sikarugir11", withExtension: "json") else {
            throw StepFailure(step: step, detail: "The Sikarugir patch profile is missing from the app.")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let profile = try decoder.decode(SikarugirPatchProfile.self, from: Data(contentsOf: url))
        guard profile.engine == expectedEngine, profile.file == expectedFile,
              profile.ranges.count == 4 else {
            throw StepFailure(step: step, detail: "The Sikarugir patch profile does not match this engine.")
        }
        return profile
    }

    private static func target(for profile: SikarugirPatchProfile) -> URL {
        SupportPaths.runners.appending(path: EngineInstaller.engineID).appending(path: profile.file)
    }
}

private extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var result = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            result.append(byte)
            index = next
        }
        self = result
    }
}
