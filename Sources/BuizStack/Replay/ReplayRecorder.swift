import Foundation

public final class ReplayRecorder {
    public enum Mode { case off, buffering, recording }

    public let options: ReplayOptions
    public let replayId: String
    private let uploader: ReplayUploader
    private let capture: ReplayCapture?
    private let clock: () -> Date
    private let random: () -> Double
    private let queue = DispatchQueue(label: "com.buizstack.replay", qos: .utility)
    private var buffer: [ReplaySegment] = []
    private var items: [ReplayItem] = []
    private var segmentStart: Date?
    private var viewport: ReplayItem?
    private var screen: ReplayItem?
    private var nextId = 0
    private var errors = 0
    private var type = "session"
    private var remote = ReplayRemoteConfig()
    private var timer: DispatchSourceTimer?
    public private(set) var mode = Mode.off
    public private(set) var effectiveOptions: ReplayOptions

    init(
        options: ReplayOptions,
        uploader: ReplayUploader,
        replayId: String,
        capture: ReplayCapture? = nil,
        clock: @escaping () -> Date = Date.init,
        random: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.options = options
        self.uploader = uploader
        self.replayId = replayId
        self.capture = capture
        self.clock = clock
        self.random = random
        effectiveOptions = options
    }

    public var bufferedSegments: Int { queue.sync { buffer.count } }

    public func start() {
        queue.sync {
            guard options.enabled, mode == .off else { return }
            remote = uploader.config() ?? ReplayRemoteConfig()
            guard remote.enabled else { return }
            effectiveOptions = options.tightened(maskAllText: remote.maskAllText)
            let context = uploader.context()
            let listed = remote.alwaysRecords(
                environment: context["environment"] as? String,
                release: context["release"] as? String,
                userId: context["userId"] as? String
            )
            if listed || random() < (remote.sessionSampleRate ?? options.sessionSampleRate) {
                mode = .recording
            } else if random() < (remote.onErrorSampleRate ?? options.onErrorSampleRate) {
                mode = .buffering
                type = "buffer"
            } else {
                return
            }
            capture?.startSegment(options: effectiveOptions)
            begin()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + options.segmentDuration, repeating: options.segmentDuration)
            timer.setEventHandler { [weak self] in self?.close(next: true) }
            timer.resume()
            self.timer = timer
        }
    }

    public func add(_ item: ReplayItem) {
        queue.async { [self] in
            guard mode != .off else { return }
            switch item.kind {
            case .viewport: viewport = item
            case .screen: screen = item
            default: break
            }
            items.append(item)
        }
    }

    public func onError() {
        queue.sync {
            guard mode != .off else { return }
            errors += 1
            promote()
        }
    }

    public func identify(_ userId: String?) { queue.sync { if remote.alwaysRecords(userId: userId) { promote() } } }

    public func rotate() { queue.sync { close(next: true) } }

    public func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            if mode != .off { close(next: false) }
            mode = .off
            buffer.removeAll()
            capture?.dispose()
        }
    }

    private func promote() {
        guard mode == .buffering else { return }
        mode = .recording
        let pending = buffer
        buffer.removeAll()
        pending.forEach { uploader.upload(replayId: replayId, type: type, segment: $0) }
    }

    private func begin() {
        let now = clock()
        segmentStart = now
        items = []
        if let viewport, let width = viewport.width, let height = viewport.height { items.append(.viewport(now, width, height)) }
        if let screen, let name = screen.name { items.append(.screen(now, name)) }
        errors = 0
    }

    private func close(next: Bool) {
        guard let start = segmentStart, mode != .off else { return }
        let video = capture?.endSegment()
        let segment = ReplaySegment(id: nextId, startedAt: start, endedAt: clock(), items: items, video: video, errorCount: errors)
        nextId += 1
        if next {
            capture?.startSegment(options: effectiveOptions)
            begin()
        } else {
            segmentStart = nil
        }
        if mode == .recording {
            uploader.upload(replayId: replayId, type: type, segment: segment)
            return
        }
        buffer.append(segment)
        let oldest = clock().addingTimeInterval(-options.buffer)
        buffer.removeAll { $0.endedAt < oldest }
    }
}
