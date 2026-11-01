import Foundation

final class CrashStore {
    private let directory: URL

    init(directory: URL) { self.directory = directory }

    func save(_ payload: Data) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? payload.write(to: directory.appendingPathComponent("crash-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString).json"))
    }

    func drain(_ send: (Data) -> Bool) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files.filter({ $0.lastPathComponent.hasPrefix("crash-") }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let payload = try? Data(contentsOf: file) else {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            if send(payload) { try? FileManager.default.removeItem(at: file) }
        }
    }
}
