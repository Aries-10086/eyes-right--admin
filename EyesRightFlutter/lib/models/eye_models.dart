import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Align with Mac `OverlayConstants` / `EyePair` / `OverlayMode`.
enum OverlayMode {
  ahAhAh('啊啊啊'),
  addLight('加一道光');

  const OverlayMode(this.label);
  final String label;
}

class EyePair {
  const EyePair({
    required this.left,
    required this.right,
    required this.confidence,
    required this.boxWidth,
  });

  final ui.Offset left;
  final ui.Offset right;
  final double confidence;
  final double boxWidth;
}

class OverlayConstants {
  static const leftEye = ui.Offset(200, 220);
  static const rightEye = ui.Offset(671, 228);
  static const totalWidth = 863.0;
  static const coverage = 0.72;
  static const confThreshold = 0.15;
  static const perEyeHalfSpanFromBox = 0.20;
  static const perEyeSpreadBoost = 1.12;
  static const perEyeCoverRatio = 1.05;
  static const perEyeMaxWidthByHalfSpan = 1.35;
  static const maxLongEdge = 2048;
  static const inputSize = 640;
}

class LetterboxResult {
  LetterboxResult({
    required this.tensor,
    required this.scale,
    required this.padLeft,
    required this.padTop,
    required this.originalWidth,
    required this.originalHeight,
  });

  /// NCHW float32, length 3*640*640
  final Float32List tensor;
  final double scale;
  final double padLeft;
  final double padTop;
  final int originalWidth;
  final int originalHeight;

  ui.Offset mapToOriginal(ui.Offset point) {
    return ui.Offset(
      (point.dx - padLeft) / scale,
      (point.dy - padTop) / scale,
    );
  }
}

class PipelineException implements Exception {
  PipelineException(this.message);
  final String message;

  @override
  String toString() => message;
}

double hypot(double x, double y) => math.sqrt(x * x + y * y);
