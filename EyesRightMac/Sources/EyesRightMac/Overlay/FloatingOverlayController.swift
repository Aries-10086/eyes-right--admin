import AppKit

/// 区域同尺寸透明置顶窗，只画贴图；右上角提供「退出」
@MainActor
final class FloatingOverlayController {
    private var panel: NSPanel?
    private var imageView: NSImageView?
    private var chromeWindow: NSWindow?
    private var exitButton: NSButton?
    private(set) var region: ScreenRegion?
    var onExit: (() -> Void)?
    var clickThrough: Bool = true {
        didSet { applyClickThrough() }
    }

    func show(region: ScreenRegion) {
        self.region = region
        ensureWindows(for: region)
        updateFrame(region.frame)
        panel?.orderFrontRegardless()
        chromeWindow?.orderFrontRegardless()
        clear()
    }

    func updateOverlayImage(_ image: CGImage?) {
        guard let imageView else { return }
        if let image {
            let size = NSSize(width: image.width, height: image.height)
            imageView.image = NSImage(cgImage: image, size: size)
        } else {
            imageView.image = nil
        }
    }

    func clear() {
        imageView?.image = nil
    }

    func hide() {
        panel?.orderOut(nil)
        chromeWindow?.orderOut(nil)
        panel = nil
        chromeWindow = nil
        imageView = nil
        exitButton = nil
        region = nil
    }

    private func ensureWindows(for region: ScreenRegion) {
        if panel != nil { return }

        let panel = NSPanel(
            contentRect: region.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let imageView = NSImageView(frame: CGRect(origin: .zero, size: region.frame.size))
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = imageView

        // 边框 + 退出按钮（始终可点，不受点击穿透影响）
        let chrome = NSWindow(
            contentRect: region.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        chrome.isOpaque = false
        chrome.backgroundColor = .clear
        chrome.hasShadow = false
        chrome.level = .statusBar
        chrome.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        chrome.ignoresMouseEvents = false

        let chromeRoot = RegionChromeView(frame: CGRect(origin: .zero, size: region.frame.size))
        let exit = NSButton(title: "退出 Esc", target: self, action: #selector(exitTapped))
        exit.bezelStyle = .rounded
        exit.controlSize = .small
        exit.wantsLayer = true
        exit.layer?.cornerRadius = 6
        exit.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        exit.contentTintColor = .white
        exit.sizeToFit()
        let exitSize = NSSize(width: max(exit.bounds.width + 16, 72), height: max(exit.bounds.height, 24))
        exit.frame = CGRect(
            x: max(8, region.frame.width - exitSize.width - 8),
            y: max(8, region.frame.height - exitSize.height - 8),
            width: exitSize.width,
            height: exitSize.height
        )
        chromeRoot.addSubview(exit)
        chrome.contentView = chromeRoot

        self.panel = panel
        self.imageView = imageView
        self.chromeWindow = chrome
        self.exitButton = exit
        applyClickThrough()
    }

    private func updateFrame(_ frame: CGRect) {
        panel?.setFrame(frame, display: true)
        chromeWindow?.setFrame(frame, display: true)
        imageView?.frame = CGRect(origin: .zero, size: frame.size)
        chromeWindow?.contentView?.frame = CGRect(origin: .zero, size: frame.size)
        if let exitButton {
            let exitSize = exitButton.frame.size
            exitButton.frame = CGRect(
                x: max(8, frame.width - exitSize.width - 8),
                y: max(8, frame.height - exitSize.height - 8),
                width: exitSize.width,
                height: exitSize.height
            )
        }
    }

    private func applyClickThrough() {
        panel?.ignoresMouseEvents = clickThrough
        // chrome 始终可点退出
        chromeWindow?.ignoresMouseEvents = false
    }

    @objc private func exitTapped() {
        onExit?()
    }
}

private final class RegionChromeView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let inset = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(rect: inset)
        path.lineWidth = 2
        NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.65, alpha: 0.95).setStroke()
        path.stroke()
    }

    /// 仅按钮区域吃点击，其余穿透到下层
    override func hitTest(_ point: NSPoint) -> NSView? {
        for sub in subviews where sub.frame.contains(point) {
            let local = convert(point, to: sub)
            return sub.hitTest(local) ?? sub
        }
        return nil
    }
}
