import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

/// Runs the U2Net saliency model on [photo] and returns a copy of [photo]
/// as an RGBA image where the alpha channel encodes "how likely this pixel
/// is foreground" (0 = fully background/transparent, 255 = fully subject).
///
/// This is a *soft* mask straight from the model — no thresholding — so the
/// touch-up screen can still see faint edges to clean up if needed.
class BackgroundRemover {
  static const int _modelSize = 320; // U2Net's expected input resolution
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  static OrtSession? _session;

  static Future<OrtSession> _getSession() async {
    if (_session != null) return _session!;
    OrtEnv.instance.init();
    final modelBytes = (await rootBundle.load('assets/models/u2net.onnx'))
        .buffer
        .asUint8List();
    final options = OrtSessionOptions();
    _session = OrtSession.fromBuffer(modelBytes, options);
    return _session!;
  }

  static Future<img.Image> cutout(img.Image photo) async {
    final session = await _getSession();

    // --- Preprocess: resize to 320x320, normalize, NCHW float32 ---
    final resized = img.copyResize(
      photo,
      width: _modelSize,
      height: _modelSize,
      interpolation: img.Interpolation.linear,
    );

    final input = Float32List(1 * 3 * _modelSize * _modelSize);
    var idx = 0;
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < _modelSize; y++) {
        for (var x = 0; x < _modelSize; x++) {
          final pixel = resized.getPixel(x, y);
          final channelVal = c == 0 ? pixel.r : (c == 1 ? pixel.g : pixel.b);
          final normalized = (channelVal / 255.0 - _mean[c]) / _std[c];
          input[idx++] = normalized;
        }
      }
    }

    final inputName = session.inputNames.first;
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      input,
      [1, 3, _modelSize, _modelSize],
    );
    final outputs = await session.runAsync(
      OrtRunOptions(),
      {inputName: inputTensor},
    );
    inputTensor.release();

    final outputTensor = outputs?.first;
    final raw = outputTensor?.value;
    outputTensor?.release();

    if (raw == null) {
      throw Exception('U2Net produced no output — check model input/output names.');
    }

    // Output is [1, 1, 320, 320]; flatten whatever nested-list shape comes back.
    final flat = _flatten(raw);

    // Min-max normalize to 0..1
    double minV = flat.first, maxV = flat.first;
    for (final v in flat) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);

    final maskSmall = img.Image(width: _modelSize, height: _modelSize);
    var i = 0;
    for (var y = 0; y < _modelSize; y++) {
      for (var x = 0; x < _modelSize; x++) {
        final norm = ((flat[i] - minV) / range).clamp(0.0, 1.0);
        final a = (norm * 255).round();
        maskSmall.setPixelRgba(x, y, a, a, a, 255);
        i++;
      }
    }

    // Resize mask back up to the original photo's resolution.
    final maskFull = img.copyResize(
      maskSmall,
      width: photo.width,
      height: photo.height,
      interpolation: img.Interpolation.linear,
    );

    // IMPORTANT: convert() returns a *new* image rather than mutating in
    // place — it must be reassigned, or the result silently keeps whatever
    // channel count `photo` started with (usually 3, no alpha), which means
    // every pixel below gets its alpha argument thrown away and the cutout
    // stays fully opaque no matter what the mask says.
    var result = img.Image.from(photo);
    result = result.convert(numChannels: 4);
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final p = result.getPixel(x, y);
        final maskVal = maskFull.getPixel(x, y).r;
        result.setPixelRgba(x, y, p.r, p.g, p.b, maskVal.round());
      }
    }

    return result;
  }

  /// Fraction of pixels (0..1) whose alpha is above a "clearly foreground"
  /// threshold. Used right after cutout to catch a failed/near-blank mask
  /// (e.g. a busy or low-contrast background the model couldn't separate)
  /// before it silently turns into an empty product photo later on.
  static double foregroundCoverage(img.Image cutout) {
    var count = 0;
    final total = cutout.width * cutout.height;
    for (var y = 0; y < cutout.height; y++) {
      for (var x = 0; x < cutout.width; x++) {
        if (cutout.getPixel(x, y).a > 40) count++;
      }
    }
    return total == 0 ? 0 : count / total;
  }

  static List<double> _flatten(dynamic nested) {
    final out = <double>[];
    void go(dynamic v) {
      if (v is List) {
        for (final e in v) {
          go(e);
        }
      } else if (v is num) {
        out.add(v.toDouble());
      }
    }
    go(nested);
    return out;
  }
}
