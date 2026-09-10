import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../models/eye_models.dart';

/// 模型 kpt2 常落在额头/鼻梁，贴小丑鼻前用两眼几何 + 鼻头颜色搜索校正。
class NoseRefiner {
  static const _geometricDepth = 0.58;
  static const _pinkPeakMin = 10.0;
  static const _eyesOnNoseDistRatio = 0.42;

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
      mid.dx + downX * _geometricDepth * inter + eyeDirX * lat * 0.1,
      mid.dy + downY * _geometricDepth * inter + eyeDirY * lat * 0.1,
    );

    final pink = _findNoseLeatherCentroid(
      image: image,
      mid: mid,
      downX: downX,
      downY: downY,
      eyeDirX: eyeDirX,
      eyeDirY: eyeDirY,
      inter: inter,
    );
    if (pink == null) return geom;

    final distMid = hypot(pink.dx - mid.dx, pink.dy - mid.dy);
    if (distMid < _eyesOnNoseDistRatio * inter) {
      return ui.Offset(pink.dx * 0.85 + mid.dx * 0.15, pink.dy * 0.85 + mid.dy * 0.15);
    }
    return ui.Offset(pink.dx * 0.72 + geom.dx * 0.28, pink.dy * 0.72 + geom.dy * 0.28);
  }

  static ui.Offset? _findNoseLeatherCentroid({
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
    var minX = w.toDouble();
    var maxX = 0.0;
    var minY = h.toDouble();
    var maxY = 0.0;
    for (var t = -0.1; t <= 1.0; t += 0.14) {
      for (final o in [-0.5, 0.0, 0.5]) {
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

    final rw = x1 - x0 + 1;
    final rh = y1 - y0 + 1;
    final score = List<double>.filled(rw * rh, 0);
    var peak = 0.0;

    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final along = (x - mid.dx) * downX + (y - mid.dy) * downY;
        final across = (x - mid.dx) * eyeDirX + (y - mid.dy) * eyeDirY;
        if (along <= -0.1 * inter || along >= 0.95 * inter || across.abs() >= 0.4 * inter) {
          continue;
        }
        final p = image.getPixel(x, y);
        final s = _leatherScore(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        score[(y - y0) * rw + (x - x0)] = s;
        if (s > peak) peak = s;
      }
    }
    if (peak < _pinkPeakMin) return null;

    final smooth = List<double>.from(score);
    for (var y = 0; y < rh; y++) {
      for (var x = 0; x < rw; x++) {
        var sum = 0.0;
        var n = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx;
            final yy = y + dy;
            if (xx < 0 || yy < 0 || xx >= rw || yy >= rh) continue;
            sum += score[yy * rw + xx];
            n++;
          }
        }
        smooth[y * rw + x] = sum / math.max(n, 1);
      }
    }

    final thr = math.max(_pinkPeakMin, peak * 0.72);
    var wsum = 0.0;
    var sx = 0.0;
    var sy = 0.0;
    var smoothPeak = 0.0;
    for (var y = 0; y < rh; y++) {
      for (var x = 0; x < rw; x++) {
        final s = smooth[y * rw + x];
        if (s > smoothPeak) smoothPeak = s;
        if (s < thr) continue;
        final px = x0 + x;
        final py = y0 + y;
        final along = (px - mid.dx) * downX + (py - mid.dy) * downY;
        final across = (px - mid.dx) * eyeDirX + (py - mid.dy) * eyeDirY;
        if (along <= -0.1 * inter || along >= 0.95 * inter || across.abs() >= 0.4 * inter) {
          continue;
        }
        wsum += s;
        sx += s * px;
        sy += s * py;
      }
    }
    if (wsum <= 0 || smoothPeak < _pinkPeakMin) return null;
    return ui.Offset(sx / wsum, sy / wsum);
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

    final orange = hue > 18 && hue < 55;
    final pink = hue >= 330 || hue <= 22;
    var score = 0.0;
    if (pink && sat > 0.16 && mx > 65) {
      score = sat * (mx / 255) * 110 + (r - g) * 0.25;
    }
    if (orange) score *= 0.05;
    final brown = r > g + 10 && r > b + 10 && mx < 130 && mx > 30 && sat > 0.12;
    if (brown) score = math.max(score, sat * 45 + (r - g) * 0.4);
    return score;
  }
}
