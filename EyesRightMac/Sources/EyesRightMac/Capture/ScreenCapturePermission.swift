import AppKit
import CoreGraphics
import Foundation

enum ScreenCapturePermission {
    /// 真实运行时权限（比「系统设置里开关看起来开着」更准）
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 弹出系统授权；首次授权后通常需要完全退出 App 再开才生效
    @discardableResult
    static func requestAccess() -> Bool {
        if isGranted { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static func isPermissionFailure(_ error: Error) -> Bool {
        if error is CaptureError {
            if case .permissionDenied = error as? CaptureError { return true }
        }
        let ns = error as NSError
        let text = (ns.localizedDescription + " " + (ns.localizedFailureReason ?? "")).lowercased()
        if text.contains("deny") || text.contains("not authorized") || text.contains("not permitted")
            || text.contains("permission") || text.contains("tcc") || text.contains("权限")
        {
            return true
        }
        // ScreenCaptureKit often uses domain/code patterns around user cancel / auth
        if ns.domain.lowercased().contains("screencapture") || ns.domain.contains("SCStream") {
            return ns.code == -3801 || ns.code == -3802 || ns.code == 1002 || ns.code == 1003
        }
        return false
    }
}
