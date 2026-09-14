import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../models/eye_models.dart';

/// 动漫脸 YOLO（adetailer face_yolov8n）→ 眼点定位。
class AnimeEyeDetector {
  AnimeEyeDetector._(this._session);

  final OrtSession _session;
  static const _modelAsset = 'assets/models/anime_face_yolov8n.onnx';
  static const _anchors = 8400;

  static Future<AnimeEyeDetector> create() async {
    final ort = OnnxRuntime();
    final session = await ort.createSessionFromAsset(_modelAsset);
    return AnimeEyeDetector._(session);
  }

  Future<List<EyePair>> detect(
    LetterboxResult letterbox,
    img.Image prepared, {
    double confThreshold = 0.25,
  }) async {
    final input = await OrtValue.fromList(
      letterbox.tensor,
      const [1, 3, OverlayConstants.inputSize, OverlayConstants.inputSize],
    );
    try {
      final outputs = await _session.run({'images': input});
      final output = outputs.values.first;
      try {
        final flat = await output.asFlattenedList();
        final floats = Float32List(flat.length);
        for (var i = 0; i < flat.length; i++) {
          floats[i] = (flat[i] as num).toDouble();
        }
        return _parse(floats, letterbox, prepared, confThreshold);
      } finally {
        await output.dispose();
      }
    } finally {
      await input.dispose();
    }
  }

  List<EyePair> _parse(
    Float32List floats,
    LetterboxResult letterbox,
    img.Image prepared,
    double confThreshold,
  ) {
    double value(int channel, int index) => floats[channel * _anchors + index];

    final boxes = <_FaceBox>[];
    for (var i = 0; i < _anchors; i++) {
      final score = value(4, i);
      if (score < confThreshold) continue;
      final cx = value(0, i);
      final cy = value(1, i);
      final bw = value(2, i);
      final bh = value(3, i);
      final x1 = (cx - bw / 2 - letterbox.padLeft) / letterbox.scale;
      final y1 = (cy - bh / 2 - letterbox.padTop) / letterbox.scale;
      final x2 = (cx + bw / 2 - letterbox.padLeft) / letterbox.scale;
      final y2 = (cy + bh / 2 - letterbox.padTop) / letterbox.scale;
      boxes.add(_FaceBox(score: score, x1: x1, y1: y1, x2: x2, y2: y2));
    }

    boxes.sort((a, b) => b.score.compareTo(a.score));
    final kept = _nms(boxes, 0.45);
    if (kept.isEmpty) return const [];

    return [_localizeEyes(kept.first, prepared)];
  }

  List<_FaceBox> _nms(List<_FaceBox> boxes, double iouThreshold) {
    final remaining = List<_FaceBox>.from(boxes);
    final kept = <_FaceBox>[];
    while (remaining.isNotEmpty) {
      final cur = remaining.removeAt(0);
      kept.add(cur);
      remaining.removeWhere((other) => _iou(cur, other) >= iouThreshold);
    }
    return kept;
  }

  double _iou(_FaceBox a, _FaceBox b) {
    final x1 = math.max(a.x1, b.x1);
    final y1 = math.max(a.y1, b.y1);
    final x2 = math.min(a.x2, b.x2);
    final y2 = math.min(a.y2, b.y2);
    final inter = math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
    final areaA = math.max(0.0, a.x2 - a.x1) * math.max(0.0, a.y2 - a.y1);
    final areaB = math.max(0.0, b.x2 - b.x1) * math.max(0.0, b.y2 - b.y1);
    return inter / (areaA + areaB - inter + 1e-6);
  }

  EyePair _localizeEyes(_FaceBox face, img.Image prepared) {
    final x1 = math.max(0.0, face.x1);
    final y1 = math.max(0.0, face.y1);
    final x2 = math.min(prepared.width - 1.0, face.x2);
    final y2 = math.min(prepared.height - 1.0, face.y2);
    final fw = math.max(1.0, x2 - x1);
    final fh = math.max(1.0, y2 - y1);

    var left = ui.Offset(x1 + fw * 0.30, y1 + fh * 0.38);
    var right = ui.Offset(x1 + fw * 0.70, y1 + fh * 0.38);

    left = _refineEyeCenter(
      seed: left,
      roi: ui.Rect.fromLTWH(x1 + fw * 0.12, y1 + fh * 0.22, fw * 0.38, fh * 0.32),
      image: prepared,
    );
    right = _refineEyeCenter(
      seed: right,
      roi: ui.Rect.fromLTWH(x1 + fw * 0.50, y1 + fh * 0.22, fw * 0.38, fh * 0.32),
      image: prepared,
    );

    if (left.dx > right.dx) {
      final tmp = left;
      left = right;
      right = tmp;
    }

    final inter = hypot(right.dx - left.dx, right.dy - left.dy);
    final mid = ui.Offset((left.dx + right.dx) / 2, (left.dy + right.dy) / 2);
    final nose = ui.Offset(mid.dx, mid.dy + inter * 0.55);

    return EyePair(
      left: left,
      right: right,
      nose: nose,
      confidence: face.score,
      boxWidth: fw,
    );
  }

  ui.Offset _refineEyeCenter({
    required ui.Offset seed,
    required ui.Rect roi,
    required img.Image image,
  }) {
    final x0 = math.max(0, roi.left.floor());
    final y0 = math.max(0, roi.top.floor());
    final x1 = math.min(image.width - 1, roi.right.ceil());
    final y1 = math.min(image.height - 1, roi.bottom.ceil());
    if (x1 <= x0 || y1 <= y0) return seed;

    final luminances = <double>[];
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final p = image.getPixel(x, y);
        luminances.add(0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
      }
    }
    final sorted = List<double>.from(luminances)..sort();
    final thr = sorted[math.max(0, (sorted.length * 0.18).floor())];

    var wsum = 0.0;
    var sx = 0.0;
    var sy = 0.0;
    var idx = 0;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final lum = luminances[idx++];
        if (lum > thr) continue;
        final weight = math.max(1.0, thr - lum + 1);
        wsum += weight;
        sx += weight * x;
        sy += weight * y;
      }
    }
    if (wsum <= 0) return seed;
    final refined = ui.Offset(sx / wsum, sy / wsum);
    return ui.Offset(
      refined.dx * 0.65 + seed.dx * 0.35,
      refined.dy * 0.65 + seed.dy * 0.35,
    );
  }

  Future<void> close() => _session.close();
}

class _FaceBox {
  const _FaceBox({
    required this.score,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final double score;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
}
