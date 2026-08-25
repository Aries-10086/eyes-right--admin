import CoreGraphics
import Foundation

/// 帧调度：降频推理 + 时间平滑 + 丢失保持，减轻闪烁/抖动
final class LivePipeline: @unchecked Sendable {
    private let detector: PoseDetector
    private let dualOverlay: CGImage
    private let guangOverlay: CGImage

    private let lock = NSLock()
    private var isBusy = false
    private var lastPair: EyePair?
    private var missCount = 0
    private let maxMissHold = 6

    /// 新检测权重；越小越稳，越大跟手越快
    private let smoothAlpha: CGFloat = 0.28
    /// 相对脸宽的死区：小于此位移视为噪声，不更新
    private let deadzoneRatio: CGFloat = 0.014
    private let deadzoneMinPixels: CGFloat = 2.0
    /// 相对脸宽：超过此位移视为切镜/换目标，直接跳变
    private let snapRatio: CGFloat = 0.35

    var overlayMode: OverlayMode = .ahAhAh

    init() throws {
        detector = try PoseDetector()
        dualOverlay = try EyeOverlay.loadOverlayImage()
        guangOverlay = try EyeOverlay.loadGuangOverlayImage()
    }

    struct Output {
        let overlayImage: CGImage?
        let pair: EyePair?
        let detected: Bool
    }

    /// 若正忙则跳过本帧；返回是否受理
    func processFrame(_ image: CGImage, completion: @escaping (Output) -> Void) -> Bool {
        lock.lock()
        if isBusy {
            lock.unlock()
            return false
        }
        isBusy = true
        let mode = overlayMode
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async {
            let output = self.detectAndRender(image: image, mode: mode)
            self.lock.lock()
            self.isBusy = false
            self.lock.unlock()
            completion(output)
        }
        return true
    }

    private func detectAndRender(image: CGImage, mode: OverlayMode) -> Output {
        let pairs: [EyePair]
        do {
            pairs = try detector.detect(in: image)
        } catch {
            pairs = []
        }

        lock.lock()
        defer { lock.unlock() }

        if let raw = pairs.first {
            let pair = smooth(raw)
            lastPair = pair
            missCount = 0
            let overlay = EyeOverlay.renderOverlayOnly(
                canvasWidth: image.width,
                canvasHeight: image.height,
                mode: mode,
                pair: pair,
                dualOverlay: dualOverlay,
                guangOverlay: guangOverlay
            )
            return Output(overlayImage: overlay, pair: pair, detected: true)
        }

        missCount += 1
        if missCount <= maxMissHold, let pair = lastPair {
            let overlay = EyeOverlay.renderOverlayOnly(
                canvasWidth: image.width,
                canvasHeight: image.height,
                mode: mode,
                pair: pair,
                dualOverlay: dualOverlay,
                guangOverlay: guangOverlay
            )
            return Output(overlayImage: overlay, pair: pair, detected: false)
        }

        lastPair = nil
        return Output(overlayImage: nil, pair: nil, detected: false)
    }

    /// 死区压静态噪声 + EMA 跟动 + 大切换跳变
    private func smooth(_ new: EyePair) -> EyePair {
        guard let last = lastPair else { return new }

        let midLast = Self.midpoint(last)
        let midNew = Self.midpoint(new)
        let dist = hypot(midNew.x - midLast.x, midNew.y - midLast.y)
        let ref = max(last.boxWidth, new.boxWidth, 1)

        if dist > ref * snapRatio {
            return new
        }

        if dist < max(deadzoneMinPixels, ref * deadzoneRatio) {
            return EyePair(
                left: last.left,
                right: last.right,
                confidence: new.confidence,
                boxWidth: last.boxWidth
            )
        }

        let a = smoothAlpha
        return EyePair(
            left: Self.lerp(last.left, new.left, a),
            right: Self.lerp(last.right, new.right, a),
            confidence: new.confidence,
            boxWidth: last.boxWidth * (1 - a) + new.boxWidth * a
        )
    }

    private static func midpoint(_ pair: EyePair) -> CGPoint {
        CGPoint(x: (pair.left.x + pair.right.x) / 2, y: (pair.left.y + pair.right.y) / 2)
    }

    private static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    func reset() {
        lock.lock()
        lastPair = nil
        missCount = 0
        lock.unlock()
    }
}
