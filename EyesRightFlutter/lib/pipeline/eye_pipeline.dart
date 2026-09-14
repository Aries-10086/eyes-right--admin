import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../inference/anime_eye_detector.dart';
import '../inference/pose_detector.dart';
import '../models/eye_models.dart';
import 'eye_composer.dart';
import 'image_codec.dart';
import 'nose_pose_detector.dart';

class EyePipeline {
  EyePipeline._({
    required PoseDetector detector,
    required AnimeEyeDetector animeDetector,
    required NosePoseDetector noseDetector,
    required ui.Image dualOverlay,
    required ui.Image guangOverlay,
    required ui.Image clownNoseOverlay,
  })  : _detector = detector,
        _animeDetector = animeDetector,
        _noseDetector = noseDetector,
        _dualOverlay = dualOverlay,
        _guangOverlay = guangOverlay,
        _clownNoseOverlay = clownNoseOverlay;

  final PoseDetector _detector;
  final AnimeEyeDetector _animeDetector;
  final NosePoseDetector _noseDetector;
  final ui.Image _dualOverlay;
  final ui.Image _guangOverlay;
  final ui.Image _clownNoseOverlay;

  static Future<EyePipeline> create() async {
    final detector = await PoseDetector.create();
    final animeDetector = await AnimeEyeDetector.create();
    final noseDetector = await NosePoseDetector.create();
    final dual = await _loadAssetImage('assets/overlays/IMG_20260819_142559_cutout.png');
    final guang = await _loadAssetImage('assets/overlays/guang_overlay.jpg');
    final clown = await _loadAssetImage('assets/overlays/clown_nose.png');
    return EyePipeline._(
      detector: detector,
      animeDetector: animeDetector,
      noseDetector: noseDetector,
      dualOverlay: dual,
      guangOverlay: guang,
      clownNoseOverlay: clown,
    );
  }

  static Future<ui.Image> _loadAssetImage(String asset) async {
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<Uint8List> processBytes(
    Uint8List bytes,
    OverlayMode mode, {
    FaceKind faceKind = FaceKind.pet,
  }) async {
    final prepared = ImageCodec.decodePrepared(bytes);
    final letterbox = ImageCodec.letterbox(prepared);
    final pairs = faceKind.usesAnimeDetector
        ? await _animeDetector.detect(letterbox, prepared)
        : await _detector.detect(letterbox);
    if (pairs.isEmpty) {
      throw PipelineException('未检测到脸或眼点，请换更清晰的正脸照片');
    }

    final base = await ImageCodec.toUiImage(prepared);
    try {
      final raw = pairs.first;
      final pair = mode == OverlayMode.clownNose
          ? await _noseDetector.refine(raw, prepared)
          : raw;
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
        case OverlayMode.clownNose:
          result = await EyeComposer.applyClownNose(
            base: base,
            sticker: _clownNoseOverlay,
            pair: pair,
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

  /// Debug helper: return prepared image with eye/nose dots drawn.
  Future<Uint8List> debugKeypoints(Uint8List bytes) async {
    final prepared = ImageCodec.decodePrepared(bytes);
    final letterbox = ImageCodec.letterbox(prepared);
    final pairs = await _detector.detect(letterbox);
    final copy = img.Image.from(prepared);
    for (final pair in pairs) {
      final refined = await _noseDetector.refine(pair, prepared);
      img.fillCircle(copy, x: refined.left.dx.round(), y: refined.left.dy.round(), radius: 6, color: img.ColorRgb8(0, 255, 0));
      img.fillCircle(copy, x: refined.right.dx.round(), y: refined.right.dy.round(), radius: 6, color: img.ColorRgb8(255, 0, 0));
      img.fillCircle(copy, x: refined.nose.dx.round(), y: refined.nose.dy.round(), radius: 6, color: img.ColorRgb8(0, 160, 255));
    }
    return Uint8List.fromList(img.encodePng(copy));
  }

  Future<void> dispose() async {
    await _detector.close();
    await _animeDetector.close();
    await _noseDetector.close();
    _dualOverlay.dispose();
    _guangOverlay.dispose();
    _clownNoseOverlay.dispose();
  }
}
