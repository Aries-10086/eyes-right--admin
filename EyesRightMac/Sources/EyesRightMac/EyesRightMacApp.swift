import AppKit
import SwiftUI

enum EyesRightMain {
    static func runCLI(input: URL, output: URL) -> Int32 {
        do {
            let pipeline = try EyePipeline()
            let result = try pipeline.processImage(at: input)
            let image = ImageProcessor.nsImage(from: result)
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:])
            else {
                fputs("Failed to encode output\n", stderr)
                return 1
            }
            try data.write(to: output)
            print("Saved: \(output.path)")
            return 0
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            return 1
        }
    }
}

struct EyesRightMacApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 980, minHeight: 680)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开图片…") {
                    viewModel.openImage()
                }
                .keyboardShortcut("o")
            }
            CommandGroup(after: .saveItem) {
                Button("保存结果…") {
                    viewModel.saveResult()
                }
                .keyboardShortcut("s")
                .disabled(viewModel.resultImage == nil)
            }
        }
    }
}
