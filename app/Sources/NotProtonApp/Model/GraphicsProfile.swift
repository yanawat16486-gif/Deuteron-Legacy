import Foundation

struct NotProtonGraphicsProfile: Codable, Equatable, Sendable {
    var renderer: String = ""
    var retina = false
    var overlay = true
}

enum GraphicsProfileStore {
    static func read(from root: URL) -> NotProtonGraphicsProfile {
        let file = root.appending(path: "notproton-profile.json")
        guard let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(NotProtonGraphicsProfile.self, from: data) else { return .init() }
        return value
    }
    static func write(_ profile: NotProtonGraphicsProfile, to root: URL) throws {
        try JSONEncoder().encode(profile).write(to: root.appending(path: "notproton-profile.json"), options: .atomic)
    }
}
