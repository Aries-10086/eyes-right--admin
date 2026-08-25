import AppKit
import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

protocol RegionCaptureSessionDelegate: AnyObject {
    func regionCaptureSession(_ session: RegionCaptureSession, didOutput image: CGImage)
    func regionCaptureSession(_ session: RegionCaptureSession, didFail error: Error)
}

/// ScreenCaptureKit 区域连续采帧
final class RegionCaptureSession: NSObject, SCStreamOutput, SCStreamDelegate {
    weak var delegate: RegionCaptureSessionDelegate?

    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "com.eyesright.region-capture", qos: .userInitiated)
    private(set) var region: ScreenRegion
    private var targetFPS: Int

    init(region: ScreenRegion, fps: Int = 12) {
        self.region = region
        self.targetFPS = max(5, min(fps, 20))
        super.init()
    }

    func start() async throws {
        await stop()

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == region.displayID })
                ?? content.displays.first
        else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let source = region.sourceRectInDisplay
        let pixelW = max(2, Int((source.width * region.backingScaleFactor).rounded()))
        let pixelH = max(2, Int((source.height * region.backingScaleFactor).rounded()))
        config.width = pixelW
        config.height = pixelH
        config.sourceRect = source
        config.scalesToFit = false
        config.showsCursor = false
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
        if #available(macOS 14.0, *) {
            config.captureResolution = .best
        }

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
    }

    func updateFPS(_ fps: Int) {
        targetFPS = max(5, min(fps, 20))
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferIsValid(sampleBuffer),
              let pixelBuffer = sampleBuffer.imageBuffer,
              let image = Self.makeCGImage(from: pixelBuffer)
        else {
            return
        }
        delegate?.regionCaptureSession(self, didOutput: image)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        delegate?.regionCaptureSession(self, didFail: error)
    }

    private static func makeCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ),
        let image = context.makeImage()
        else {
            return nil
        }
        // Screen buffers are often upside-down relative to our detector (top-left). Flip once.
        return ImageProcessor.flipVertically(image) ?? image
    }
}

enum CaptureError: LocalizedError {
    case noDisplay
    case regionTooSmall
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "找不到可用于采集的显示器"
        case .regionTooSmall:
            return "选区太小，请框选至少 80×80 的区域"
        case .permissionDenied:
            return """
            屏幕录制仍被系统拒绝（设置里开关开着也可能无效）。请：① 完全退出 Eyes Right；② 系统设置 → 录屏 → 删掉旧的 Eyes Right 再重新打开开关；③ 重新打开 App。若反复失败，当前包多为 ad-hoc 签名，新系统要求用 Apple 开发证书重签后才能真正授权。
            """
            .replacingOccurrences(of: "\n", with: "")
        }
    }
}
