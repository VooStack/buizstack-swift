import Foundation

enum TelemetryRecord {
    case error(timestamp: Date, type: String, message: String, stacktrace: String?, fatal: Bool, attributes: [String: Any])
    case event(timestamp: Date, name: String, attributes: [String: Any])

    var urgent: Bool {
        if case .error(_, _, _, _, let fatal, _) = self { return fatal }
        return false
    }
}
