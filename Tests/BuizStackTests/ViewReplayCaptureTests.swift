import SwiftUI
import UIKit
import XCTest

@testable import BuizStack

@MainActor
final class ViewReplayCaptureTests: XCTestCase {
    func testRecordsAMaskedMp4OfUIKitAndSwiftUIContent() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        root.view.backgroundColor = .systemYellow
        let label = UILabel(frame: CGRect(x: 40, y: 120, width: 310, height: 40))
        label.text = "Visible static text"
        let email = UITextField(frame: CGRect(x: 40, y: 180, width: 310, height: 44))
        email.text = "ada@lovelace.dev"
        email.backgroundColor = .white
        let password = UITextField(frame: CGRect(x: 40, y: 240, width: 310, height: 44))
        password.text = "hunter2"
        password.isSecureTextEntry = true
        password.backgroundColor = .white
        let image = UIImageView(frame: CGRect(x: 40, y: 300, width: 80, height: 80))
        image.image = UIImage(systemName: "map.fill")
        let hosting = UIHostingController(rootView: VStack {
            Text("SwiftUI visible")
            Text("SwiftUI secret").buizStackReplayMask()
        })
        hosting.view.frame = CGRect(x: 40, y: 400, width: 310, height: 100)
        hosting.view.backgroundColor = .systemTeal
        root.addChild(hosting)
        [label, email, password, image, hosting.view].forEach { root.view.addSubview($0) }
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        let masks = try XCTUnwrap(ReplayMasks.collect(in: window, options: ReplayOptions()))
        print("BUIZSTACK_MASKS \(masks)")
        XCTAssertEqual(masks.count, 4)

        let capture = ViewReplayCapture(window: { window }, isActive: { true })
        capture.startSegment(options: ReplayOptions())
        RunLoop.main.run(until: Date().addingTimeInterval(3.5))
        let video = try XCTUnwrap(capture.endSegment())

        XCTAssertEqual(String(decoding: video.data[4..<8], as: UTF8.self), "ftyp")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("buizstack_ios_probe.mp4")
        try video.data.write(to: url)
        let snapshots = capture.snapshotTimes.map { $0 * 1000 }
        let collects = capture.collectTimes.map { $0 * 1000 }
        print("BUIZSTACK_IOS_TIMINGS snapshot_ms=\(snapshots) collect_ms=\(collects)")
        XCTAssertLessThan(collects.max() ?? 0, 2)
        print("BUIZSTACK_IOS_VIDEO \(url.path) \(video.data.count) \(video.width)x\(video.height)")
    }
}
