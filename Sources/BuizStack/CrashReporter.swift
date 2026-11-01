import Foundation
import MetricKit

final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    private static var store: CrashStore?
    private static var encode: (([TelemetryRecord]) -> Data)?
    private static var context: (() -> [String: Any])?
    private static var previous: NSUncaughtExceptionHandler?
    private let report: (TelemetryRecord) -> Void

    init(store: CrashStore, encode: @escaping ([TelemetryRecord]) -> Data, context: @escaping () -> [String: Any], report: @escaping (TelemetryRecord) -> Void) {
        self.report = report
        super.init()
        Self.store = store
        Self.encode = encode
        Self.context = context
        Self.previous = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            let record = TelemetryRecord.error(
                timestamp: Date(),
                type: exception.name.rawValue,
                message: exception.reason ?? exception.name.rawValue,
                stacktrace: exception.callStackSymbols.joined(separator: "\n"),
                fatal: true,
                attributes: CrashReporter.context?() ?? [:]
            )
            if let encode = CrashReporter.encode { CrashReporter.store?.save(encode([record])) }
            CrashReporter.previous?(exception)
        }
        MXMetricManager.shared.add(self)
    }

    func stop() { MXMetricManager.shared.remove(self) }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                let signal = crash.signal.map { "signal \($0)" }
                let type = crash.exceptionType.map { "EXC_\($0)" } ?? signal ?? "Crash"
                report(
                    .error(
                        timestamp: payload.timeStampEnd,
                        type: type,
                        message: crash.terminationReason ?? [type, signal].compactMap { $0 }.joined(separator: " · "),
                        stacktrace: Self.frames(crash.callStackTree),
                        fatal: true,
                        attributes: ["crash.source": "metrickit", "app.version": crash.applicationVersion]
                    )
                )
            }
            for hang in payload.hangDiagnostics ?? [] {
                report(
                    .error(
                        timestamp: payload.timeStampEnd,
                        type: "AppHang",
                        message: "The main thread was blocked for \(hang.hangDuration.description)",
                        stacktrace: Self.frames(hang.callStackTree),
                        fatal: false,
                        attributes: ["crash.source": "metrickit"]
                    )
                )
            }
        }
    }

    private static func frames(_ tree: MXCallStackTree) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: tree.jsonRepresentation()) as? [String: Any],
            let stacks = json["callStacks"] as? [[String: Any]],
            let crashed = stacks.first(where: { $0["threadAttributed"] as? Bool == true }) ?? stacks.first,
            let roots = crashed["callStackRootFrames"] as? [[String: Any]]
        else { return nil }
        var lines: [String] = []
        var frame = roots.first
        while let current = frame, lines.count < 64 {
            let binary = current["binaryName"] as? String ?? "?"
            let offset = current["offsetIntoBinaryTextSegment"] as? Int ?? 0
            lines.append("at \(binary) + \(offset)")
            frame = (current["subFrames"] as? [[String: Any]])?.first
        }
        return lines.joined(separator: "\n")
    }
}
