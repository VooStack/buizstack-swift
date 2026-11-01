import Foundation

final class HangWatchdog {
    private let timeout: TimeInterval
    private let onHang: () -> Void
    private var thread: Thread?
    private var running = true
    private var ticked = true

    init(timeout: TimeInterval = 5, onHang: @escaping () -> Void) {
        self.timeout = timeout
        self.onHang = onHang
    }

    func start() {
        let thread = Thread { [weak self] in self?.loop() }
        thread.name = "buizstack-hang"
        thread.qualityOfService = .utility
        self.thread = thread
        thread.start()
    }

    func stop() { running = false }

    private func loop() {
        var reported = false
        while running {
            ticked = false
            DispatchQueue.main.async { [weak self] in self?.ticked = true }
            Thread.sleep(forTimeInterval: timeout)
            if !ticked && !reported {
                reported = true
                onHang()
            } else if ticked {
                reported = false
            }
        }
    }
}
