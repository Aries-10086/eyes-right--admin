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
            return "找不到眼睛素材 PNG"
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
    private let overlayImage: CGImage

    init() throws {
        detector = try PoseDetector()
        overlayImage = try EyeOverlay.loadOverlayImage()
    }

    func processImage(at url: URL) throws -> CGImage {
        let source = try ImageProcessor.loadCGImage(from: url)
        let pairs = try detector.detect(in: source)
        guard let pair = pairs.first else {
            throw PipelineError.noFaceDetected
        }

        guard let result = EyeOverlay.apply(to: source, overlay: overlayImage, pair: pair) else {
            throw PipelineError.preprocessFailed
        }
        return result
    }
}
