import AppKit
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var sourceImage: NSImage?
    @Published var resultImage: NSImage?
    @Published var isProcessing = false
    @Published var isDropTargeted = false
    @Published var statusMessage = ""
    @Published var overlayMode: OverlayMode = .ahAhAh {
        didSet {
            guard oldValue != overlayMode, sourceURL != nil else { return }
            reprocessCurrent()
        }
    }

    private var pipeline: EyePipeline?
    private var sourceURL: URL?

    init() {
        Task {
            await loadPipeline()
        }
    }

    private func loadPipeline() async {
        do {
            pipeline = try EyePipeline()
            statusMessage = ""
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        process(url: url)
    }

    func handleDrop(url: URL) {
        process(url: url)
    }

    func saveResult() {
        guard let image = resultImage else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "eyes_result.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(
                using: url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
                    ? .jpeg
                    : .png,
                properties: [:]
              )
        else {
            statusMessage = "保存失败"
            return
        }

        do {
            try data.write(to: url)
            statusMessage = "已保存：\(url.lastPathComponent)"
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func reprocessCurrent() {
        guard let sourceURL else { return }
        process(url: sourceURL)
    }

    private func process(url: URL) {
        guard let pipeline else {
            statusMessage = "模型尚未加载完成"
            return
        }

        sourceURL = url
        isProcessing = true
        isDropTargeted = false
        statusMessage = "处理中…"
        let mode = overlayMode

        Task.detached(priority: .userInitiated) { [pipeline] in
            do {
                let result = try pipeline.processImage(at: url, mode: mode)
                let source = try ImageProcessor.loadCGImage(from: url)

                await MainActor.run {
                    self.sourceImage = ImageProcessor.nsImage(from: source)
                    self.resultImage = ImageProcessor.nsImage(from: result)
                    self.isProcessing = false
                    self.statusMessage = "完成：\(url.lastPathComponent) · \(mode.rawValue)"
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }
}
