import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Matrix4;

import '../models/eye_models.dart';

/// Overlay compositing in Flutter top-left space (aligned with Mac rules).
class EyeComposer {
  static Future<ui.Image> apply({
    required ui.Image base,
    required ui.Image overlay,
    required EyePair pair,
    double coverage = OverlayConstants.coverage,
  }) async {
    var scaleBoost = 1.0;
    if (pair.boxWidth > 0) {
      final interOverlay = hypot(
        OverlayConstants.rightEye.dx - OverlayConstants.leftEye.dx,
        OverlayConstants.rightEye.dy - OverlayConstants.leftEye.dy,
      );
      final interReal = math.max(
        hypot(pair.right.dx - pair.left.dx, pair.right.dy - pair.left.dy),
        1e-6,
      );
      final desiredWidth = pair.boxWidth * coverage;
      final baseScale = interReal / interOverlay;
      final neededScale = desiredWidth / OverlayConstants.totalWidth;
      scaleBoost = neededScale / baseScale;
    }

    final matrix = _similarityTransform(
      srcLeft: OverlayConstants.leftEye,
      srcRight: OverlayConstants.rightEye,
      dstLeft: pair.left,
      dstRight: pair.right,
      scaleBoost: scaleBoost,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(base, ui.Offset.zero, ui.Paint());
    canvas.transform(matrix.storage);
    canvas.drawImage(overlay, ui.Offset.zero, ui.Paint());
    final picture = recorder.endRecording();
    return picture.toImage(base.width, base.height);
  }

  static Future<ui.Image> applyPerEye({
    required ui.Image base,
    required ui.Image sticker,
    required EyePair pair,
    bool mirrorRight = false,
  }) async {
    final dx = pair.right.dx - pair.left.dx;
    final dy = pair.right.dy - pair.left.dy;
    final interEye = math.max(hypot(dx, dy), 1e-6);
    final mid = ui.Offset(
      (pair.left.dx + pair.right.dx) / 2,
      (pair.left.dy + pair.right.dy) / 2,
    );
    final dir = ui.Offset(dx / interEye, dy / interEye);

    final halfFromEyes = interEye * 0.5;
    final halfFromBox = pair.boxWidth > 0
        ? pair.boxWidth * OverlayConstants.perEyeHalfSpanFromBox
        : halfFromEyes;
    final halfSpan =
        math.max(halfFromEyes, halfFromBox) * OverlayConstants.perEyeSpreadBoost;

    final leftCenter = ui.Offset(
      mid.dx - dir.dx * halfSpan,
      mid.dy - dir.dy * halfSpan,
    );
    final rightCenter = ui.Offset(
      mid.dx + dir.dx * halfSpan,
      mid.dy + dir.dy * halfSpan,
    );

    final coverWidth = halfSpan * OverlayConstants.perEyeCoverRatio;
    final maxWidth = halfSpan * OverlayConstants.perEyeMaxWidthByHalfSpan;
    final targetWidth = math.min(math.max(coverWidth, halfSpan * 0.85), maxWidth);
    final scale = targetWidth / sticker.width;
    final angle = math.atan2(dy, dx);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(base, ui.Offset.zero, ui.Paint());
    _drawSticker(canvas, sticker, leftCenter, scale, angle, false);
    _drawSticker(canvas, sticker, rightCenter, scale, angle, mirrorRight);
    final picture = recorder.endRecording();
    return picture.toImage(base.width, base.height);
  }

  static void _drawSticker(
    ui.Canvas canvas,
    ui.Image sticker,
    ui.Offset center,
    double scale,
    double angle,
    bool mirror,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(mirror ? -scale : scale, scale);
    canvas.drawImage(
      sticker,
      ui.Offset(-sticker.width / 2, -sticker.height / 2),
      ui.Paint(),
    );
    canvas.restore();
  }

  static Matrix4 _similarityTransform({
    required ui.Offset srcLeft,
    required ui.Offset srcRight,
    required ui.Offset dstLeft,
    required ui.Offset dstRight,
    required double scaleBoost,
  }) {
    final srcCenter = ui.Offset(
      (srcLeft.dx + srcRight.dx) / 2,
      (srcLeft.dy + srcRight.dy) / 2,
    );
    final dstCenter = ui.Offset(
      (dstLeft.dx + dstRight.dx) / 2,
      (dstLeft.dy + dstRight.dy) / 2,
    );

    final srcVx = srcRight.dx - srcLeft.dx;
    final srcVy = srcRight.dy - srcLeft.dy;
    final dstVx = dstRight.dx - dstLeft.dx;
    final dstVy = dstRight.dy - dstLeft.dy;

    final srcDistance = math.max(hypot(srcVx, srcVy), 1e-6);
    final dstDistance = hypot(dstVx, dstVy) * scaleBoost;
    final scale = dstDistance / srcDistance;

    final srcAngle = math.atan2(srcVy, srcVx);
    final dstAngle = math.atan2(dstVy, dstVx);
    final angle = dstAngle - srcAngle;

    final cosA = math.cos(angle) * scale;
    final sinA = math.sin(angle) * scale;
    final tx = dstCenter.dx - (cosA * srcCenter.dx - sinA * srcCenter.dy);
    final ty = dstCenter.dy - (sinA * srcCenter.dx + cosA * srcCenter.dy);

    // Column-major Matrix4 matching CGAffineTransform(a,b,c,d,tx,ty)
    // with c = -sinA, d = cosA
    return Matrix4(
      cosA, sinA, 0, 0,
      -sinA, cosA, 0, 0,
      0, 0, 1, 0,
      tx, ty, 0, 1,
    );
  }
}
