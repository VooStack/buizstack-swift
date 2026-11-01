import Foundation

public struct ReplayOptions {
    public var enabled: Bool
    public var sessionSampleRate: Double
    public var onErrorSampleRate: Double
    public var bufferDuration: TimeInterval
    public var segmentDuration: TimeInterval
    public var maskAllText: Bool
    public var maskImages: Bool

    public init(
        enabled: Bool = true,
        sessionSampleRate: Double = 0,
        onErrorSampleRate: Double = 1,
        bufferDuration: TimeInterval = 60,
        segmentDuration: TimeInterval = 10,
        maskAllText: Bool = false,
        maskImages: Bool = true
    ) {
        self.enabled = enabled
        self.sessionSampleRate = sessionSampleRate
        self.onErrorSampleRate = onErrorSampleRate
        self.bufferDuration = bufferDuration
        self.segmentDuration = segmentDuration
        self.maskAllText = maskAllText
        self.maskImages = maskImages
    }

    var buffer: TimeInterval { min(max(bufferDuration, 30), 120) }

    func tightened(maskAllText: Bool) -> ReplayOptions {
        var options = self
        options.maskAllText = self.maskAllText || maskAllText
        return options
    }
}
