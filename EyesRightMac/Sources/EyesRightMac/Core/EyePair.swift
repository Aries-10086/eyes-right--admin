import CoreGraphics

struct EyePair: Sendable {
    let left: CGPoint
    let right: CGPoint
    let confidence: Float
    let boxWidth: CGFloat
}

enum OverlayConstants {
    static let leftEye = CGPoint(x: 200, y: 220)
    static let rightEye = CGPoint(x: 671, y: 228)
    static let totalWidth: CGFloat = 863
    static let coverage: CGFloat = 0.72
    static let confThreshold: Float = 0.15
}
