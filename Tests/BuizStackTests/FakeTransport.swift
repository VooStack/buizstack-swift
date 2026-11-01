import Foundation

@testable import BuizStack

final class FakeTransport: HttpTransport {
    var config = "{}"
    private let lock = NSLock()
    private(set) var posts: [(URL, Data)] = []

    override func post(_ url: URL, key: String, contentType: String, body: Data) -> Int {
        lock.withLock { posts.append((url, body)) }
        return 200
    }

    override func get(_ url: URL, key: String) -> (Int, Data) { (200, Data(config.utf8)) }

    var uploads: [String] {
        lock.withLock { posts.filter { $0.0.path.hasSuffix("/v1/replays") }.map { String(decoding: $0.1, as: UTF8.self) } }
    }

    var uploadBodies: [Data] { lock.withLock { posts.filter { $0.0.path.hasSuffix("/v1/replays") }.map(\.1) } }
}
