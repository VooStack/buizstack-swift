import Foundation

struct ReplayRemoteConfig {
    var enabled = true
    var sessionSampleRate: Double?
    var onErrorSampleRate: Double?
    var maskAllText = false
    var environments: Set<String> = []
    var releases: Set<String> = []
    var userIds: Set<String> = []

    init() {}

    init?(json: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { return nil }
        enabled = object["enabled"] as? Bool ?? true
        sessionSampleRate = object["sessionSampleRate"] as? Double
        onErrorSampleRate = object["onErrorSampleRate"] as? Double
        maskAllText = object["maskAllText"] as? Bool ?? false
        environments = Set((object["fullRecordEnvironments"] as? [String] ?? []).map { $0.lowercased() })
        releases = Set(object["fullRecordReleases"] as? [String] ?? [])
        userIds = Set(object["fullRecordUserIds"] as? [String] ?? [])
    }

    func alwaysRecords(environment: String? = nil, release: String? = nil, userId: String? = nil) -> Bool {
        (environment.map { environments.contains($0.lowercased()) } ?? false) || (release.map(releases.contains) ?? false)
            || (userId.map(userIds.contains) ?? false)
    }
}
