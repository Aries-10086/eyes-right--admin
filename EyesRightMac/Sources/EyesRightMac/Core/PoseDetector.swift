import CoreGraphics
import Foundation
import OnnxRuntimeBindings

final class PoseDetector: @unchecked Sendable {
    private let session: ORTSession

    init() throws {
        guard let modelURL = AppResources.url(forResource: "pet_eye_best", withExtension: "onnx") else {
            throw PipelineError.modelNotFound
        }
        let env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        session = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)
    }

    func detect(in image: CGImage, confThreshold: Float = OverlayConstants.confThreshold) throws -> [EyePair] {
        let letterbox = try ImageProcessor.letterbox(image)
        let inputShape: [NSNumber] = [1, 3, 640, 640]
        let inputData = Data(bytes: letterbox.tensor, count: letterbox.tensor.count * MemoryLayout<Float>.size)
        let inputTensor = try ORTValue(
            tensorData: NSMutableData(data: inputData),
            elementType: .float,
            shape: inputShape
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

        let count = 8400
        let floats = outputData.withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: Float.self))
        }

        var candidates: [(score: Float, cx: Float, cy: Float, w: Float, kpts: [(CGPoint, Float)])] = []

        for index in 0..<count {
            func value(_ channel: Int) -> Float {
                floats[channel * count + index]
            }

            let score = value(4)
            guard score >= confThreshold else { continue }

            let cx = value(0)
            let cy = value(1)
            let boxW = value(2)

            var keypoints: [(CGPoint, Float)] = []
            for kptIndex in 0..<3 {
                let channel = 5 + kptIndex * 3
                let point = CGPoint(x: CGFloat(value(channel)), y: CGFloat(value(channel + 1)))
                let mapped = ImageProcessor.mapPointToOriginal(point, letterbox: letterbox)
                keypoints.append((mapped, value(channel + 2)))
            }

            candidates.append((score, cx, cy, boxW, keypoints))
        }

        candidates.sort { $0.score > $1.score }
        guard let best = candidates.first else { return [] }

        var left = best.kpts[0].0
        var right = best.kpts[1].0
        if left.x > right.x {
            swap(&left, &right)
        }

        let interEye = hypot(right.x - left.x, right.y - left.y)
        let mid = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        // 两眼连线的法向（图像顶左，y 向下）；模型缺鼻点时给一个「额头侧」先验供 NoseRefiner 反射
        let nx = -(right.y - left.y) / max(interEye, 1e-6)
        let ny = (right.x - left.x) / max(interEye, 1e-6)
        let foreheadCue = CGPoint(
            x: mid.x - nx * interEye * 0.45,
            y: mid.y - ny * interEye * 0.45
        )
        // 始终保留原始 kpt2（即便偏到额头）；由 NoseRefiner 校正到鼻头
        let nose = (best.kpts.count > 2 && best.kpts[2].1 >= OverlayConstants.noseConfThreshold)
            ? best.kpts[2].0
            : foreheadCue

        let kptConf = min(best.kpts[0].1, best.kpts[1].1)
        let boxWidth = CGFloat(best.w / letterbox.scale)

        return [
            EyePair(
                left: left,
                right: right,
                nose: nose,
                confidence: min(best.score, kptConf),
                boxWidth: boxWidth
            ),
        ]
    }
}
