import CoreGraphics

struct EyePair: Sendable {
    let left: CGPoint
    let right: CGPoint
    let confidence: Float
    let boxWidth: CGFloat
}

enum OverlayMode: String, CaseIterable, Identifiable, Sendable {
    /// Original dual-eye cutout sticker
    case ahAhAh = "啊啊啊"
    /// Same image pasted on each eye (right eye not mirrored)
    case addLight = "加一道光"

    var id: String { rawValue }
}

enum OverlayConstants {
    static let leftEye = CGPoint(x: 200, y: 220)
    static let rightEye = CGPoint(x: 671, y: 228)
    static let totalWidth: CGFloat = 863
    static let coverage: CGFloat = 0.72
    static let confThreshold: Float = 0.15

    /// 「加一道光」：贴纸中心到两眼中点的半跨距 ≥ 脸宽 × 该比例（检测点偏近时仍能拉开）
    static let perEyeHalfSpanFromBox: CGFloat = 0.20
    /// 在半跨距上再外推一点，避免贴在鼻梁
    static let perEyeSpreadBoost: CGFloat = 1.12
    /// 单张贴纸宽度相对「半跨距」的比例，用于盖住单眼
    static let perEyeCoverRatio: CGFloat = 1.05
    /// 贴纸宽度上限，避免两张在中间严重重叠（相对半跨距）
    static let perEyeMaxWidthByHalfSpan: CGFloat = 1.35
}
