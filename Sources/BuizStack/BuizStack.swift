import Foundation
import UIKit

public enum BuizStack {
    private static let lock = NSLock()
    private static var client: BuizStackClient?
    private static var reporter: CrashReporter?
    private static var watchdog: HangWatchdog?
    private static var capture: ViewReplayCapture?
    private static var lastScreen: String?
    private static var userId: String?
    private static var userEmail: String?
    private static var userName: String?
    private static let background = DispatchQueue(label: "com.buizstack.start", qos: .utility)

    public private(set) static var replay: ReplayRecorder?
    public private(set) static var sessionId = newSessionId()

    public static var isEnabled: Bool { client != nil }

    @discardableResult
    public static func start(
        dsn: String?,
        serviceName: String,
        environment: String = "production",
        release: String? = nil,
        replay replayOptions: ReplayOptions? = nil,
        captureCrashes: Bool = true,
        detectHangs: Bool = true,
        transport: HttpTransport = HttpTransport()
    ) -> Bool {
        guard let parsed = BuizStackDsn(dsn) else { return false }
        close()
        sessionId = newSessionId()
        let device = UIDevice.current
        let telemetry = BuizStackClient(
            dsn: parsed,
            encoder: OtlpLogEncoder(resource: [
                "service.name": serviceName,
                "service.version": release,
                "deployment.environment.name": environment,
                "telemetry.sdk.name": "buizstack.ios",
                "telemetry.sdk.language": "swift",
                "os.type": "ios",
                "os.version": device.systemVersion,
                "device.model.name": Self.model(),
            ]),
            transport: transport
        )
        client = telemetry
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("buizstack")
        let store = CrashStore(directory: directory)
        background.async { store.drain(telemetry.send) }
        if captureCrashes {
            reporter = CrashReporter(store: store, encode: telemetry.encode, context: context) { record in telemetry.add(record) }
        }
        if detectHangs {
            watchdog = HangWatchdog {
                captureError(type: "AppHang", message: "The main thread was blocked for 5 seconds", stacktrace: nil, fatal: false, attributes: ["hang": true])
            }
            watchdog?.start()
        }
        Instrumentation.install()
        Instrumentation.onScreen = { trackScreen($0) }
        if let replayOptions, replayOptions.enabled {
            let viewCapture = ViewReplayCapture()
            capture = viewCapture
            let model = Self.model()
            let os = "iOS \(device.systemVersion)"
            let recorder = ReplayRecorder(
                options: replayOptions,
                uploader: ReplayUploader(dsn: parsed, transport: transport) {
                    var context: [String: Any] = ["environment": environment, "platform": "ios", "device": model, "os": os]
                    context["release"] = release
                    context["userId"] = BuizStack.userId
                    return context
                },
                replayId: sessionId,
                capture: viewCapture
            )
            replay = recorder
            Instrumentation.onTouch = { window, point in
                viewCapture.touched()
                recorder.add(.tap(Date(), Double(point.x), Double(point.y)))
                recorder.add(.viewport(Date(), Int(window.bounds.width), Int(window.bounds.height)))
            }
            background.async { recorder.start() }
        }
        return true
    }

    public static func identify(_ userId: String?, email: String? = nil, name: String? = nil) {
        let signedOut = userId?.isEmpty ?? true
        lock.withLock {
            Self.userId = signedOut ? nil : userId
            userEmail = signedOut || (email?.isEmpty ?? true) ? nil : email
            userName = signedOut || (name?.isEmpty ?? true) ? nil : name
        }
        if let replay { background.async { replay.identify(signedOut ? nil : userId) } }
    }

    public static func track(_ name: String, properties: [String: Any] = [:]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed != "screen_view" { replay?.add(.event(Date(), trimmed)) }
        client?.add(.event(timestamp: Date(), name: trimmed, attributes: context().merging(properties) { $1 }))
    }

    public static func trackScreen(_ name: String) {
        guard name != lastScreen else { return }
        lastScreen = name
        replay?.add(.screen(Date(), name))
        track("screen_view", properties: ["screen.name": name])
    }

    public static func captureException(_ error: Error, fatal: Bool = false, attributes: [String: Any] = [:]) {
        let nsError = error as NSError
        captureError(
            type: String(reflecting: type(of: error)),
            message: nsError.localizedDescription,
            stacktrace: Thread.callStackSymbols.joined(separator: "\n"),
            fatal: fatal,
            attributes: attributes.merging(["error.domain": nsError.domain, "error.code": nsError.code]) { a, _ in a }
        )
    }

    public static func flush() { client?.flush() }

    public static func close() {
        watchdog?.stop()
        watchdog = nil
        reporter?.stop()
        reporter = nil
        if let replay { background.async { replay.stop() } }
        replay = nil
        capture = nil
        Instrumentation.onTouch = nil
        client = nil
        lastScreen = nil
    }

    private static func captureError(type: String, message: String, stacktrace: String?, fatal: Bool, attributes: [String: Any]) {
        client?.add(.error(timestamp: Date(), type: type, message: message, stacktrace: stacktrace, fatal: fatal, attributes: context().merging(attributes) { $1 }))
        if let replay { background.async { replay.onError() } }
    }

    private static func context() -> [String: Any] {
        lock.withLock {
            var context: [String: Any] = ["session.id": sessionId]
            context["user.id"] = userId
            context["user.email"] = userEmail
            context["user.name"] = userName
            return context
        }
    }

    private static func model() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    private static func newSessionId() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
