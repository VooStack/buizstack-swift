import XCTest

@testable import BuizStack

final class TelemetryTests: XCTestCase {
    func testParsesDsnsIntoTheIngestBaseAndKey() {
        let dsn = BuizStackDsn("https://02e1cd03@ingest.buizstack.com/7a3bb8ce637c4e659defc96ebe324533")
        XCTAssertEqual(dsn?.publicKey, "02e1cd03")
        XCTAssertEqual(dsn?.signal("logs").absoluteString, "https://ingest.buizstack.com/7a3bb8ce637c4e659defc96ebe324533/v1/logs")
        XCTAssertNil(BuizStackDsn("https://ingest.buizstack.com/app"))
        XCTAssertNil(BuizStackDsn(nil))
    }

    func testEncodesErrorsAndEventsAsOtlpLogRecords() throws {
        let data = OtlpLogEncoder(resource: ["service.name": "shop", "service.version": nil]).encode([
            .error(timestamp: Date(timeIntervalSince1970: 1), type: "CartError", message: "cart empty", stacktrace: nil, fatal: true, attributes: ["session.id": "s1"]),
            .event(timestamp: Date(timeIntervalSince1970: 1), name: "checkout_started", attributes: ["items": 3]),
        ])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let logs = try XCTUnwrap((json["resourceLogs"] as? [[String: Any]])?.first)
        XCTAssertEqual(((logs["resource"] as? [String: Any])?["attributes"] as? [Any])?.count, 1)
        let records = try XCTUnwrap(((logs["scopeLogs"] as? [[String: Any]])?.first?["logRecords"]) as? [[String: Any]])
        XCTAssertEqual(records[0]["severityNumber"] as? Int, 21)
        XCTAssertEqual(records[0]["timeUnixNano"] as? String, "1000000000")
        XCTAssertEqual(records[1]["eventName"] as? String, "checkout_started")
    }
}
