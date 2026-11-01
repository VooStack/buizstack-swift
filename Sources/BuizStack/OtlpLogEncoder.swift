import Foundation

struct OtlpLogEncoder {
    let resource: [String: Any?]

    func encode(_ records: [TelemetryRecord]) -> Data {
        let body: [String: Any] = [
            "resourceLogs": [
                [
                    "resource": ["attributes": Self.attributes(resource)],
                    "scopeLogs": [["scope": ["name": "buizstack.ios"], "logRecords": records.map(Self.record)]],
                ]
            ]
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    private static func record(_ record: TelemetryRecord) -> [String: Any] {
        switch record {
        case let .error(timestamp, type, message, stacktrace, fatal, attributes):
            var all: [String: Any?] = attributes
            all["exception.type"] = type
            all["exception.message"] = message
            all["exception.stacktrace"] = stacktrace
            return [
                "timeUnixNano": nanos(timestamp),
                "severityNumber": fatal ? 21 : 17,
                "severityText": fatal ? "FATAL" : "ERROR",
                "body": ["stringValue": message],
                "attributes": Self.attributes(all),
            ]
        case let .event(timestamp, name, attributes):
            var all: [String: Any?] = attributes
            all["event.name"] = name
            return [
                "timeUnixNano": nanos(timestamp),
                "severityNumber": 9,
                "severityText": "INFO",
                "eventName": name,
                "body": ["stringValue": name],
                "attributes": Self.attributes(all),
            ]
        }
    }

    private static func nanos(_ date: Date) -> String { String(Int64(date.timeIntervalSince1970 * 1000) * 1_000_000) }

    private static func attributes(_ values: [String: Any?]) -> [[String: Any]] {
        values.keys.sorted().compactMap { key in
            guard let value = values[key] ?? nil else { return nil }
            let typed: [String: Any]
            switch value {
            case let v as Bool: typed = ["boolValue": v]
            case let v as Int: typed = ["intValue": String(v)]
            case let v as Double: typed = ["doubleValue": v]
            default: typed = ["stringValue": "\(value)"]
            }
            return ["key": key, "value": typed]
        }
    }
}
