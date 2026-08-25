import AppKit

/// 全屏蒙版拖拽选区（类似截图）
@MainActor
final class RegionPickerController {
    private var windows: [PickerWindow] = []
    private var completion: ((ScreenRegion?) -> Void)?
    private var keyMonitor: Any?

    func begin(completion: @escaping (ScreenRegion?) -> Void) {
        cancel()
        self.completion = completion

        for screen in NSScreen.screens {
            let window = PickerWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true

            let view = RegionPickerView(screenFrame: screen.frame) { [weak self] rect in
                self?.finish(with: rect)
            } onCancel: { [weak self] in
                self?.finish(with: nil)
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            windows.append(window)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // Esc
                self.finish(with: nil)
                return nil
            case 36, 76: // Return / Enter
                self.commitFromActiveView()
                return nil
            default:
                return event
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
    }

    func cancel() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func commitFromActiveView() {
        let view = (NSApp.keyWindow?.contentView as? RegionPickerView)
            ?? windows.compactMap { $0.contentView as? RegionPickerView }.first
        view?.commitIfValid()
    }

    private func finish(with rect: CGRect?) {
        let region = rect.flatMap(ScreenRegionGeometry.makeRegion(globalRect:))
        let cb = completion
        completion = nil
        cancel()
        cb?(region)
    }
}

private final class PickerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class RegionPickerView: NSView {
    private let screenFrame: CGRect
    private let onComplete: (CGRect) -> Void
    private let onCancel: () -> Void
    private var startPoint: CGPoint?
    private var currentRect: CGRect = .zero
    private var hasSelection = false

    private lazy var cancelButton: NSButton = {
        let button = NSButton(title: "退出选区 Esc", target: self, action: #selector(cancelTapped))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        button.layer?.cornerRadius = 8
        button.contentTintColor = .white
        return button
    }()

    private lazy var confirmButton: NSButton = {
        let button = NSButton(title: "开始贴眼 ⏎", target: self, action: #selector(confirmTapped))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.isEnabled = false
        return button
    }()

    init(screenFrame: CGRect, onComplete: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.screenFrame = screenFrame
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
        addSubview(cancelButton)
        addSubview(confirmButton)
        layoutChrome()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        layoutChrome()
    }

    override func layout() {
        super.layout()
        layoutChrome()
    }

    private func layoutChrome() {
        cancelButton.sizeToFit()
        confirmButton.sizeToFit()
        let padding: CGFloat = 16
        let btnH = max(cancelButton.bounds.height, 36)
        let cancelW = max(cancelButton.bounds.width + 20, 120)
        let confirmW = max(confirmButton.bounds.width + 20, 120)
        cancelButton.frame = CGRect(
            x: padding,
            y: bounds.height - btnH - padding - 8,
            width: cancelW,
            height: btnH
        )
        confirmButton.frame = CGRect(
            x: padding + cancelW + 12,
            y: bounds.height - btnH - padding - 8,
            width: confirmW,
            height: btnH
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: bounds)
        if currentRect.width > 2, currentRect.height > 2 {
            path.append(NSBezierPath(rect: currentRect))
            path.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.45).setFill()
        path.fill()

        if currentRect.width > 2, currentRect.height > 2 {
            NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.65, alpha: 1).setStroke()
            let border = NSBezierPath(rect: currentRect.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 2
            border.stroke()
        }

        let hint = hasSelection
            ? "调整选区后点「开始贴眼」或按 Enter · Esc /「退出选区」取消"
            : "拖拽选择贴眼区域 · Esc /「退出选区」取消"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = hint.size(withAttributes: attrs)
        let origin = CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height - 96)
        hint.draw(at: origin, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        hasSelection = false
        confirmButton.isEnabled = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let p = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, p.x),
            y: min(start.y, p.y),
            width: abs(p.x - start.x),
            height: abs(p.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard startPoint != nil else { return }
        startPoint = nil
        hasSelection = currentRect.width >= 80 && currentRect.height >= 80
        confirmButton.isEnabled = hasSelection
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:
            onCancel()
        case 36, 76:
            commitIfValid()
        default:
            super.keyDown(with: event)
        }
    }

    @objc private func cancelTapped() {
        onCancel()
    }

    @objc private func confirmTapped() {
        commitIfValid()
    }

    func commitIfValid() {
        guard currentRect.width >= 80, currentRect.height >= 80 else { return }
        let global = CGRect(
            x: screenFrame.minX + currentRect.minX,
            y: screenFrame.minY + currentRect.minY,
            width: currentRect.width,
            height: currentRect.height
        )
        onComplete(global)
    }
}
