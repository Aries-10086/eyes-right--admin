import CoreGraphics
import Foundation
import OnnxRuntimeBindings

/// 动漫脸检测（adetailer face_yolov8n）→ 眼点定位 → 供贴图使用。
final class AnimeEyeDetector: @unchecked Sendable {
    private let session: ORTSession
    private static let inputSize = 640
    private static let anchors = 8400

    init() throws {
        guard let modelURL = AppResources.url(forResource: "anime_face_yolov8n", withExtension: "onnx") else {
            throw PipelineError.modelNotFound
        }
        let env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        session = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)
    }

    func detect(in image: CGImage, confThreshold: Float = 0.25) throws -> [EyePair] {
        let letterbox = try ImageProcessor.letterbox(image, targetSize: Self.inputSize)
        let inputData = Data(bytes: letterbox.tensor, count: letterbox.tensor.count * MemoryLayout<Float>.size)
        let inputTensor = try ORTValue(
            tensorData: NSMutableData(data: inputData),
            elementType: .float,
            shape: [1, 3, NSNumber(value: Self.inputSize), NSNumber(value: Self.inputSize)]
        )

        let outputs = try session.run(
            withInputs: ["images": inputTensor],
            outputNames: ["output0"],
            runOptions: nil
        )
        guard let outputTensor = outputs["output0"],
              let outputData = try outputTensor.tensorData() as Data?
        else {
            throw PipelineError.inferenceFailed
        }

        let floats = outputData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        // YOLOv8 single-class face: (1, 5, 8400) → channel-major
        let count = Self.anchors
        guard floats.count >= 5 * count else { return [] }

        func value(_ channel: Int, _ index: Int) -> Float {
            floats[channel * count + index]
        }

        var boxes: [(score: Float, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)] = []
        for i in 0..<count {
            let score = value(4, i)
            guard score >= confThreshold else { continue }
            let cx = value(0, i)
            let cy = value(1, i)
            let bw = value(2, i)
            let bh = value(3, i)
            let x1 = CGFloat((cx - bw / 2 - letterbox.padLeft) / letterbox.scale)
            let y1 = CGFloat((cy - bh / 2 - letterbox.padTop) / letterbox.scale)
            let x2 = CGFloat((cx + bw / 2 - letterbox.padLeft) / letterbox.scale)
            let y2 = CGFloat((cy + bh / 2 - letterbox.padTop) / letterbox.scale)
            boxes.append((score, x1, y1, x2, y2))
        }

        boxes.sort { $0.score > $1.score }
        let kept = nms(boxes, iouThreshold: 0.45)
        guard let best = kept.first else { return [] }

        let pixels = RGBAImage(image)
        let pair = localizeEyes(
            face: best,
            imageWidth: image.width,
            imageHeight: image.height,
            pixels: pixels
        )
        return [pair]
    }

    private func nms(
        _ boxes: [(score: Float, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)],
        iouThreshold: CGFloat
    ) -> [(score: Float, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)] {
        var remaining = boxes
        var kept: [(score: Float, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)] = []
        while !remaining.isEmpty {
            let cur = remaining.removeFirst()
            kept.append(cur)
            remaining = remaining.filter { other in
                iou(cur, other) < iouThreshold
            }
        }
        return kept
    }

    private func iou(
        _ a: (score: Float, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat),
        _ b: (score: Float, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)
    ) -> CGFloat {
        let x1 = max(a.x1, b.x1)
        let y1 = max(a.y1, b.y1)
        let x2 = min(a.x2, b.x2)
        let y2 = min(a.y2, b.y2)
        let inter = max(0, x2 - x1) * max(0, y2 - y1)
        let areaA = max(0, a.x2 - a.x1) * max(0, a.y2 - a.y1)
        let areaB = max(0, b.x2 - b.x1) * max(0, b.y2 - b.y1)
        return inter / (areaA + areaB - inter + 1e-6)
    }

    /// 动漫脸比例先验 + ROI 内暗点/对比细化
    private func localizeEyes(
        face: (score: Float, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat),
        imageWidth: Int,
        imageHeight: Int,
        pixels: RGBAImage?
    ) -> EyePair {
        let x1 = max(0, face.x1)
        let y1 = max(0, face.y1)
        let x2 = min(CGFloat(imageWidth - 1), face.x2)
        let y2 = min(CGFloat(imageHeight - 1), face.y2)
        let fw = max(1, x2 - x1)
        let fh = max(1, y2 - y1)

        // 动漫脸：眼睛约在脸高 36%~40%、左右约 30%/70%
        var left = CGPoint(x: x1 + fw * 0.30, y: y1 + fh * 0.38)
        var right = CGPoint(x: x1 + fw * 0.70, y: y1 + fh * 0.38)

        if let pixels {
            left = refineEyeCenter(
                seed: left,
                roi: CGRect(
                    x: x1 + fw * 0.12,
                    y: y1 + fh * 0.22,
                    width: fw * 0.38,
                    height: fh * 0.32
                ),
                pixels: pixels
            )
            right = refineEyeCenter(
                seed: right,
                roi: CGRect(
                    x: x1 + fw * 0.50,
                    y: y1 + fh * 0.22,
                    width: fw * 0.38,
                    height: fh * 0.32
                ),
                pixels: pixels
            )
        }

        if left.x > right.x { swap(&left, &right) }

        let inter = hypot(right.x - left.x, right.y - left.y)
        let mid = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        let nose = CGPoint(x: mid.x, y: mid.y + inter * 0.55)

        return EyePair(
            left: left,
            right: right,
            nose: nose,
            confidence: face.score,
            boxWidth: fw
        )
    }

    /// 在眼眶 ROI 内找偏暗且有对比的中心（适配动漫大眼瞳孔）
    private func refineEyeCenter(seed: CGPoint, roi: CGRect, pixels: RGBAImage) -> CGPoint {
        let x0 = max(0, Int(floor(roi.minX)))
        let y0 = max(0, Int(floor(roi.minY)))
        let x1 = min(pixels.width - 1, Int(ceil(roi.maxX)))
        let y1 = min(pixels.height - 1, Int(ceil(roi.maxY)))
        guard x1 > x0, y1 > y0 else { return seed }

        var luminances: [Float] = []
        luminances.reserveCapacity((x1 - x0 + 1) * (y1 - y0 + 1))
        for y in y0...y1 {
            for x in x0...x1 {
                let (r, g, b) = pixels.rgb(x: x, y: y)
                luminances.append(0.299 * r + 0.587 * g + 0.114 * b)
            }
        }
        let sorted = luminances.sorted()
        let thr = sorted[max(0, Int(Float(sorted.count) * 0.18))]

        var wsum: Float = 0
        var sx: Float = 0
        var sy: Float = 0
        var idx = 0
        for y in y0...y1 {
            for x in x0...x1 {
                let lum = luminances[idx]
                idx += 1
                guard lum <= thr else { continue }
                let weight = max(1, thr - lum + 1)
                wsum += weight
                sx += weight * Float(x)
                sy += weight * Float(y)
            }
        }
        guard wsum > 0 else { return seed }
        let refined = CGPoint(x: CGFloat(sx / wsum), y: CGFloat(sy / wsum))
        // 与先验混合，避免贴到眉毛/刘海
        return CGPoint(x: refined.x * 0.65 + seed.x * 0.35, y: refined.y * 0.65 + seed.y * 0.35)
    }
}

/// 与 NoseRefiner 相同的顶左 RGBA 采样
private struct RGBAImage {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let data: [UInt8]

    init?(_ image: CGImage) {
        width = image.width
        height = image.height
        bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = buffer
    }

    func rgb(x: Int, y: Int) -> (Float, Float, Float) {
        let i = y * bytesPerRow + x * 4
        return (Float(data[i]), Float(data[i + 1]), Float(data[i + 2]))
    }
}
