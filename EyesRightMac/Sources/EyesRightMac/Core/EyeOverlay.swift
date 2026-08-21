import AppKit
import CoreGraphics

enum EyeOverlay {
    static func loadOverlayImage() throws -> CGImage {
        guard let url = AppResources.url(forResource: "IMG_20260819_142559_cutout", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PipelineError.overlayNotFound
        }
        return image
    }

    static func apply(
        to base: CGImage,
        overlay: CGImage,
        pair: EyePair,
        coverage: CGFloat = OverlayConstants.coverage
    ) -> CGImage? {
        let width = base.width
        let height = base.height
        let overlayWidth = overlay.width
        let overlayHeight = overlay.height

        var scaleBoost: CGFloat = 1.0
        if pair.boxWidth > 0 {
            let interOverlay = hypot(
                OverlayConstants.rightEye.x - OverlayConstants.leftEye.x,
                OverlayConstants.rightEye.y - OverlayConstants.leftEye.y
            )
            let interReal = max(
                hypot(pair.right.x - pair.left.x, pair.right.y - pair.left.y),
                1e-6
            )
            let desiredWidth = pair.boxWidth * coverage
            let baseScale = interReal / interOverlay
            let neededScale = desiredWidth / OverlayConstants.totalWidth
            scaleBoost = neededScale / baseScale
        }

        // Detector / overlay template use top-left coords (OpenCV). CGContext is
        // bottom-left — convert both sides so the similarity matches Python.
        let srcLeft = CGPoint(
            x: OverlayConstants.leftEye.x,
            y: CGFloat(overlayHeight) - OverlayConstants.leftEye.y
        )
        let srcRight = CGPoint(
            x: OverlayConstants.rightEye.x,
            y: CGFloat(overlayHeight) - OverlayConstants.rightEye.y
        )
        let dstLeft = CGPoint(x: pair.left.x, y: CGFloat(height) - pair.left.y)
        let dstRight = CGPoint(x: pair.right.x, y: CGFloat(height) - pair.right.y)

        let transform = similarityTransform(
            srcLeft: srcLeft,
            srcRight: srcRight,
            dstLeft: dstLeft,
            dstRight: dstRight,
            scaleBoost: scaleBoost
        )

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

        context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.concatenate(transform)
        context.draw(overlay, in: CGRect(x: 0, y: 0, width: overlayWidth, height: overlayHeight))

        return context.makeImage()
    }

    private static func similarityTransform(
        srcLeft: CGPoint,
        srcRight: CGPoint,
        dstLeft: CGPoint,
        dstRight: CGPoint,
        scaleBoost: CGFloat
    ) -> CGAffineTransform {
        let srcCenter = CGPoint(
            x: (srcLeft.x + srcRight.x) / 2,
            y: (srcLeft.y + srcRight.y) / 2
        )
        let dstCenter = CGPoint(
            x: (dstLeft.x + dstRight.x) / 2,
            y: (dstLeft.y + dstRight.y) / 2
        )

        let srcVector = CGVector(dx: srcRight.x - srcLeft.x, dy: srcRight.y - srcLeft.y)
        let dstVector = CGVector(dx: dstRight.x - dstLeft.x, dy: dstRight.y - dstLeft.y)

        let srcDistance = max(hypot(srcVector.dx, srcVector.dy), 1e-6)
        let dstDistance = hypot(dstVector.dx, dstVector.dy) * scaleBoost
        let scale = dstDistance / srcDistance

        let srcAngle = atan2(srcVector.dy, srcVector.dx)
        let dstAngle = atan2(dstVector.dy, dstVector.dx)
        let angle = dstAngle - srcAngle

        let cosA = cos(angle) * scale
        let sinA = sin(angle) * scale
        let tx = dstCenter.x - (cosA * srcCenter.x - sinA * srcCenter.y)
        let ty = dstCenter.y - (sinA * srcCenter.x + cosA * srcCenter.y)

        return CGAffineTransform(a: cosA, b: sinA, c: -sinA, d: cosA, tx: tx, ty: ty)
    }
}
