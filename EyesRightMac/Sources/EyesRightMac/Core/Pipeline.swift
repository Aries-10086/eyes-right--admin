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
            return "找不到检测模型文件"
        case .overlayNotFound:
            return "找不到贴图素材"
        case .cannotReadImage(let name):
            return "无法读取图片：\(name)"
        case .preprocessFailed:
            return "图片预处理失败"
        case .inferenceFailed:
            return "模型推理失败"
        case .noFaceDetected:
            return "未检测到脸或眼点，请换更清晰的正脸照片"
        }
    }
}

final class EyePipeline: @unchecked Sendable {
    private let detector: PoseDetector
    private let animeDetector: AnimeEyeDetector
    private let noseDetector: NosePoseDetector
    private let dualOverlay: CGImage
    private let guangOverlay: CGImage
    private let clownNoseOverlay: CGImage

    init() throws {
        detector = try PoseDetector()
        animeDetector = try AnimeEyeDetector()
        noseDetector = try NosePoseDetector()
        dualOverlay = try EyeOverlay.loadOverlayImage()
        guangOverlay = try EyeOverlay.loadGuangOverlayImage()
        clownNoseOverlay = try EyeOverlay.loadClownNoseImage()
    }

    func processImage(
        at url: URL,
        mode: OverlayMode = .ahAhAh,
        faceKind: FaceKind = .pet
    ) throws -> CGImage {
        let source = try ImageProcessor.loadCGImage(from: url)
        let pairs: [EyePair]
        if faceKind.usesAnimeDetector {
            pairs = try animeDetector.detect(in: source)
        } else {
            pairs = try detector.detect(in: source)
        }
        guard let raw = pairs.first else {
            throw PipelineError.noFaceDetected
        }
        let pair = (mode == .clownNose) ? noseDetector.refine(raw, in: source) : raw

        let result: CGImage?
        switch mode {
        case .ahAhAh:
            result = EyeOverlay.apply(to: source, overlay: dualOverlay, pair: pair)
        case .addLight:
            result = EyeOverlay.applyPerEye(
                to: source,
                sticker: guangOverlay,
                pair: pair,
                mirrorRight: false
            )
        case .clownNose:
            result = EyeOverlay.applyClownNose(
                to: source,
                sticker: clownNoseOverlay,
                pair: pair
            )
        }

        guard let result else {
            throw PipelineError.preprocessFailed
        }
        return result
    }
}
