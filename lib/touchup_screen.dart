import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

enum _BrushMode { erase, restore }

class TouchUpScreen extends StatefulWidget {
  final img.Image cutout; // RGBA, alpha = auto-detected mask
  final void Function(img.Image edited) onDone;

  const TouchUpScreen({super.key, required this.cutout, required this.onDone});

  @override
  State<TouchUpScreen> createState() => _TouchUpScreenState();
}

class _TouchUpScreenState extends State<TouchUpScreen> {
  late img.Image _working;
  late List<int> _originalAlpha; // alpha before any user edits, for "restore"
  Uint8List? _previewBytes;
  _BrushMode _mode = _BrushMode.erase;
  double _brushRadius = 30;

  @override
  void initState() {
    super.initState();
    _working = img.Image.from(widget.cutout);
    _originalAlpha = List<int>.filled(_working.width * _working.height, 255);
    for (var y = 0; y < _working.height; y++) {
      for (var x = 0; x < _working.width; x++) {
        _originalAlpha[y * _working.width + x] = _working.getPixel(x, y).a.round();
      }
    }
    _refreshPreview();
  }

  void _refreshPreview() {
    _previewBytes = Uint8List.fromList(img.encodePng(_working));
  }

  void _applyBrush(Offset localPos, Size widgetSize) {
    // Image is shown with BoxFit.contain — work out the scale + letterbox offset.
    final imgW = _working.width.toDouble();
    final imgH = _working.height.toDouble();
    final scale = (widgetSize.width / imgW < widgetSize.height / imgH)
        ? widgetSize.width / imgW
        : widgetSize.height / imgH;
    final renderedW = imgW * scale;
    final renderedH = imgH * scale;
    final offsetX = (widgetSize.width - renderedW) / 2;
    final offsetY = (widgetSize.height - renderedH) / 2;

    final imgX = ((localPos.dx - offsetX) / scale);
    final imgY = ((localPos.dy - offsetY) / scale);
    if (imgX < 0 || imgY < 0 || imgX >= imgW || imgY >= imgH) return;

    final radiusInImageSpace = _brushRadius / scale;
    final r2 = radiusInImageSpace * radiusInImageSpace;
    final minX = (imgX - radiusInImageSpace).floor().clamp(0, _working.width - 1);
    final maxX = (imgX + radiusInImageSpace).ceil().clamp(0, _working.width - 1);
    final minY = (imgY - radiusInImageSpace).floor().clamp(0, _working.height - 1);
    final maxY = (imgY + radiusInImageSpace).ceil().clamp(0, _working.height - 1);

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final dx = x - imgX;
        final dy = y - imgY;
        if (dx * dx + dy * dy > r2) continue;
        final p = _working.getPixel(x, y);
        final newAlpha = _mode == _BrushMode.erase
            ? 0
            : _originalAlpha[y * _working.width + x];
        _working.setPixelRgba(x, y, p.r, p.g, p.b, newAlpha);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Touch Up'),
        actions: [
          TextButton(
            onPressed: () => widget.onDone(_working),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _mode == _BrushMode.erase
                  ? 'Brush over any background bits still showing'
                  : 'Brush to bring back any part erased by mistake',
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFBDBDBD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    onPanStart: (d) => setState(() {
                      _applyBrush(d.localPosition, size);
                      _refreshPreview();
                    }),
                    onPanUpdate: (d) => setState(() {
                      _applyBrush(d.localPosition, size);
                      _refreshPreview();
                    }),
                    child: _previewBytes == null
                        ? const SizedBox.shrink()
                        : Image.memory(_previewBytes!, fit: BoxFit.contain, gaplessPlayback: true),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.brush, size: 18),
                    Expanded(
                      child: Slider(
                        value: _brushRadius,
                        min: 8,
                        max: 80,
                        onChanged: (v) => setState(() => _brushRadius = v),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Erase'),
                        selected: _mode == _BrushMode.erase,
                        onSelected: (_) => setState(() => _mode = _BrushMode.erase),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Restore'),
                        selected: _mode == _BrushMode.restore,
                        onSelected: (_) => setState(() => _mode = _BrushMode.restore),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
