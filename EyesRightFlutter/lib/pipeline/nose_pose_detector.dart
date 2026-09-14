import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../models/eye_models.dart';
import 'nose_refiner.dart';

/// 专用鼻尖：RTMPose-AP10K（猫狗）+ 猫脸 landmark；失败回退 NoseRefiner。
class NosePoseDetector {
  NosePoseDetector._(this._rtm, this._cat);

  final OrtSession _rtm;
  final OrtSession? _cat;

  static const _rtmSize = 256;
  static const _catSize = 224;
  static const _simccSplit = 2.0;
  static const _rtmNoseIndex = 2;

  static Future<NosePoseDetector> create() async {
    final ort = OnnxRuntime();
    final rtm = await ort.createSessionFromAsset('assets/models/pet_nose_rtmpose.onnx');
    OrtSession? cat;
    try {
      cat = await ort.createSessionFromAsset('assets/models/cat_landmark_model.onnx');
    } catch (_) {
      cat = null;
    }
    return NosePoseDetector._(rtm, cat);
  }

  Future<EyePair> refine(EyePair pair, img.Image image) async {
    final mid = ui.Offset((pair.left.dx + pair.right.dx) / 2, (pair.left.dy + pair.right.dy) / 2);
    final dx = pair.right.dx - pair.left.dx;
    final dy = pair.right.dy - pair.left.dy;
    final inter = math.max(hypot(dx, dy), 1e-6);
    final eyeDirX = dx / inter;
    final eyeDirY = dy / inter;
    final down = _faceDown(pair, eyeDirX, eyeDirY, inter);

    final candidates = <({ui.Offset point, double score, String source})>[];
    final rtm = await _runRtm(image, pair, down.$1, down.$2, inter);
    if (rtm != null) candidates.add(rtm);
    final cat = await _runCat(image, mid, down.$1, down.$2, eyeDirX, eyeDirY, inter);
    if (cat != null) candidates.add(cat);

    ui.Offset chosen;
    final best = _pickBest(candidates, mid, down.$1, down.$2, eyeDirX, eyeDirY, inter);
    if (best != null) {
      chosen = best;
    } else {
      chosen = NoseRefiner.refine(pair, image).nose;
    }
    final clamped = _clampToMidline(chosen, mid, down.$1, down.$2, eyeDirX, eyeDirY, inter);
    return EyePair(
      left: pair.left,
      right: pair.right,
      nose: clamped,
      confidence: pair.confidence,
      boxWidth: pair.boxWidth,
    );
  }

  (double, double) _faceDown(EyePair pair, double eyeDirX, double eyeDirY, double inter) {
    final mid = ui.Offset((pair.left.dx + pair.right.dx) / 2, (pair.left.dy + pair.right.dy) / 2);
    final toMx = pair.nose.dx - mid.dx;
    final toMy = pair.nose.dy - mid.dy;
    final lat = toMx * eyeDirX + toMy * eyeDirY;
    final orthX = toMx - eyeDirX * lat;
    final orthY = toMy - eyeDirY * lat;
    final olen = hypot(orthX, orthY);
    if (olen > 1e-3) return (-orthX / olen, -orthY / olen);
    var nx = -eyeDirY;
    var ny = eyeDirX;
    if (ny < 0) {
      nx = -nx;
      ny = -ny;
    }
    return (nx, ny);
  }

  Future<({ui.Offset point, double score, String source})?> _runRtm(
    img.Image image,
    EyePair pair,
    double downX,
    double downY,
    double inter,
  ) async {
    final box = _faceBox(pair, image.width, image.height, downX, downY, inter);
    final tensor = _cropImagenet(image, box, _rtmSize);
    final input = await OrtValue.fromList(tensor, [1, 3, _rtmSize, _rtmSize]);
    try {
      final outputs = await _rtm.run({'input': input});
      try {
        final sx = await _asFloats(outputs['simcc_x']!);
        final sy = await _asFloats(outputs['simcc_y']!);
        const bins = 512;
        final idx = _rtmNoseIndex;
        var bestX = 0, bestY = 0;
        var maxX = -1e9, maxY = -1e9;
        for (var b = 0; b < bins; b++) {
          final vx = sx[idx * bins + b];
          final vy = sy[idx * bins + b];
          if (vx > maxX) {
            maxX = vx;
            bestX = b;
          }
          if (vy > maxY) {
            maxY = vy;
            bestY = b;
          }
        }
        final score = math.min(maxX, maxY);
        if (score < 0.05) return null;
        final lx = bestX / _simccSplit;
        final ly = bestY / _simccSplit;
        final x = box.left + lx / _rtmSize * box.width;
        final y = box.top + ly / _rtmSize * box.height;
        return (point: ui.Offset(x, y), score: score, source: 'rtm');
      } finally {
        for (final v in outputs.values) {
          await v.dispose();
        }
      }
    } finally {
      await input.dispose();
    }
  }

