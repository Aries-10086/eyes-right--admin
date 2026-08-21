import CoreGraphics
import Foundation

enum PipelineError: LocalizedError {
    case modelNotFound
    case overlayNotFound
    case cannotReadImage(String)
    case preprocessFailed
    case inferenceFailed
    case noFaceDetected

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "找不到模型 pet_eye_best.onnx"
        case .overlayNotFound:
            return "找不到贴图素材"
        case .cannotReadImage(let name):
            return "无法读取图片：\(name)"
        case .preprocessFailed:
            return "图片预处理失败"
        case .inferenceFailed:
            return "模型推理失败"
        case .noFaceDetected:
            return "未检测到猫/狗脸或眼点，请换更清晰正脸照片"
        }
    }
}

final class EyePipeline: @unchecked Sendable {
    private let detector: PoseDetector
    private let dualOverlay: CGImage
    private let guangOverlay: CGImage

    init() throws {
        detector = try PoseDetector()
        dualOverlay = try EyeOverlay.loadOverlayImage()
        guangOverlay = try EyeOverlay.loadGuangOverlayImage()
    }

    func processImage(at url: URL, mode: OverlayMode = .ahAhAh) throws -> CGImage {
        let source = try ImageProcessor.loadCGImage(from: url)
        let pairs = try detector.detect(in: source)
        guard let pair = pairs.first else {
            throw PipelineError.noFaceDetected
        }

        let result: CGImage?
        switch mode {
        case .ahAhAh:
            result = EyeOverlay.apply(to: source, overlay: dualOverlay, pair: pair)
        case .addLight:
            // 右眼不镜像
            result = EyeOverlay.applyPerEye(
                to: source,
                sticker: guangOverlay,
                pair: pair,
                mirrorRight: false
            )
        }

        guard let result else {
            throw PipelineError.preprocessFailed
        }
        return result
    }
}
