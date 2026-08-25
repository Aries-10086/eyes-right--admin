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

    static func loadGuangOverlayImage() throws -> CGImage {
        guard let url = AppResources.url(forResource: "guang_overlay", withExtension: "jpg"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PipelineError.overlayNotFound
        }
        return image
    }

    /// 「啊啊啊」：整张双眼镜片一次贴上
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

    /// 「加一道光」：算距离 → 定中心 → 再定大小盖住眼睛；右眼默认不镜像
    static func applyPerEye(
        to base: CGImage,
        sticker: CGImage,
        pair: EyePair,
        mirrorRight: Bool = false
    ) -> CGImage? {
        let width = base.width
        let height = base.height
        let stickerW = CGFloat(sticker.width)
        let stickerH = CGFloat(sticker.height)

        // 1) 距离与朝向
        let dx = pair.right.x - pair.left.x
        let dy = pair.right.y - pair.left.y
        let interEye = max(hypot(dx, dy), 1e-6)
        let mid = CGPoint(
            x: (pair.left.x + pair.right.x) / 2,
            y: (pair.left.y + pair.right.y) / 2
        )
        let dir = CGVector(dx: dx / interEye, dy: dy / interEye)

        // 半跨距：至少用检测眼距的一半；若点挤在一起，则按脸宽拉开
        let halfFromEyes = interEye * 0.5
        let halfFromBox = pair.boxWidth > 0
            ? pair.boxWidth * OverlayConstants.perEyeHalfSpanFromBox
            : halfFromEyes
        let halfSpan = max(halfFromEyes, halfFromBox) * OverlayConstants.perEyeSpreadBoost

        // 2) 两张图中心：沿两眼连线，对称放在中点两侧
        let leftCenter = CGPoint(
            x: mid.x - dir.dx * halfSpan,
            y: mid.y - dir.dy * halfSpan
        )
        let rightCenter = CGPoint(
            x: mid.x + dir.dx * halfSpan,
            y: mid.y + dir.dy * halfSpan
        )

        // 3) 大小：盖住单眼，但限制上限避免中间糊成一团
        let coverWidth = halfSpan * OverlayConstants.perEyeCoverRatio
        let maxWidth = halfSpan * OverlayConstants.perEyeMaxWidthByHalfSpan
        let targetWidth = min(max(coverWidth, halfSpan * 0.85), maxWidth)
        let scale = targetWidth / stickerW

        let angleTopLeft = atan2(dy, dx)
        let angleCG = -angleTopLeft

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

        drawSticker(
            sticker,
            in: context,
            centerTopLeft: leftCenter,
            imageHeight: height,
            scale: scale,
            angleCG: angleCG,
            mirror: false,
            stickerSize: CGSize(width: stickerW, height: stickerH)
        )
        drawSticker(
            sticker,
            in: context,
            centerTopLeft: rightCenter,
            imageHeight: height,
            scale: scale,
            angleCG: angleCG,
            mirror: mirrorRight,
            stickerSize: CGSize(width: stickerW, height: stickerH)
        )

        return context.makeImage()
    }

    /// 仅绘制贴图到透明画布（区域实时 overlay 用，不画底图）
    static func renderOverlayOnly(
        canvasWidth: Int,
        canvasHeight: Int,
        mode: OverlayMode,
        pair: EyePair,
        dualOverlay: CGImage,
        guangOverlay: CGImage
    ) -> CGImage? {
        guard let blank = clearCanvas(width: canvasWidth, height: canvasHeight) else {
            return nil
        }
        switch mode {
        case .ahAhAh:
            return apply(to: blank, overlay: dualOverlay, pair: pair)
        case .addLight:
            return applyPerEye(to: blank, sticker: guangOverlay, pair: pair, mirrorRight: false)
        }
    }

    private static func clearCanvas(width: Int, height: Int) -> CGImage? {
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
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func drawSticker(
        _ sticker: CGImage,
        in context: CGContext,
        centerTopLeft: CGPoint,
        imageHeight: Int,
        scale: CGFloat,
        angleCG: CGFloat,
        mirror: Bool,
        stickerSize: CGSize
    ) {
        let cx = centerTopLeft.x
        let cy = CGFloat(imageHeight) - centerTopLeft.y

        context.saveGState()
        context.translateBy(x: cx, y: cy)
        context.rotate(by: angleCG)
        if mirror {
            context.scaleBy(x: -scale, y: scale)
        } else {
            context.scaleBy(x: scale, y: scale)
        }
        context.draw(
            sticker,
            in: CGRect(
                x: -stickerSize.width / 2,
                y: -stickerSize.height / 2,
                width: stickerSize.width,
                height: stickerSize.height
            )
        )
        context.restoreGState()
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
