import Foundation

public struct ReplayVideo {
    public let data: Data
    public let contentType: String
    public let width: Int
    public let height: Int
}

struct ReplaySegment {
    let id: Int
    let startedAt: Date
    let endedAt: Date
    let items: [ReplayItem]
    let video: ReplayVideo?
    let errorCount: Int
}

public protocol ReplayCapture: AnyObject {
    func startSegment(options: ReplayOptions)
    func endSegment() -> ReplayVideo?
    func dispose()
}
