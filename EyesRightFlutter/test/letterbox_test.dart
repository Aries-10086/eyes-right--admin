import 'dart:ui' show Offset;

import 'package:eyes_right_flutter/pipeline/image_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('letterbox produces 640 NCHW tensor with gray pad', () {
    final src = img.Image(width: 320, height: 160);
    img.fill(src, color: img.ColorRgb8(255, 0, 0));
    final lb = ImageCodec.letterbox(src);
    expect(lb.tensor.length, 3 * 640 * 640);
    expect(lb.originalWidth, 320);
    expect(lb.originalHeight, 160);
    expect(lb.scale, closeTo(2.0, 1e-6));
    final mapped = lb.mapToOriginal(const Offset(320, 320));
    expect(mapped.dx, closeTo(160, 2));
    expect(mapped.dy, closeTo(80, 2));
  });
}
