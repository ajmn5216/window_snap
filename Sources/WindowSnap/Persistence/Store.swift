import Foundation

/// JSON persistence in `~/Library/Application Support/WindowSnap/config.json`.
/// Only user-created layouts and settings are stored; built-in layouts are
/// regenerated at launch (so updates to presets always take effect).
final class Store {
    static let shared = Store()

    struct Config: Codable {
        var settings: Settings
        var userLayouts: [Layout]
    }

    private let dir: URL
    private let configURL: URL

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = appSupport.appendingPathComponent("WindowSnap", isDirectory: true)
        configURL = dir.appendingPathComponent("config.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    var configPath: String { configURL.path }

    func load() -> Config {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            return Config(settings: Settings(), userLayouts: [])
        }
        return config
    }

    func save(_ config: Config) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: configURL, options: .atomic)
    }
}
