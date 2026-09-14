import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../models/eye_models.dart';

/// 校正鼻尖：强制两眼中线，颜色搜索只调深度，避免橘色皮毛拽到脸颊。
class NoseRefiner {
  static const _geometricDepth = 0.62;
  static const _maxAcrossRatio = 0.12;
  static const _pinkPeakMin = 14.0;
  static const _depthMinRatio = 0.28;
  static const _depthMaxRatio = 0.95;

  static EyePair refine(EyePair pair, img.Image image) {
    final tip = _resolveTip(pair, image);
    return EyePair(
      left: pair.left,
      right: pair.right,
      nose: tip,
      confidence: pair.confidence,
      boxWidth: pair.boxWidth,
    );
  }

  static ui.Offset _resolveTip(EyePair pair, img.Image image) {
    final left = pair.left;
    final right = pair.right;
    final mid = ui.Offset((left.dx + right.dx) / 2, (left.dy + right.dy) / 2);
    final dx = right.dx - left.dx;
    final dy = right.dy - left.dy;
    final inter = math.max(hypot(dx, dy), 1e-6);
    final eyeDirX = dx / inter;
    final eyeDirY = dy / inter;

    final toMx = pair.nose.dx - mid.dx;
    final toMy = pair.nose.dy - mid.dy;
    final lat = toMx * eyeDirX + toMy * eyeDirY;
    final orthX = toMx - eyeDirX * lat;
    final orthY = toMy - eyeDirY * lat;
    final olen = hypot(orthX, orthY);

    late final double downX;
    late final double downY;
    if (olen > 1e-3) {
      downX = -orthX / olen;
      downY = -orthY / olen;
    } else {
      var nx = -eyeDirY;
      var ny = eyeDirX;
      if (ny < 0) {
        nx = -nx;
        ny = -ny;
      }
      downX = nx;
      downY = ny;
    }

    final geom = ui.Offset(
      mid.dx + downX * _geometricDepth * inter,
      mid.dy + downY * _geometricDepth * inter,
    );

    final depth = _findBestDepthAlongMidline(
      image: image,
      mid: mid,
      downX: downX,
      downY: downY,
      eyeDirX: eyeDirX,
      eyeDirY: eyeDirY,
      inter: inter,
    );
    if (depth == null) return geom;
    return ui.Offset(mid.dx + downX * depth, mid.dy + downY * depth);
  }

  static double? _findBestDepthAlongMidline({
    required img.Image image,
    required ui.Offset mid,
    required double downX,
    required double downY,
    required double eyeDirX,
    required double eyeDirY,
    required double inter,
  }) {
    final w = image.width;
    final h = image.height;
    final depthMin = _depthMinRatio * inter;
    final depthMax = _depthMaxRatio * inter;
    final maxAcross = _maxAcrossRatio * inter;

    var minX = w.toDouble();
    var maxX = 0.0;
    var minY = h.toDouble();
    var maxY = 0.0;
    for (var t = _depthMinRatio; t <= _depthMaxRatio; t += 0.08) {
      for (final o in [-_maxAcrossRatio, 0.0, _maxAcrossRatio]) {
        final px = mid.dx + downX * inter * t + eyeDirX * inter * o;
        final py = mid.dy + downY * inter * t + eyeDirY * inter * o;
        minX = math.min(minX, px);
        maxX = math.max(maxX, px);
        minY = math.min(minY, py);
        maxY = math.max(maxY, py);
      }
    }

    final x0 = minX.floor().clamp(0, w - 1);
    final y0 = minY.floor().clamp(0, h - 1);
    final x1 = maxX.ceil().clamp(0, w - 1);
    final y1 = maxY.ceil().clamp(0, h - 1);
    if (x1 <= x0 || y1 <= y0) return null;

    const bins = 24;
    final binScore = List<double>.filled(bins, 0);
    final binWeight = List<double>.filled(bins, 0);
    var peak = 0.0;

    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final vx = x - mid.dx;
        final vy = y - mid.dy;
        final along = vx * downX + vy * downY;
        final across = vx * eyeDirX + vy * eyeDirY;
        if (along < depthMin || along > depthMax || across.abs() > maxAcross) {
          continue;
        }
        final p = image.getPixel(x, y);
        final s = _leatherScore(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        if (s <= 0) continue;
        if (s > peak) peak = s;
        final centerW = 1.0 - across.abs() / maxAcross;
        final idx = (((along - depthMin) / (depthMax - depthMin)) * bins)
            .floor()
            .clamp(0, bins - 1);
        binScore[idx] += s * centerW;
        binWeight[idx] += centerW;
      }
    }

    if (peak < _pinkPeakMin) return null;

    var bestIdx = -1;
    var bestAvg = 0.0;
    for (var i = 0; i < bins; i++) {
      if (binWeight[i] < 4) continue;
      final avg = binScore[i] / binWeight[i];
      if (avg > bestAvg) {
        bestAvg = avg;
        bestIdx = i;
      }
    }
    if (bestIdx < 0 || bestAvg < _pinkPeakMin * 0.85) return null;

    final t0 = depthMin + (depthMax - depthMin) * (bestIdx + 0.5) / bins;
    final geomDepth = _geometricDepth * inter;
    return t0 * 0.65 + geomDepth * 0.35;
  }

  static double _leatherScore(double r, double g, double b) {
    final mx = math.max(r, math.max(g, b));
    final mn = math.min(r, math.min(g, b));
    final sat = mx > 1e-3 ? (mx - mn) / mx : 0.0;
    final d = math.max(mx - mn, 1e-3);
    double hue;
    if (r == mx) {
      hue = 60 * (g - b) / d;
    } else if (g == mx) {
      hue = 120 + 60 * (b - r) / d;
    } else {
      hue = 240 + 60 * (r - g) / d;
    }
    if (hue < 0) hue += 360;

    if (hue > 15 && hue < 60) return 0;
    if (mx > 220 && sat < 0.18) return 0;

    var score = 0.0;
    final pink = hue >= 330 || hue <= 18;
    if (pink && sat > 0.20 && mx > 70 && mx < 230) {
      score = sat * (mx / 255) * 120 + math.max(0, r - g) * 0.35;
    }
    final brown = r > g + 8 && r > b + 8 && mx < 140 && mx > 25 && sat > 0.14;
    if (brown) {
      score = math.max(score, sat * 55 + (r - g) * 0.5);
    }
    if (r < g + 6) score *= 0.15;
    return score;
  }
}
