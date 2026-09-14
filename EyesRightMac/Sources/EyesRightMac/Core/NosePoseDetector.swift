import CoreGraphics
import Foundation
import OnnxRuntimeBindings

/// 专用鼻尖检测：RTMPose-AP10K（猫狗）+ 猫脸 9 点模型加权；失败回退 NoseRefiner。
final class NosePoseDetector: @unchecked Sendable {
    private let rtmSession: ORTSession
    private let catSession: ORTSession?
    private let env: ORTEnv

    private static let rtmSize = 256
    private static let catSize = 224
    private static let simccSplit: Float = 2
    /// AP10K：0 左眼 1 右眼 2 鼻子
    private static let rtmNoseIndex = 2

    init() throws {
        env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()

        guard let rtmURL = AppResources.url(forResource: "pet_nose_rtmpose", withExtension: "onnx") else {
            throw PipelineError.modelNotFound
        }
        rtmSession = try ORTSession(env: env, modelPath: rtmURL.path, sessionOptions: options)

        if let catURL = AppResources.url(forResource: "cat_landmark_model", withExtension: "onnx") {
            catSession = try? ORTSession(env: env, modelPath: catURL.path, sessionOptions: options)
        } else {
            catSession = nil
        }
    }

    /// 用已有眼点裁脸，跑专用鼻模，写回 `EyePair.nose`
    func refine(_ pair: EyePair, in image: CGImage) -> EyePair {
        let mid = CGPoint(x: (pair.left.x + pair.right.x) / 2, y: (pair.left.y + pair.right.y) / 2)
        let dx = pair.right.x - pair.left.x
        let dy = pair.right.y - pair.left.y
        let inter = max(hypot(dx, dy), 1e-6)
        let eyeDir = CGVector(dx: dx / inter, dy: dy / inter)
        let down = faceDown(pair: pair, eyeDir: eyeDir, inter: inter)

        var candidates: [(point: CGPoint, score: CGFloat, source: String)] = []

        if let rtm = try? runRTMPose(image: image, pair: pair, down: down, inter: inter) {
            candidates.append(rtm)
        }
        if let cat = try? runCatLandmark(image: image, mid: mid, down: down, eyeDir: eyeDir, inter: inter) {
            candidates.append(cat)
        }

        let chosen: CGPoint
        if let best = pickBest(candidates: candidates, mid: mid, down: down, eyeDir: eyeDir, inter: inter) {
            chosen = best
        } else {
            // 几何 + 颜色回退
            chosen = NoseRefiner.refine(pair, in: image).nose
        }

        // 最终仍钳制在中线附近，避免贴到脸颊
        let clamped = clampToMidline(chosen, mid: mid, down: down, eyeDir: eyeDir, inter: inter)
        return EyePair(
            left: pair.left,
            right: pair.right,
            nose: clamped,
            confidence: pair.confidence,
            boxWidth: pair.boxWidth
        )
    }

    // MARK: - RTMPose AP10K

    private func runRTMPose(
        image: CGImage,
        pair: EyePair,
        down: CGVector,
        inter: CGFloat
    ) throws -> (point: CGPoint, score: CGFloat, source: String)? {
        let box = faceBox(pair: pair, imageWidth: image.width, imageHeight: image.height)
        guard let tensor = try cropNormalizedTensor(
            image: image,
            box: box,
            size: Self.rtmSize,
            mean: (123.675, 116.28, 103.53),
            std: (58.395, 57.12, 57.375)
        ) else { return nil }

        let input = try ORTValue(
            tensorData: NSMutableData(data: Data(bytes: tensor, count: tensor.count * 4)),
            elementType: .float,
            shape: [1, 3, NSNumber(value: Self.rtmSize), NSNumber(value: Self.rtmSize)]
        )
        let outputs = try rtmSession.run(
            withInputs: ["input": input],
            outputNames: ["simcc_x", "simcc_y"],
            runOptions: nil
        )
        guard let sxVal = outputs["simcc_x"], let syVal = outputs["simcc_y"],
              let sxData = try sxVal.tensorData() as Data?,
              let syData = try syVal.tensorData() as Data?
        else { return nil }

        let sx = sxData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let sy = syData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        // shapes: [1, 17, 512]
        let kpts = 17
        let bins = 512
        guard sx.count >= kpts * bins, sy.count >= kpts * bins else { return nil }

        let idx = Self.rtmNoseIndex
        var bestX = 0
        var bestY = 0
        var maxX: Float = -Float.greatestFiniteMagnitude
        var maxY: Float = -Float.greatestFiniteMagnitude
        for b in 0..<bins {
            let vx = sx[idx * bins + b]
            let vy = sy[idx * bins + b]
            if vx > maxX { maxX = vx; bestX = b }
            if vy > maxY { maxY = vy; bestY = b }
        }
        let score = CGFloat(min(maxX, maxY))
        guard score > 0.05 else { return nil }

        let lx = CGFloat(Float(bestX) / Self.simccSplit)
        let ly = CGFloat(Float(bestY) / Self.simccSplit)
        let x = box.minX + lx / CGFloat(Self.rtmSize) * box.width
        let y = box.minY + ly / CGFloat(Self.rtmSize) * box.height
        return (CGPoint(x: x, y: y), score, "rtm")
    }

