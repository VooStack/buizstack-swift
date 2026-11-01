import UIKit

final class ViewReplayCapture: ReplayCapture {
    static let maxWidth: CGFloat = 360
    static let interval: TimeInterval = 1
    static let maxDeferral: TimeInterval = 3

    private let encoderQueue = DispatchQueue(label: "com.buizstack.replay.encoder", qos: .utility)
    private let window: () -> UIWindow?
    private let isActive: () -> Bool

    init(
        window: @escaping () -> UIWindow? = ViewReplayCapture.keyWindow,
        isActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active }
    ) {
        self.window = window
        self.isActive = isActive
    }
    private var timer: Timer?
    private var options = ReplayOptions()
    private var encoder: ReplayEncoder?
    private var active = false
    private var waitingSince: Date?
    private(set) var lastTouch = Date.distantPast
    private(set) var snapshotTimes: [TimeInterval] = []
    private(set) var collectTimes: [TimeInterval] = []

    func touched() {
        lastTouch = Date()
    }

    func startSegment(options: ReplayOptions) {
        DispatchQueue.main.async { [self] in
            self.options = options
            active = true
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in self?.tick() }
        }
    }

    func endSegment() -> ReplayVideo? {
        let stop = { [self] in
            active = false
            timer?.invalidate()
            timer = nil
        }
        if Thread.isMainThread { stop() } else { DispatchQueue.main.sync(execute: stop) }
        return encoderQueue.sync {
            let current = encoder
            encoder = nil
            guard let current, let data = current.finish() else { return nil }
            return ReplayVideo(data: data, contentType: "video/mp4", width: current.width, height: current.height)
        }
    }

    func dispose() {
        DispatchQueue.main.async { [self] in
            active = false
            timer?.invalidate()
            timer = nil
        }
        encoderQueue.async { [self] in
            encoder?.cancel()
            encoder = nil
        }
    }

    private func tick() {
        guard active, isActive(), let window = window(), !window.bounds.isEmpty else { return }
        let now = Date()
        waitingSince = waitingSince ?? now
        if now.timeIntervalSince(lastTouch) < 0.3, now.timeIntervalSince(waitingSince!) < Self.maxDeferral { return }
        waitingSince = nil
        let collectStart = CACurrentMediaTime()
        let masks = ReplayMasks.collect(in: window, options: options)
        record(&collectTimes, CACurrentMediaTime() - collectStart)
        guard let masks else { return }
        let scale = min(1, Self.maxWidth / window.bounds.width)
        let width = Int(window.bounds.width * scale) / 2 * 2
        let height = Int(window.bounds.height * scale) / 2 * 2
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let snapshotStart = CACurrentMediaTime()
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { context in
            if !window.drawHierarchy(in: window.bounds, afterScreenUpdates: false) {
                window.layer.render(in: context.cgContext)
            }
        }
        record(&snapshotTimes, CACurrentMediaTime() - snapshotStart)
        guard let cgImage = image.cgImage else { return }
        let scaled = masks.map { CGRect(x: $0.minX * scale, y: $0.minY * scale, width: $0.width * scale, height: $0.height * scale) }
        encoderQueue.async { [self] in
            if encoder?.width != width || encoder?.height != height {
                encoder?.cancel()
                let output = FileManager.default.temporaryDirectory.appendingPathComponent("buizstack-replay-\(UUID().uuidString).mp4")
                encoder = try? ReplayEncoder(width: width, height: height, bitrate: 300_000, output: output)
            }
            encoder?.frame(cgImage, masks: scaled, at: now)
        }
    }

    private func record(_ samples: inout [TimeInterval], _ value: TimeInterval) {
        if samples.count >= 500 { samples.removeFirst() }
        samples.append(value)
    }

    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
