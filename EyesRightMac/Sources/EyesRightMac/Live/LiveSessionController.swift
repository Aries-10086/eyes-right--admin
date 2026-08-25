import AppKit
import Foundation

enum LiveFPSPreset: Int, CaseIterable, Identifiable {
    case eco = 8
    case normal = 12
    case high = 15

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .eco: return "省电 8"
        case .normal: return "标准 12"
        case .high: return "流畅 15"
        }
    }
}

/// 区域贴眼会话：选区 → 采集 → 检测 → 置顶贴图
@MainActor
final class LiveSessionController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var statusText = ""
    @Published var fpsPreset: LiveFPSPreset = .normal
    @Published var clickThrough = true {
        didSet { overlay.clickThrough = clickThrough }
    }

    private let picker = RegionPickerController()
    private var capture: RegionCaptureSession?
    private var pipeline: LivePipeline?
    private let overlay = FloatingOverlayController()
    private var currentRegion: ScreenRegion?
    private var overlayMode: OverlayMode = .ahAhAh
    private var escMonitor: Any?

    func setOverlayMode(_ mode: OverlayMode) {
        overlayMode = mode
        pipeline?.overlayMode = mode
    }

    func startRegionEyeOverlay() {
        if isRunning {
            stop()
        }

        statusText = "请拖拽选择贴眼区域…"
        picker.begin { [weak self] region in
            guard let self else { return }
            guard let region else {
                self.statusText = "已取消选区"
                return
            }
            Task { await self.beginCapture(region: region) }
        }
    }

    func togglePause() {
        guard isRunning else { return }
        isPaused.toggle()
        statusText = isPaused ? "区域贴眼已暂停" : "区域贴眼进行中…"
        if isPaused {
            overlay.clear()
        }
    }

    func stop() {
        removeEscMonitor()
        picker.cancel()
        let session = capture
        capture = nil
        Task {
            await session?.stop()
        }
        pipeline?.reset()
        overlay.onExit = nil
        overlay.hide()
        isRunning = false
        isPaused = false
        currentRegion = nil
        statusText = "区域贴眼已结束"
    }

    private func installEscMonitor() {
        removeEscMonitor()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRunning, event.keyCode == 53 else { return event }
            self.stop()
            return nil
        }
    }

    private func removeEscMonitor() {
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
    }

    private func beginCapture(region: ScreenRegion) async {
        do {
            if !ScreenCapturePermission.isGranted {
                statusText = "正在请求屏幕录制权限…"
                let granted = ScreenCapturePermission.requestAccess()
                if !granted || !ScreenCapturePermission.isGranted {
                    throw CaptureError.permissionDenied
                }
                // 首次授权后，部分系统要重启进程才真正生效
                statusText = "已授权：请完全退出 App 后重新打开，再点「区域贴眼」"
                return
            }

            if pipeline == nil {
                pipeline = try LivePipeline()
            }
            pipeline?.overlayMode = overlayMode
            pipeline?.reset()

            let session = RegionCaptureSession(region: region, fps: fpsPreset.rawValue)
            session.delegate = self
            capture = session
            currentRegion = region
            overlay.clickThrough = clickThrough
            overlay.onExit = { [weak self] in self?.stop() }
            overlay.show(region: region)

            try await session.start()
            isRunning = true
            isPaused = false
            installEscMonitor()
            statusText = "区域贴眼进行中 · \(fpsPreset.title) FPS · Esc 退出"
        } catch {
            overlay.onExit = nil
            overlay.hide()
            capture = nil
            isRunning = false
            removeEscMonitor()
            if ScreenCapturePermission.isPermissionFailure(error) || !ScreenCapturePermission.isGranted {
                statusText = CaptureError.permissionDenied.errorDescription
                    ?? error.localizedDescription
                ScreenCapturePermission.openSystemSettings()
            } else {
                statusText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

extension LiveSessionController: RegionCaptureSessionDelegate {
    nonisolated func regionCaptureSession(_ session: RegionCaptureSession, didOutput image: CGImage) {
        Task { @MainActor in
            guard self.isRunning, !self.isPaused else { return }
            guard let pipeline = self.pipeline else { return }
            _ = pipeline.processFrame(image) { [weak self] output in
                Task { @MainActor in
                    guard let self, self.isRunning, !self.isPaused else { return }
                    self.overlay.updateOverlayImage(output.overlayImage)
                    if output.detected {
                        // keep quiet status while detecting
                    } else if output.overlayImage == nil {
                        self.statusText = "区域贴眼中 · 未检测到眼点"
                    }
                }
            }
        }
    }

    nonisolated func regionCaptureSession(_ session: RegionCaptureSession, didFail error: Error) {
        Task { @MainActor in
            if ScreenCapturePermission.isPermissionFailure(error) || !ScreenCapturePermission.isGranted {
                self.statusText = CaptureError.permissionDenied.errorDescription
                    ?? error.localizedDescription
                ScreenCapturePermission.openSystemSettings()
            } else {
                self.statusText = error.localizedDescription
            }
            self.stop()
        }
    }
}
