import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../models/eye_models.dart';

class ImageCodec {
  /// Decode bytes, bake EXIF orientation, optionally shrink long edge.
  static img.Image decodePrepared(Uint8List bytes, {int maxLongEdge = OverlayConstants.maxLongEdge}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw PipelineException('无法读取图片');
    }
    var image = img.bakeOrientation(decoded);
    final longEdge = image.width > image.height ? image.width : image.height;
    if (longEdge > maxLongEdge) {
      final scale = maxLongEdge / longEdge;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }
    return image.convert(numChannels: 4);
  }

  static Future<ui.Image> toUiImage(img.Image image) async {
    final rgba = image.convert(numChannels: 4);
    final bytes = Uint8List.fromList(rgba.getBytes(order: img.ChannelOrder.rgba));
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: rgba.width,
      height: rgba.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<Uint8List> encodePng(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw PipelineException('导出图片失败');
    }
    return data.buffer.asUint8List();
  }

  /// Letterbox to 640×640 NCHW RGB float (matches Ultralytics / Mac).
  static LetterboxResult letterbox(img.Image image, {int targetSize = OverlayConstants.inputSize}) {
    final width = image.width;
    final height = image.height;
    final scale = (targetSize / height < targetSize / width)
        ? targetSize / height
        : targetSize / width;
    final newWidth = (width * scale).round();
    final newHeight = (height * scale).round();
    final padLeft = (targetSize - newWidth) ~/ 2;
    final padTop = (targetSize - newHeight) ~/ 2;

    final resized = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );

    final plane = targetSize * targetSize;
    final tensor = Float32List(3 * plane);
    const gray = 114 / 255.0;
    for (var i = 0; i < plane; i++) {
      tensor[i] = gray;
      tensor[plane + i] = gray;
      tensor[2 * plane + i] = gray;
    }

    for (var y = 0; y < newHeight; y++) {
      for (var x = 0; x < newWidth; x++) {
        final p = resized.getPixel(x, y);
        final dx = x + padLeft;
        final dy = y + padTop;
        final idx = dy * targetSize + dx;
        tensor[idx] = p.r / 255.0;
        tensor[plane + idx] = p.g / 255.0;
        tensor[2 * plane + idx] = p.b / 255.0;
      }
    }

    return LetterboxResult(
      tensor: tensor,
      scale: scale,
      padLeft: padLeft.toDouble(),
      padTop: padTop.toDouble(),
      originalWidth: width,
      originalHeight: height,
    );
  }
}
