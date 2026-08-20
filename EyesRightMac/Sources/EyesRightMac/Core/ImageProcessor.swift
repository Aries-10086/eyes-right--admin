import AppKit
import CoreGraphics

struct LetterboxResult {
    let tensor: [Float]
    let scale: Float
    let padLeft: Float
    let padTop: Float
    let originalWidth: Int
    let originalHeight: Int
}

enum ImageProcessor {
    static func loadCGImage(from url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PipelineError.cannotReadImage(url.lastPathComponent)
        }
        return image
    }

    static func nsImage(from cgImage: CGImage, flipForDisplay: Bool = false) -> NSImage {
        let image = flipForDisplay ? (flipVertically(cgImage) ?? cgImage) : cgImage
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    /// CGContext compositing uses a flipped (top-left) space; AppKit expects upright pixels.
    static func flipVertically(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Letterbox to 640×640 NCHW RGB float tensor (matches Ultralytics / OpenCV).
    static func letterbox(_ image: CGImage, targetSize: Int = 640) throws -> LetterboxResult {
        let width = image.width
        let height = image.height
        let scale = min(Float(targetSize) / Float(height), Float(targetSize) / Float(width))
        let newWidth = Int(round(Float(width) * scale))
        let newHeight = Int(round(Float(height) * scale))
        let padLeft = (targetSize - newWidth) / 2
        let padTop = (targetSize - newHeight) / 2

        let bytesPerRow = targetSize * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw PipelineError.preprocessFailed
        }

        // Avoid CTM Y-flip + makeImage().dataProvider — that path produced a
        // vertically flipped tensor and killed detection on some photos.
        // Draw in bottom-left user space; read context.data with row0 = top
        // (matches YOLO input; verified against Ultralytics letterbox).
        context.setFillColor(red: 114 / 255, green: 114 / 255, blue: 114 / 255, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
        context.interpolationQuality = .high
        let drawY = targetSize - padTop - newHeight
        context.draw(
            image,
            in: CGRect(x: padLeft, y: drawY, width: newWidth, height: newHeight)
        )

        guard let baseAddress = context.data else {
            throw PipelineError.preprocessFailed
        }
        let pixels = baseAddress.bindMemory(to: UInt8.self, capacity: bytesPerRow * targetSize)

        let gray: Float = 114 / 255
        var tensor = [Float](repeating: gray, count: 3 * targetSize * targetSize)

        for y in 0..<targetSize {
            for x in 0..<targetSize {
                let offset = y * bytesPerRow + x * 4
                let plane = y * targetSize + x
                tensor[plane] = Float(pixels[offset]) / 255
                tensor[targetSize * targetSize + plane] = Float(pixels[offset + 1]) / 255
                tensor[2 * targetSize * targetSize + plane] = Float(pixels[offset + 2]) / 255
            }
        }

        return LetterboxResult(
            tensor: tensor,
            scale: scale,
            padLeft: Float(padLeft),
            padTop: Float(padTop),
            originalWidth: width,
            originalHeight: height
        )
    }

    static func mapPointToOriginal(
        _ point: CGPoint,
        letterbox: LetterboxResult
    ) -> CGPoint {
        CGPoint(
            x: CGFloat((Float(point.x) - letterbox.padLeft) / letterbox.scale),
            y: CGFloat((Float(point.y) - letterbox.padTop) / letterbox.scale)
        )
    }
}
