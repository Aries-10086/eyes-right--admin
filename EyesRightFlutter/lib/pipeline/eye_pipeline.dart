import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../inference/pose_detector.dart';
import '../models/eye_models.dart';
import 'eye_composer.dart';
import 'image_codec.dart';

class EyePipeline {
  EyePipeline._({
    required PoseDetector detector,
    required ui.Image dualOverlay,
    required ui.Image guangOverlay,
  })  : _detector = detector,
        _dualOverlay = dualOverlay,
        _guangOverlay = guangOverlay;

  final PoseDetector _detector;
  final ui.Image _dualOverlay;
  final ui.Image _guangOverlay;

  static Future<EyePipeline> create() async {
    final detector = await PoseDetector.create();
    final dual = await _loadAssetImage('assets/overlays/IMG_20260819_142559_cutout.png');
    final guang = await _loadAssetImage('assets/overlays/guang_overlay.jpg');
    return EyePipeline._(
      detector: detector,
      dualOverlay: dual,
      guangOverlay: guang,
    );
  }

  static Future<ui.Image> _loadAssetImage(String asset) async {
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<Uint8List> processBytes(Uint8List bytes, OverlayMode mode) async {
    final prepared = ImageCodec.decodePrepared(bytes);
    final letterbox = ImageCodec.letterbox(prepared);
    final pairs = await _detector.detect(letterbox);
    if (pairs.isEmpty) {
      throw PipelineException('未检测到猫/狗脸或眼点，请换更清晰正脸照片');
    }

    final base = await ImageCodec.toUiImage(prepared);
    try {
      final pair = pairs.first;
      final ui.Image result;
      switch (mode) {
        case OverlayMode.ahAhAh:
          result = await EyeComposer.apply(
            base: base,
            overlay: _dualOverlay,
            pair: pair,
          );
        case OverlayMode.addLight:
          result = await EyeComposer.applyPerEye(
            base: base,
            sticker: _guangOverlay,
            pair: pair,
            mirrorRight: false,
          );
      }
      try {
        return await ImageCodec.encodePng(result);
      } finally {
        result.dispose();
      }
    } finally {
      base.dispose();
    }
  }

  /// Debug helper: return prepared image with eye dots drawn.
  Future<Uint8List> debugKeypoints(Uint8List bytes) async {
    final prepared = ImageCodec.decodePrepared(bytes);
    final letterbox = ImageCodec.letterbox(prepared);
    final pairs = await _detector.detect(letterbox);
    final copy = img.Image.from(prepared);
    for (final pair in pairs) {
      img.fillCircle(copy, x: pair.left.dx.round(), y: pair.left.dy.round(), radius: 6, color: img.ColorRgb8(0, 255, 0));
      img.fillCircle(copy, x: pair.right.dx.round(), y: pair.right.dy.round(), radius: 6, color: img.ColorRgb8(255, 0, 0));
    }
    return Uint8List.fromList(img.encodePng(copy));
  }

  Future<void> dispose() async {
    await _detector.close();
    _dualOverlay.dispose();
    _guangOverlay.dispose();
  }
}
