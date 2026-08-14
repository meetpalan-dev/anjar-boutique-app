import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'checkerboard.dart';

enum _BrushMode { erase, restore }

class TouchUpScreen extends StatefulWidget {
  final img.Image cutout;
  final void Function(img.Image edited) onDone;

  const TouchUpScreen({super.key, required this.cutout, required this.onDone});

  @override
  State<TouchUpScreen> createState() => _TouchUpScreenState();
}

class _TouchUpScreenState extends State<TouchUpScreen> {
  static const int _maxUndoSteps = 100;

  ui.Image? _original; // pristine, used to "restore" pixels
  ui.Image? _current; // committed state (after the last finished stroke)
  final List<ui.Image> _undoStack = [];
  final List<ui.Image> _redoStack = [];

  // Points of the stroke currently being drawn (image-space coordinates),
  // repainted every frame via CustomPaint — no Dart-side pixel mutation
  // happens until the stroke is committed.
  final List<Offset> _liveStrokePoints = [];
  bool _loading = true;
  bool _committing = false;

  _BrushMode _mode = _BrushMode.erase;
  double _brushRadius = 30;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final pngBytes = Uint8List.fromList(img.encodePng(widget.cutout));
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    // Two independent decodes so `_original` and `_current` are distinct
    // GPU-side images (never share mutation).
    final codec2 = await ui.instantiateImageCodec(pngBytes);
    final frame2 = await codec2.getNextFrame();
    if (!mounted) return;
    setState(() {
      _original = frame.image;
      _current = frame2.image;
      _loading = false;
    });
  }

  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

  void _pushUndo(ui.Image previous) {
    _undoStack.add(previous);
    if (_undoStack.length > _maxUndoSteps) {
      // drop the oldest — dispose it so its GPU texture is released
      _undoStack.removeAt(0).dispose();
    }
    for (final img in _redoStack) {
      img.dispose();
    }
    _redoStack.clear();
  }

  void _undo() {
    if (!_canUndo || _current == null) return;
    setState(() {
      _redoStack.add(_current!);
      _current = _undoStack.removeLast();
    });
  }

  void _redo() {
    if (!_canRedo || _current == null) return;
    setState(() {
      _undoStack.add(_current!);
      _current = _redoStack.removeLast();
    });
  }

  /// Bakes the current live stroke (if any) into a new committed ui.Image.
  Future<void> _commitStroke() async {
    if (_liveStrokePoints.isEmpty || _current == null || _original == null) {
      _liveStrokePoints.clear();
      return;
    }
    setState(() => _committing = true);

    final w = _current!.width, h = _current!.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintEdit(canvas, _current!, _original!, _liveStrokePoints, _mode, _brushRadius);
    final picture = recorder.endRecording();
    final newImage = await picture.toImage(w, h);

    final previous = _current!;
    setState(() {
      _pushUndo(previous);
      _current = newImage;
      _liveStrokePoints.clear();
      _committing = false;
    });
  }

  /// Draws [base] with the stroke's erase/restore effect baked in — no
  /// decorative overlay here, this is the "real pixels" pass only.
  static void _paintEdit(Canvas canvas, ui.Image base, ui.Image original,
      List<Offset> points, _BrushMode mode, double radius) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()), Paint());
    canvas.drawImage(base, Offset.zero, Paint());
    for (final p in points) {
      if (mode == _BrushMode.erase) {
        canvas.drawCircle(p, radius, Paint()..blendMode = BlendMode.clear);
      } else {
        canvas.save();
        final path = Path()..addOval(Rect.fromCircle(center: p, radius: radius));
        canvas.clipPath(path);
        canvas.drawImage(original, Offset.zero, Paint());
        canvas.restore();
      }
    }
    canvas.restore();
  }

  Future<img.Image> _exportAsImgImage() async {
    final current = _current!;
    final byteData = await current.toByteData(format: ui.ImageByteFormat.rawRgba);
    return img.Image.fromBytes(
      width: current.width,
      height: current.height,
      bytes: byteData!.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  Future<void> _tapDone() async {
    await _commitStroke();
    if (!mounted) return;
    final result = await _exportAsImgImage();
    widget.onDone(result);
  }

  @override
  void dispose() {
    _original?.dispose();
    _current?.dispose();
    for (final i in _undoStack) {
      i.dispose();
    }
    for (final i in _redoStack) {
      i.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Touch Up'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _canUndo ? _undo : null,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _canRedo ? _redo : null,
            tooltip: 'Redo',
          ),
          TextButton(
            onPressed: _loading || _committing ? null : _tapDone,
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _mode == _BrushMode.erase
                        ? 'Brush over any background bits still showing — pinch to zoom'
                        : 'Brush to bring back anything erased by mistake — pinch to zoom',
                    style: const TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                    child: Checkerboard(
                      // panEnabled: false so a single finger is always free
                      // for painting; pinch (2 fingers) still zooms.
                      child: InteractiveViewer(
                        panEnabled: false,
                        scaleEnabled: true,
                        minScale: 0.5,
                        maxScale: 6,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _current!.width / _current!.height,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final scale = constraints.maxWidth / _current!.width;
                                return GestureDetector(
                                  onPanDown: (d) => setState(() {
                                    _liveStrokePoints.add(d.localPosition / scale);
                                  }),
                                  onPanUpdate: (d) => setState(() {
                                    _liveStrokePoints.add(d.localPosition / scale);
                                  }),
                                  onPanEnd: (_) => _commitStroke(),
                                  child: CustomPaint(
                                    size: Size(constraints.maxWidth, constraints.maxWidth / (_current!.width / _current!.height)),
                                    painter: _LiveEditPainter(
                                      base: _current!,
                                      original: _original!,
                                      strokePoints: _liveStrokePoints,
                                      mode: _mode,
                                      radius: _brushRadius,
                                      displayScale: scale,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
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
                              max: 100,
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
                              selectedColor: const Color(0xFFFBD9D5),
                              onSelected: (_) => setState(() => _mode = _BrushMode.erase),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Restore'),
                              selected: _mode == _BrushMode.restore,
                              selectedColor: const Color(0xFFCDEBDD),
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

/// Renders [base] with the in-progress stroke's edit applied live, PLUS a
/// clearly visible red (erase) / green (restore) overlay on top so the user
/// can see exactly what's being touched. The overlay is drawn in this
/// widget only — it is never baked into the committed image.
class _LiveEditPainter extends CustomPainter {
  final ui.Image base;
  final ui.Image original;
  final List<Offset> strokePoints;
  final _BrushMode mode;
  final double radius;
  final double displayScale;

  _LiveEditPainter({
    required this.base,
    required this.original,
    required this.strokePoints,
    required this.mode,
    required this.radius,
    required this.displayScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(displayScale);

    // 1) real edit preview (what will actually be committed)
    canvas.saveLayer(Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()), Paint());
    canvas.drawImage(base, Offset.zero, Paint());
    for (final p in strokePoints) {
      if (mode == _BrushMode.erase) {
        canvas.drawCircle(p, radius, Paint()..blendMode = BlendMode.clear);
      } else {
        canvas.save();
        final path = Path()..addOval(Rect.fromCircle(center: p, radius: radius));
        canvas.clipPath(path);
        canvas.drawImage(original, Offset.zero, Paint());
        canvas.restore();
      }
    }
    canvas.restore();

    // 2) decorative overlay — obvious color, drawn on top, purely visual
    final overlayColor = mode == _BrushMode.erase
        ? const Color(0x99E0453D) // translucent red
        : const Color(0x992F9E6E); // translucent green
    final overlayPaint = Paint()..color = overlayColor;
    for (final p in strokePoints) {
      canvas.drawCircle(p, radius, overlayPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiveEditPainter oldDelegate) => true;
}
