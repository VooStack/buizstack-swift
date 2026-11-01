import Foundation

final class ReplayUploader {
    private let dsn: BuizStackDsn
    private let transport: HttpTransport
    let context: () -> [String: Any]

    init(dsn: BuizStackDsn, transport: HttpTransport, context: @escaping () -> [String: Any]) {
        self.dsn = dsn
        self.transport = transport
        self.context = context
    }

    func config() -> ReplayRemoteConfig? {
        let (code, body) = transport.get(dsn.signal("replay-config"), key: dsn.publicKey)
        return code == 200 ? ReplayRemoteConfig(json: body) : nil
    }

    @discardableResult
    func upload(replayId: String, type: String, segment: ReplaySegment) -> Bool {
        var metadata = context()
        metadata["replayId"] = replayId
        metadata["segment"] = segment.id
        metadata["type"] = type
        metadata["startedAt"] = Int64(segment.startedAt.timeIntervalSince1970 * 1000)
        metadata["endedAt"] = Int64(segment.endedAt.timeIntervalSince1970 * 1000)
        metadata["errorCount"] = segment.errorCount
        let timeline: [String: Any] = ["items": segment.items.map(\.json)]
        let boundary = "buizstack-\(UUID().uuidString)"
        var body = Data()
        func part(_ name: String, _ filename: String, _ type: String, _ data: Data) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(type)\r\n\r\n".utf8))
            body.append(data)
            body.append(Data("\r\n".utf8))
        }
        part("metadata", "metadata.json", "application/json", (try? JSONSerialization.data(withJSONObject: metadata)) ?? Data())
        part("timeline", "timeline.json", "application/json", (try? JSONSerialization.data(withJSONObject: timeline)) ?? Data())
        if let video = segment.video { part("video", "segment.mp4", video.contentType, video.data) }
        body.append(Data("--\(boundary)--\r\n".utf8))
        return transport.post(dsn.signal("replays"), key: dsn.publicKey, contentType: "multipart/form-data; boundary=\(boundary)", body: body) < 300
    }
}
