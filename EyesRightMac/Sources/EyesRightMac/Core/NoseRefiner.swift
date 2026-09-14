import CoreGraphics

/// 校正鼻尖：强制落在两眼中线上，只用颜色搜索微调「深度」。
/// 旧版允许横向漂移，橘色皮毛易把点拽到脸颊。
enum NoseRefiner {
    /// 两眼中点沿脸朝下的几何深度（相对眼距）
    private static let geometricDepth: CGFloat = 0.62
    /// 颜色搜索允许偏离中线的最大比例（眼距）
    private static let maxAcrossRatio: CGFloat = 0.12
    private static let pinkPeakMin: Float = 14
    /// 深度搜索范围（相对眼距）
    private static let depthMinRatio: CGFloat = 0.28
    private static let depthMaxRatio: CGFloat = 0.95

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

        // 脸朝下：优先用「远离模型鼻点」的法向；模型鼻点常在额头侧
        let toModel = CGVector(dx: pair.nose.x - mid.x, dy: pair.nose.y - mid.y)
        let lat = toModel.dx * eyeDir.dx + toModel.dy * eyeDir.dy
        let orth = CGVector(dx: toModel.dx - eyeDir.dx * lat, dy: toModel.dy - eyeDir.dy * lat)
        let olen = hypot(orth.dx, orth.dy)

        let down: CGVector
        if olen > 1e-3 {
            down = CGVector(dx: -orth.dx / olen, dy: -orth.dy / olen)
        } else {
            // 无可靠正交分量时，取更接近图像下方的法向
            var n = CGVector(dx: -eyeDir.dy, dy: eyeDir.dx)
            if n.dy < 0 { n = CGVector(dx: -n.dx, dy: -n.dy) }
            down = n
        }

        // 几何先验：严格贴中线，不带模型横向偏移
        let geom = CGPoint(
            x: mid.x + down.dx * geometricDepth * inter,
            y: mid.y + down.dy * geometricDepth * inter
        )

        guard let pixels = RGBAImage(image) else { return geom }

        // 颜色搜索只在中线窄带内调深度；横向超限直接丢弃
        if let depth = findBestDepthAlongMidline(
            pixels: pixels,
            mid: mid,
            down: down,
            eyeDir: eyeDir,
            inter: inter
        ) {
            return CGPoint(
                x: mid.x + down.dx * depth,
                y: mid.y + down.dy * depth
            )
        }

        return geom
    }

    /// 沿两眼中线扫描，返回最佳深度（像素距离），失败返回 nil
    private static func findBestDepthAlongMidline(
        pixels: RGBAImage,
        mid: CGPoint,
        down: CGVector,
        eyeDir: CGVector,
        inter: CGFloat
    ) -> CGFloat? {
        let w = pixels.width
        let h = pixels.height
        let depthMin = depthMinRatio * inter
        let depthMax = depthMaxRatio * inter
        let maxAcross = maxAcrossRatio * inter

        // ROI：中线走廊
        var minX = CGFloat(w), maxX: CGFloat = 0
        var minY = CGFloat(h), maxY: CGFloat = 0
        for t in stride(from: depthMinRatio, through: depthMaxRatio, by: 0.08) {
            for o in [CGFloat(-maxAcrossRatio), 0, maxAcrossRatio] {
                let p = CGPoint(
                    x: mid.x + down.dx * inter * t + eyeDir.dx * inter * o,
                    y: mid.y + down.dy * inter * t + eyeDir.dy * inter * o
                )
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
        }

        let x0 = max(0, Int(floor(minX)))
        let y0 = max(0, Int(floor(minY)))
        let x1 = min(w - 1, Int(ceil(maxX)))
        let y1 = min(h - 1, Int(ceil(maxY)))
        guard x1 > x0, y1 > y0 else { return nil }

        // 按深度分桶累加颜色分，选峰值深度
        let bins = 24
        var binScore = [Float](repeating: 0, count: bins)
        var binWeight = [Float](repeating: 0, count: bins)
        var peak: Float = 0

        for y in y0...y1 {
            for x in x0...x1 {
                let vx = CGFloat(x) - mid.x
                let vy = CGFloat(y) - mid.y
                let along = vx * down.dx + vy * down.dy
                let across = vx * eyeDir.dx + vy * eyeDir.dy
                guard along >= depthMin, along <= depthMax, abs(across) <= maxAcross else {
                    continue
                }
                let (r, g, b) = pixels.rgb(x: x, y: y)
                let s = leatherScore(r: r, g: g, b: b)
                guard s > 0 else { continue }
                peak = max(peak, s)

                // 越靠中线权重越高，抑制横向噪声
                let centerW = Float(1.0 - abs(across) / maxAcross)
                let idx = min(
                    bins - 1,
                    max(0, Int(((along - depthMin) / (depthMax - depthMin)) * CGFloat(bins)))
                )
                binScore[idx] += s * centerW
                binWeight[idx] += centerW
            }
        }

        guard peak >= pinkPeakMin else { return nil }

        var bestIdx = -1
        var bestAvg: Float = 0
        for i in 0..<bins {
            guard binWeight[i] > 0 else { continue }
            let avg = binScore[i] / binWeight[i]
            // 要求桶内有足够证据
            if binWeight[i] >= 4, avg > bestAvg {
                bestAvg = avg
                bestIdx = i
            }
        }
        guard bestIdx >= 0, bestAvg >= pinkPeakMin * 0.85 else { return nil }

        let t0 = depthMin + (depthMax - depthMin) * (CGFloat(bestIdx) + 0.5) / CGFloat(bins)
        // 与几何先验混合，避免颜色偶发尖峰
        let geomDepth = geometricDepth * inter
        return t0 * 0.65 + geomDepth * 0.35
    }

    /// 粉/红/褐鼻头；强力压制橘色皮毛
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

        // 橘/黄毛皮：直接剔除
        if hue > 15 && hue < 60 { return 0 }
        // 过亮接近肤色白毛：降低
        if mx > 220 && sat < 0.18 { return 0 }

        var score: Float = 0
        let pink = hue >= 330 || hue <= 18
        if pink && sat > 0.20 && mx > 70 && mx < 230 {
            score = sat * (mx / 255) * 120 + max(0, r - g) * 0.35
        }
        // 深色/褐色鼻头（黑猫、深鼻）
        let brown = r > g + 8 && r > b + 8 && mx < 140 && mx > 25 && sat > 0.14
        if brown {
            score = max(score, sat * 55 + (r - g) * 0.5)
        }
        // 要求 R 明显大于 G，避免灰毛
        if r < g + 6 { score *= 0.15 }
        return score
    }
}

/// 顶左原点 RGBA 缓冲，与 PoseDetector 关键点坐标系一致
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
        // Quartz 原点在左下；翻转到顶左，才能与关键点 (x,y) 对齐
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = buffer
    }

    func rgb(x: Int, y: Int) -> (Float, Float, Float) {
        let i = y * bytesPerRow + x * 4
        return (Float(data[i]), Float(data[i + 1]), Float(data[i + 2]))
    }
}
