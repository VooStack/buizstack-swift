import AVFoundation
import CoreGraphics
import CoreVideo

final class ReplayEncoder {
    let width: Int
    let height: Int
    private let output: URL
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private var lastTime: CMTime?
    private var frames = 0

    init(width: Int, height: Int, bitrate: Int, output: URL) throws {
        self.width = width
        self.height = height
        self.output = output
        writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: bitrate,
                    AVVideoMaxKeyFrameIntervalKey: 5,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                ],
            ]
        )
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        writer.add(input)
    }

    func frame(_ image: CGImage, masks: [CGRect], at date: Date) {
        let time = CMTime(value: Int64(date.timeIntervalSince1970 * 1000), timescale: 1000)
        if let last = lastTime, time <= last { return }
        if writer.status == .unknown {
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: time)
        }
        guard writer.status == .writing, input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let pixels = buffer else { return }
        CVPixelBufferLockBaseAddress(pixels, [])
        defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
        guard
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(pixels),
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixels),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            )
        else { return }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        for rect in masks {
            context.fill(CGRect(x: rect.minX, y: CGFloat(height) - rect.maxY, width: rect.width, height: rect.height))
        }
        if adaptor.append(pixels, withPresentationTime: time) {
            lastTime = time
            frames += 1
        }
    }

    func finish() -> Data? {
        guard writer.status == .writing, frames > 0 else {
            cancel()
            return nil
        }
        input.markAsFinished()
        if let last = lastTime { writer.endSession(atSourceTime: last + CMTime(value: 1, timescale: 1)) }
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        let data = writer.status == .completed ? try? Data(contentsOf: output) : nil
        try? FileManager.default.removeItem(at: output)
        return data
    }

    func cancel() {
        if writer.status == .writing { writer.cancelWriting() }
        try? FileManager.default.removeItem(at: output)
    }
}
