import Foundation

final class BuizStackClient {
    private let dsn: BuizStackDsn
    private let encoder: OtlpLogEncoder
    private let transport: HttpTransport
    private let queue = DispatchQueue(label: "com.buizstack.telemetry", qos: .utility)
    private var pending: [TelemetryRecord] = []
    private var scheduled = false

    init(dsn: BuizStackDsn, encoder: OtlpLogEncoder, transport: HttpTransport) {
        self.dsn = dsn
        self.encoder = encoder
        self.transport = transport
    }

    func add(_ record: TelemetryRecord) {
        queue.async { [self] in
            if pending.count >= 500 { pending.removeFirst() }
            pending.append(record)
            if record.urgent || pending.count >= 50 {
                drain()
            } else if !scheduled {
                scheduled = true
                queue.asyncAfter(deadline: .now() + 5) { [self] in drain() }
            }
        }
    }

    func encode(_ records: [TelemetryRecord]) -> Data { encoder.encode(records) }

    @discardableResult
    func send(_ payload: Data) -> Bool { transport.post(dsn.signal("logs"), key: dsn.publicKey, contentType: "application/json", body: payload) < 300 }

    func flush() { queue.sync { drain() } }

    private func drain() {
        scheduled = false
        while !pending.isEmpty {
            let batch = Array(pending.prefix(50))
            pending.removeFirst(batch.count)
            send(encoder.encode(batch))
        }
    }
}
