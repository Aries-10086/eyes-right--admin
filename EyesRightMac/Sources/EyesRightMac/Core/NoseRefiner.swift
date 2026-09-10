import CoreGraphics

/// 模型 kpt2 常落在额头/鼻梁，贴小丑鼻前用两眼几何 + 鼻头颜色搜索校正。
enum NoseRefiner {
    /// 两眼中点沿「脸朝下」方向的几何先验（相对眼距）
    private static let geometricDepth: CGFloat = 0.58
    private static let pinkPeakMin: Float = 10
    private static let eyesOnNoseDistRatio: CGFloat = 0.42

    static func refine(_ pair: EyePair, in image: CGImage) -> EyePair {
        let tip = resolveTip(pair: pair, image: image)
        return EyePair(
            left: pair.left,
            right: pair.right,
            nose: tip,
            confidence: pair.confidence,
            boxWidth: pair.boxWidth
        )
    }

    private static func resolveTip(pair: EyePair, image: CGImage) -> CGPoint {
        let left = pair.left
        let right = pair.right
        let mid = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        let dx = right.x - left.x
        let dy = right.y - left.y
        let inter = max(hypot(dx, dy), 1e-6)
        let eyeDir = CGVector(dx: dx / inter, dy: dy / inter)

        let toModel = CGVector(dx: pair.nose.x - mid.x, dy: pair.nose.y - mid.y)
        let lat = toModel.dx * eyeDir.dx + toModel.dy * eyeDir.dy
        let orth = CGVector(dx: toModel.dx - eyeDir.dx * lat, dy: toModel.dy - eyeDir.dy * lat)
        let olen = hypot(orth.dx, orth.dy)

        let down: CGVector
        if olen > 1e-3 {
            // 模型鼻点多在额头侧：脸朝下取反方向
            down = CGVector(dx: -orth.dx / olen, dy: -orth.dy / olen)
        } else {
            var n = CGVector(dx: -eyeDir.dy, dy: eyeDir.dx)
            if n.dy < 0 { n = CGVector(dx: -n.dx, dy: -n.dy) }
            down = n
        }

        let geom = CGPoint(
            x: mid.x + down.dx * geometricDepth * inter + eyeDir.dx * lat * 0.1,
            y: mid.y + down.dy * geometricDepth * inter + eyeDir.dy * lat * 0.1
        )

        guard let pixels = RGBAImage(image) else { return geom }
        guard let pink = findNoseLeatherCentroid(
            pixels: pixels,
            mid: mid,
            down: down,
            eyeDir: eyeDir,
            inter: inter
        ) else {
            return geom
        }

        let distMid = hypot(pink.point.x - mid.x, pink.point.y - mid.y)
        if distMid < eyesOnNoseDistRatio * inter {
            // 眼点误落在鼻头两侧时，粉色质心≈鼻心
            return CGPoint(
                x: pink.point.x * 0.85 + mid.x * 0.15,
                y: pink.point.y * 0.85 + mid.y * 0.15
            )
        }

        return CGPoint(
            x: pink.point.x * 0.72 + geom.x * 0.28,
            y: pink.point.y * 0.72 + geom.y * 0.28
        )
    }