  Future<({ui.Offset point, double score, String source})?> _runCat(
    img.Image image,
    ui.Offset mid,
    double downX,
    double downY,
    double eyeDirX,
    double eyeDirY,
    double inter,
  ) async {
    final cat = _cat;
    if (cat == null) return null;
    final tensor = _full01(image, _catSize);
    final input = await OrtValue.fromList(tensor, [1, 3, _catSize, _catSize]);
    try {
      final outputs = await cat.run({'input': input});
      try {
        final out = await _asFloats(outputs.values.first);
        if (out.length < 6) return null;
        final p2 = ui.Offset(out[4] * image.width, out[5] * image.height);
        final along = (p2.dx - mid.dx) * downX + (p2.dy - mid.dy) * downY;
        final across = (p2.dx - mid.dx) * eyeDirX + (p2.dy - mid.dy) * eyeDirY;
        if (along <= 0.15 * inter || along >= 1.15 * inter || across.abs() >= 0.35 * inter) {
          return null;
        }
        final score = (1.0 - across.abs() / (0.35 * inter)) * 0.9;
        return (point: p2, score: score, source: 'cat');
      } finally {
        for (final v in outputs.values) {
          await v.dispose();
        }
      }
    } finally {
      await input.dispose();
    }
  }

  ui.Offset? _pickBest(
    List<({ui.Offset point, double score, String source})> candidates,
    ui.Offset mid,
    double downX,
    double downY,
    double eyeDirX,
    double eyeDirY,
    double inter,
  ) {
    ({ui.Offset point, double score})? best;
    for (final c in candidates) {
      final along = (c.point.dx - mid.dx) * downX + (c.point.dy - mid.dy) * downY;
      final across = (c.point.dx - mid.dx) * eyeDirX + (c.point.dy - mid.dy) * eyeDirY;
      if (along <= 0.12 * inter || along >= 1.2 * inter) continue;
      if (across.abs() >= 0.32 * inter) continue;
      final boost = c.source == 'cat' ? 1.15 : 1.0;
      final midline = math.max(0.0, 1 - across.abs() / (0.32 * inter));
      final total = c.score * boost * (0.55 + 0.45 * midline);
      if (best == null || total > best.score) {
        best = (point: c.point, score: total);
      }
    }
    return best?.point;
  }

  ui.Offset _clampToMidline(
    ui.Offset point,
    ui.Offset mid,
    double downX,
    double downY,
    double eyeDirX,
    double eyeDirY,
    double inter,
  ) {
    final along = (point.dx - mid.dx) * downX + (point.dy - mid.dy) * downY;
    var across = (point.dx - mid.dx) * eyeDirX + (point.dy - mid.dy) * eyeDirY;
    final maxAcross = 0.10 * inter;
    across = across.clamp(-maxAcross, maxAcross);
    final depth = along.clamp(0.28 * inter, 1.05 * inter);
    return ui.Offset(mid.dx + downX * depth + eyeDirX * across, mid.dy + downY * depth + eyeDirY * across);
  }

  ({int left, int top, int width, int height}) _faceBox(
    EyePair pair,
    int iw,
    int ih,
    double downX,
    double downY,
    double inter,
  ) {
    final mid = ui.Offset((pair.left.dx + pair.right.dx) / 2, (pair.left.dy + pair.right.dy) / 2);
    final face = math.max(pair.boxWidth, inter * 2.6) * 1.35;
    final cx = mid.dx + downX * inter * 0.35;
    final cy = mid.dy + downY * inter * 0.35;
    final x1 = (cx - face / 2).clamp(0, iw - 1.0);
    final y1 = (cy - face / 2).clamp(0, ih - 1.0);
    final x2 = (cx + face / 2).clamp(0, iw - 1.0);
    final y2 = (cy + face / 2).clamp(0, ih - 1.0);
    return (
      left: x1.round(),
      top: y1.round(),
      width: math.max(1, (x2 - x1).round()),
      height: math.max(1, (y2 - y1).round()),
    );
  }

  Float32List _cropImagenet(img.Image image, ({int left, int top, int width, int height}) box, int size) {
    final cropped = img.copyCrop(image, x: box.left, y: box.top, width: box.width, height: box.height);
    final resized = img.copyResize(cropped, width: size, height: size, interpolation: img.Interpolation.linear);
    const mean = [123.675, 116.28, 103.53];
    const std = [58.395, 57.12, 57.375];
    final out = Float32List(3 * size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = resized.getPixel(x, y);
        final plane = y * size + x;
        out[plane] = (p.r.toDouble() - mean[0]) / std[0];
        out[size * size + plane] = (p.g.toDouble() - mean[1]) / std[1];
        out[2 * size * size + plane] = (p.b.toDouble() - mean[2]) / std[2];
      }
    }
    return out;
  }

  Float32List _full01(img.Image image, int size) {
    final resized = img.copyResize(image, width: size, height: size, interpolation: img.Interpolation.linear);
    final out = Float32List(3 * size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = resized.getPixel(x, y);
        final plane = y * size + x;
        out[plane] = p.r.toDouble() / 255.0;
        out[size * size + plane] = p.g.toDouble() / 255.0;
        out[2 * size * size + plane] = p.b.toDouble() / 255.0;
      }
    }
    return out;
  }

  Future<Float32List> _asFloats(OrtValue value) async {
    final flat = await value.asFlattenedList();
    final out = Float32List(flat.length);
    for (var i = 0; i < flat.length; i++) {
      out[i] = (flat[i] as num).toDouble();
    }
    return out;
  }

  Future<void> close() async {
    await _rtm.close();
    await _cat?.close();
  }
}
