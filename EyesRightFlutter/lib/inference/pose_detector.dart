import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../models/eye_models.dart';

class PoseDetector {
  PoseDetector._(this._session);

  final OrtSession _session;
  static const _modelAsset = 'assets/models/pet_eye_best.onnx';
  static const _anchors = 8400;

  static Future<PoseDetector> create() async {
    final ort = OnnxRuntime();
    final session = await ort.createSessionFromAsset(_modelAsset);
    return PoseDetector._(session);
  }

  Future<List<EyePair>> detect(LetterboxResult letterbox, {double confThreshold = OverlayConstants.confThreshold}) async {
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
        return _parse(floats, letterbox, confThreshold);
      } finally {
        await output.dispose();
      }
    } finally {
      await input.dispose();
    }
  }

  List<EyePair> _parse(Float32List floats, LetterboxResult letterbox, double confThreshold) {
    double value(int channel, int index) => floats[channel * _anchors + index];

    var bestScore = -1.0;
    var bestW = 0.0;
    final bestKpts = <(ui.Offset, double)>[];

    for (var index = 0; index < _anchors; index++) {
      final score = value(4, index);
      if (score < confThreshold || score <= bestScore) continue;

      bestScore = score;
      bestW = value(2, index);
      bestKpts
        ..clear()
        ..addAll(
          List.generate(3, (k) {
            final channel = 5 + k * 3;
            final mapped = letterbox.mapToOriginal(
              ui.Offset(value(channel, index), value(channel + 1, index)),
            );
            return (mapped, value(channel + 2, index));
          }),
        );
    }

    if (bestScore < 0 || bestKpts.length < 2) {
      return const [];
    }

    var left = bestKpts[0].$1;
    var right = bestKpts[1].$1;
    if (left.dx > right.dx) {
      final tmp = left;
      left = right;
      right = tmp;
    }

    final kptConf = bestKpts[0].$2 < bestKpts[1].$2 ? bestKpts[0].$2 : bestKpts[1].$2;
    return [
      EyePair(
        left: left,
        right: right,
        confidence: bestScore < kptConf ? bestScore : kptConf,
        boxWidth: bestW / letterbox.scale,
      ),
    ];
  }

  Future<void> close() => _session.close();
}