    // MARK: - Cat 9-point landmark (p2 ≈ nose tip on clear faces)

    private func runCatLandmark(
        image: CGImage,
        mid: CGPoint,
        down: CGVector,
        eyeDir: CGVector,
        inter: CGFloat
    ) throws -> (point: CGPoint, score: CGFloat, source: String)? {
        guard let catSession else { return nil }
        guard let tensor = try fullImageTensor01(image: image, size: Self.catSize) else { return nil }
        let input = try ORTValue(
            tensorData: NSMutableData(data: Data(bytes: tensor, count: tensor.count * 4)),
            elementType: .float,
            shape: [1, 3, NSNumber(value: Self.catSize), NSNumber(value: Self.catSize)]
        )
        let outputs = try catSession.run(
            withInputs: ["input": input],
            outputNames: ["output"],
            runOptions: nil
        )
        guard let outVal = outputs["output"],
              let outData = try outVal.tensorData() as Data?
        else { return nil }
        let floats = outData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        guard floats.count >= 6 else { return nil }

        let w = CGFloat(image.width)
        let h = CGFloat(image.height)
        // output normalized 0~1
        let p2 = CGPoint(x: CGFloat(floats[4]) * w, y: CGFloat(floats[5]) * h)
        // 粗置信度：落在眼下中线带则高
        let along = (p2.x - mid.x) * down.dx + (p2.y - mid.y) * down.dy
        let across = (p2.x - mid.x) * eyeDir.dx + (p2.y - mid.y) * eyeDir.dy
        guard along > 0.15 * inter, along < 1.15 * inter, abs(across) < 0.35 * inter else {
            return nil
        }
        let score = CGFloat(1.0 - abs(across) / (0.35 * inter)) * 0.9
        return (p2, score, "cat")
    }

    // MARK: - Helpers

    private func faceDown(pair: EyePair, eyeDir: CGVector, inter: CGFloat) -> CGVector {
        let mid = CGPoint(x: (pair.left.x + pair.right.x) / 2, y: (pair.left.y + pair.right.y) / 2)
        let toModel = CGVector(dx: pair.nose.x - mid.x, dy: pair.nose.y - mid.y)
        let lat = toModel.dx * eyeDir.dx + toModel.dy * eyeDir.dy
        let orth = CGVector(dx: toModel.dx - eyeDir.dx * lat, dy: toModel.dy - eyeDir.dy * lat)
        let olen = hypot(orth.dx, orth.dy)
        if olen > 1e-3 {
            return CGVector(dx: -orth.dx / olen, dy: -orth.dy / olen)
        }
        var n = CGVector(dx: -eyeDir.dy, dy: eyeDir.dx)
        if n.dy < 0 { n = CGVector(dx: -n.dx, dy: -n.dy) }
        return n
    }

