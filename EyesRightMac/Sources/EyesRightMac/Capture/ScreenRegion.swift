import AppKit
import CoreGraphics
import Foundation

/// 用户在屏幕上框选的采集区域（Cocoa 全局坐标，原点在左下）
struct ScreenRegion: Equatable, Sendable {
    var frame: CGRect
    var displayID: CGDirectDisplayID
    var backingScaleFactor: CGFloat

    var isValid: Bool {
        frame.width >= 80 && frame.height >= 80
    }

    /// ScreenCaptureKit sourceRect：相对该显示器，原点在左上
    var sourceRectInDisplay: CGRect {
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }) else {
            return CGRect(origin: .zero, size: frame.size)
        }
        let local = CGRect(
            x: frame.minX - screen.frame.minX,
            y: frame.minY - screen.frame.minY,
            width: frame.width,
            height: frame.height
        )
        return CGRect(
            x: local.minX,
            y: screen.frame.height - local.maxY,
            width: local.width,
            height: local.height
        )
    }

    var pixelSize: CGSize {
        CGSize(
            width: (frame.width * backingScaleFactor).rounded(),
            height: (frame.height * backingScaleFactor).rounded()
        )
    }
}

enum ScreenRegionGeometry {
    static func screenContaining(_ point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }

    static func makeRegion(globalRect: CGRect) -> ScreenRegion? {
        let center = CGPoint(x: globalRect.midX, y: globalRect.midY)
        guard let screen = screenContaining(center) else { return nil }
        let clamped = globalRect.intersection(screen.frame)
        guard !clamped.isNull, clamped.width >= 80, clamped.height >= 80 else { return nil }
        return ScreenRegion(
            frame: clamped,
            displayID: displayID(of: screen),
            backingScaleFactor: screen.backingScaleFactor
        )
    }
}
