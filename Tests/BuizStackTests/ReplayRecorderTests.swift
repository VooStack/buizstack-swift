import XCTest

@testable import BuizStack

final class ReplayRecorderTests: XCTestCase {
    private let dsn = BuizStackDsn("https://key@ingest.buizstack.com/7a3bb8ce637c4e659defc96ebe324533")!
    private var now = Date(timeIntervalSince1970: 1_761_998_400)
    private var transport = FakeTransport()

    private final class Capture: ReplayCapture {
        var started = 0
        var options: ReplayOptions?

        func startSegment(options: ReplayOptions) {
            started += 1
            self.options = options
        }

        func endSegment() -> ReplayVideo? { ReplayVideo(data: Data([1, 2, 3]), contentType: "video/mp4", width: 360, height: 780) }

        func dispose() {}
    }

    private func recorder(sessionRate: Double, capture: ReplayCapture? = nil) -> ReplayRecorder {
        ReplayRecorder(
            options: ReplayOptions(sessionSampleRate: sessionRate, onErrorSampleRate: 1, segmentDuration: 3600),
            uploader: ReplayUploader(dsn: dsn, transport: transport) { ["environment": "production"] },
            replayId: "ab12cd34ef56ab12cd34ef56ab12cd34",
            capture: capture,
            clock: { [unowned self] in now },
            random: { 0.5 }
        )
    }

    private func advance(_ replay: ReplayRecorder, _ segments: Int) {
        for _ in 0..<segments {
            now = now.addingTimeInterval(10)
            replay.rotate()
        }
    }

    func testBuffersTheLastMinuteThenFlushesItInOrderOnError() {
        let replay = recorder(sessionRate: 0)
        replay.start()
        replay.add(.viewport(now, 360, 780))
        advance(replay, 9)
        XCTAssertEqual(replay.mode, .buffering)
        XCTAssertTrue(transport.uploads.isEmpty)
        XCTAssertEqual(replay.bufferedSegments, 7)

        replay.onError()

        XCTAssertEqual(replay.mode, .recording)
        XCTAssertEqual(transport.uploads.count, 7)
        XCTAssertTrue(transport.uploads[0].contains("\"segment\":2"))
        XCTAssertTrue(transport.uploads[0].contains("\"type\":\"buffer\""))
        advance(replay, 1)
        XCTAssertTrue(transport.uploads.last!.contains("\"errorCount\":1"))
        replay.stop()
    }

    func testSessionSamplingUploadsEverySegmentWithVideoAndCarriedScreen() {
        let capture = Capture()
        let replay = recorder(sessionRate: 1, capture: capture)
        replay.start()
        replay.add(.screen(now, "CheckoutViewController"))
        advance(replay, 1)
        replay.add(.tap(now, 10, 20))
        replay.stop()

        XCTAssertEqual(transport.uploads.count, 2)
        XCTAssertTrue(transport.uploads[1].contains("CheckoutViewController"))
        XCTAssertTrue(transport.uploads[1].contains("\"type\":\"tap\""))
        XCTAssertTrue(transport.uploads[1].contains("name=\"video\"; filename=\"segment.mp4\""))
        XCTAssertEqual(capture.started, 2)
    }

    func testTheKillSwitchAndAlwaysRecordRulesComeFromTheProject() {
        transport.config = #"{"enabled":false}"#
        let off = recorder(sessionRate: 1)
        off.start()
        XCTAssertEqual(off.mode, .off)

        transport.config = #"{"maskAllText":true,"fullRecordUserIds":["qa@voostack.com"]}"#
        let capture = Capture()
        let replay = recorder(sessionRate: 0, capture: capture)
        replay.start()
        XCTAssertEqual(replay.mode, .buffering)
        XCTAssertEqual(capture.options?.maskAllText, true)
        advance(replay, 2)
        replay.identify("qa@voostack.com")
        XCTAssertEqual(replay.mode, .recording)
        XCTAssertEqual(transport.uploads.count, 2)
        replay.stop()
    }
}