    private func faceBox(pair: EyePair, imageWidth: Int, imageHeight: Int) -> CGRect {
        let mid = CGPoint(x: (pair.left.x + pair.right.x) / 2, y: (pair.left.y + pair.right.y) / 2)
        let inter = max(hypot(pair.right.x - pair.left.x, pair.right.y - pair.left.y), 1)
        let face = max(pair.boxWidth, inter * 2.6) * 1.35
        let dx = pair.right.x - pair.left.x
        let dy = pair.right.y - pair.left.y
        let eyeDir = CGVector(dx: dx / inter, dy: dy / inter)
        let down = faceDown(pair: pair, eyeDir: eyeDir, inter: inter)
        // 中心略向下，覆盖鼻口
        let center = CGPoint(x: mid.x + down.dx * inter * 0.35, y: mid.y + down.dy * inter * 0.35)
        var x1 = center.x - face / 2
        var y1 = center.y - face / 2
        var x2 = center.x + face / 2
        var y2 = center.y + face / 2
        x1 = max(0, x1); y1 = max(0, y1)
        x2 = min(CGFloat(imageWidth - 1), x2)
        y2 = min(CGFloat(imageHeight - 1), y2)
        return CGRect(x: x1, y: y1, width: max(1, x2 - x1), height: max(1, y2 - y1))
    }

    private func pickBest(
        candidates: [(point: CGPoint, score: CGFloat, source: String)],
        mid: CGPoint,
        down: CGVector,
        eyeDir: CGVector,
        inter: CGFloat
    ) -> CGPoint? {
        guard !candidates.isEmpty else { return nil }
        var best: (point: CGPoint, score: CGFloat)?
        for c in candidates {
            let along = (c.point.x - mid.x) * down.dx + (c.point.y - mid.y) * down.dy
            let across = (c.point.x - mid.x) * eyeDir.dx + (c.point.y - mid.y) * eyeDir.dy
            guard along > 0.12 * inter, along < 1.2 * inter else { continue }
            guard abs(across) < 0.32 * inter else { continue }
            // 猫脸模型在清晰正脸上更贴鼻头，略加权
            let sourceBoost: CGFloat = c.source == "cat" ? 1.15 : 1.0
            let midline = max(0, 1 - abs(across) / (0.32 * inter))
            let total = c.score * sourceBoost * (0.55 + 0.45 * midline)
            if best == nil || total > best!.score {
                best = (c.point, total)
            }
        }
        return best?.point
    }

    private func clampToMidline(
        _ point: CGPoint,
        mid: CGPoint,
        down: CGVector,
        eyeDir: CGVector,
        inter: CGFloat
    ) -> CGPoint {
        let along = (point.x - mid.x) * down.dx + (point.y - mid.y) * down.dy
        var across = (point.x - mid.x) * eyeDir.dx + (point.y - mid.y) * eyeDir.dy
        let maxAcross = 0.10 * inter
        across = min(max(across, -maxAcross), maxAcross)
        let depth = min(max(along, 0.28 * inter), 1.05 * inter)
        return CGPoint(
            x: mid.x + down.dx * depth + eyeDir.dx * across,
            y: mid.y + down.dy * depth + eyeDir.dy * across
        )
    }

    private func cropNormalizedTensor(
        image: CGImage,
        box: CGRect,
        size: Int,
        mean: (Float, Float, Float),
        std: (Float, Float, Float)
    ) throws -> [Float]? {
        guard let cropped = image.cropping(to: CGRect(
            x: box.minX.rounded(.down),
            y: box.minY.rounded(.down),
            width: box.width.rounded(.up),
            height: box.height.rounded(.up)
        )) else { return nil }

        let bytesPerRow = size * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * size)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buffer,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        // 顶左缓冲（与关键点一致）
        ctx.translateBy(x: 0, y: CGFloat(size))
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: size, height: size))

        var tensor = [Float](repeating: 0, count: 3 * size * size)
        for y in 0..<size {
            for x in 0..<size {
                let o = y * bytesPerRow + x * 4
                let plane = y * size + x
                tensor[plane] = (Float(buffer[o]) - mean.0) / std.0
                tensor[size * size + plane] = (Float(buffer[o + 1]) - mean.1) / std.1
                tensor[2 * size * size + plane] = (Float(buffer[o + 2]) - mean.2) / std.2
            }
        }
        return tensor
    }

    private func fullImageTensor01(image: CGImage, size: Int) throws -> [Float]? {
        let bytesPerRow = size * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * size)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buffer,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(size))
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        var tensor = [Float](repeating: 0, count: 3 * size * size)
        for y in 0..<size {
            for x in 0..<size {
                let o = y * bytesPerRow + x * 4
                let plane = y * size + x
                tensor[plane] = Float(buffer[o]) / 255
                tensor[size * size + plane] = Float(buffer[o + 1]) / 255
                tensor[2 * size * size + plane] = Float(buffer[o + 2]) / 255
            }
        }
        return tensor
    }
}