    private static func findNoseLeatherCentroid(
        pixels: RGBAImage,
        mid: CGPoint,
        down: CGVector,
        eyeDir: CGVector,
        inter: CGFloat
    ) -> (point: CGPoint, peak: Float)? {
        let w = pixels.width
        let h = pixels.height

        var minX = CGFloat(w), maxX: CGFloat = 0
        var minY = CGFloat(h), maxY: CGFloat = 0
        for t in stride(from: CGFloat(-0.1), through: 1.0, by: 0.14) {
            for o in [CGFloat(-0.5), 0, 0.5] {
                let p = CGPoint(
                    x: mid.x + down.dx * inter * t + eyeDir.dx * inter * o,
                    y: mid.y + down.dy * inter * t + eyeDir.dy * inter * o
                )
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
        }

        let x0 = max(0, Int(minX.rounded(.down)))
        let y0 = max(0, Int(minY.rounded(.down)))
        let x1 = min(w - 1, Int(maxX.rounded(.up)))
        let y1 = min(h - 1, Int(maxY.rounded(.up)))
        guard x1 > x0, y1 > y0 else { return nil }

        let rw = x1 - x0 + 1
        let rh = y1 - y0 + 1
        var score = [Float](repeating: 0, count: rw * rh)
        var peak: Float = 0

        for y in y0...y1 {
            for x in x0...x1 {
                let along = (CGFloat(x) - mid.x) * down.dx + (CGFloat(y) - mid.y) * down.dy
                let across = (CGFloat(x) - mid.x) * eyeDir.dx + (CGFloat(y) - mid.y) * eyeDir.dy
                guard along > -0.1 * inter, along < 0.95 * inter, abs(across) < 0.4 * inter else {
                    continue
                }
                let (r, g, b) = pixels.rgb(x: x, y: y)
                let s = leatherScore(r: r, g: g, b: b)
                score[(y - y0) * rw + (x - x0)] = s
                peak = max(peak, s)
            }
        }

        guard peak >= pinkPeakMin else { return nil }

        // 3×3 盒式平滑后再取加权质心
        var smooth = score
        for y in 0..<rh {
            for x in 0..<rw {
                var sum: Float = 0
                var n: Float = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let xx = x + dx, yy = y + dy
                        guard xx >= 0, yy >= 0, xx < rw, yy < rh else { continue }
                        sum += score[yy * rw + xx]
                        n += 1
                    }
                }
                smooth[y * rw + x] = sum / max(n, 1)
            }
        }

        let thr = max(pinkPeakMin, peak * 0.72)
        var wsum: Float = 0
        var sx: Float = 0
        var sy: Float = 0
        var smoothPeak: Float = 0
        for y in 0..<rh {
            for x in 0..<rw {
                let s = smooth[y * rw + x]
                smoothPeak = max(smoothPeak, s)
                guard s >= thr else { continue }
                let along = (CGFloat(x0 + x) - mid.x) * down.dx + (CGFloat(y0 + y) - mid.y) * down.dy
                let across = (CGFloat(x0 + x) - mid.x) * eyeDir.dx + (CGFloat(y0 + y) - mid.y) * eyeDir.dy
                guard along > -0.1 * inter, along < 0.95 * inter, abs(across) < 0.4 * inter else {
                    continue
                }
                wsum += s
                sx += s * Float(x0 + x)
                sy += s * Float(y0 + y)
            }
        }

        guard wsum > 0, smoothPeak >= pinkPeakMin else { return nil }
        return (CGPoint(x: CGFloat(sx / wsum), y: CGFloat(sy / wsum)), smoothPeak)
    }

    /// 粉/红鼻头；压低橘色皮毛误检
    private static func leatherScore(r: Float, g: Float, b: Float) -> Float {
        let mx = max(r, max(g, b))
        let mn = min(r, min(g, b))
        let sat = mx > 1e-3 ? (mx - mn) / mx : 0
        let d = max(mx - mn, 1e-3)
        var hue: Float = 0
        if r == mx {
            hue = 60 * (g - b) / d
        } else if g == mx {
            hue = 120 + 60 * (b - r) / d
        } else {
            hue = 240 + 60 * (r - g) / d
        }
        if hue < 0 { hue += 360 }

        let orange = hue > 18 && hue < 55
        let pink = hue >= 330 || hue <= 22
        var score: Float = 0
        if pink && sat > 0.16 && mx > 65 {
            score = sat * (mx / 255) * 110 + (r - g) * 0.25
        }
        if orange {
            score *= 0.05
        }
        let brown = r > g + 10 && r > b + 10 && mx < 130 && mx > 30 && sat > 0.12
        if brown {
            score = max(score, sat * 45 + (r - g) * 0.4)
        }
        return score
    }
}

/// 顶左原点、逐行 RGBA8888 采样
private struct RGBAImage {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let data: [UInt8]

    init?(_ image: CGImage) {
        width = image.width
        height = image.height
        bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        // 画成顶左坐标系，与关键点一致
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = buffer
    }

    func rgb(x: Int, y: Int) -> (Float, Float, Float) {
        let i = y * bytesPerRow + x * 4
        return (Float(data[i]), Float(data[i + 1]), Float(data[i + 2]))
    }
}
