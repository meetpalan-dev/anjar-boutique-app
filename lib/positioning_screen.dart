import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'templates.dart';
import 'main.dart' show DetailsFormScreen;

class PositioningScreen extends StatefulWidget {
  final img.Image cutout;
  const PositioningScreen({super.key, required this.cutout});

  @override
  State<PositioningScreen> createState() => _PositioningScreenState();
}

class _PositioningScreenState extends State<PositioningScreen> {
  TemplateOption _selectedTemplate = availableTemplates.first;
  final Map<String, img.Image> _templateCache = {};

  late Uint8List _cutoutPngBytes;
  bool _loading = true;
  String? _error;

  // All in TEMPLATE-PIXEL space (not screen pixels) — this is also exactly
  // what gets used for the final export, so preview and output always match.
  Offset _cutoutCenter = Offset.zero;
  double _cutoutScale = 1.0;
  bool _showGrid = true;

  // gesture bookkeeping
  Offset _gestureStartFocal = Offset.zero;
  Offset _gestureStartCenter = Offset.zero;
  double _gestureStartScale = 1.0;

  @override
  void initState() {
    super.initState();
    _cutoutPngBytes = Uint8List.fromList(img.encodePng(widget.cutout));
    _loadTemplate(_selectedTemplate);
  }

  Future<img.Image> _decodeTemplate(String assetPath) async {
    if (_templateCache.containsKey(assetPath)) return _templateCache[assetPath]!;
    final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
    final decoded = img.decodeImage(bytes)!;
    _templateCache[assetPath] = decoded;
    return decoded;
  }

  Future<void> _loadTemplate(TemplateOption template) async {
    setState(() => _loading = true);
    try {
      final tpl = await _decodeTemplate(template.assetPath);
      // Default: cutout centered, scaled to fit comfortably within the
      // template (about 70% of the shorter template dimension).
      final fitScale = (tpl.width * 0.7 / widget.cutout.width)
          .clamp(0.01, tpl.height * 0.7 / widget.cutout.height);
      if (!mounted) return;
      setState(() {
        _selectedTemplate = template;
        _cutoutCenter = Offset(tpl.width / 2, tpl.height / 2);
        _cutoutScale = fitScale.toDouble();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Alignment controls: move the cutout's CENTER to the template's center
  // on the given axis (or both), preserving scale exactly. Uses the cached
  // decoded template — already loaded by the time these buttons are visible
  // — and writes to the same _cutoutCenter the exporter reads from, so the
  // preview and the final Ready to Post image always agree.
  void _centerHorizontally() {
    final tpl = _templateCache[_selectedTemplate.assetPath];
    if (tpl == null) return;
    setState(() => _cutoutCenter = Offset(tpl.width / 2, _cutoutCenter.dy));
  }

  void _centerVertically() {
    final tpl = _templateCache[_selectedTemplate.assetPath];
    if (tpl == null) return;
    setState(() => _cutoutCenter = Offset(_cutoutCenter.dx, tpl.height / 2));
  }

  void _centerBoth() {
    final tpl = _templateCache[_selectedTemplate.assetPath];
    if (tpl == null) return;
    setState(() => _cutoutCenter = Offset(tpl.width / 2, tpl.height / 2));
  }

  Future<void> _tapContinue() async {
    setState(() => _loading = true);
    try {
      final tpl = await _decodeTemplate(_selectedTemplate.assetPath);
      final canvas = img.Image.from(tpl);

      final scaledW = (widget.cutout.width * _cutoutScale).round().clamp(1, 20000);
      final scaledH = (widget.cutout.height * _cutoutScale).round().clamp(1, 20000);
      final resizedCutout = img.copyResize(
        widget.cutout,
        width: scaledW,
        height: scaledH,
        interpolation: img.Interpolation.average,
      );

      final pasteX = (_cutoutCenter.dx - scaledW / 2).round();
      final pasteY = (_cutoutCenter.dy - scaledH / 2).round();
      img.compositeImage(canvas, resizedCutout, dstX: pasteX, dstY: pasteY);

      final composited = Uint8List.fromList(img.encodePng(canvas));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailsFormScreen(composited: composited)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickTemplate() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Background', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: availableTemplates.map((t) {
                    final selected = t.assetPath == _selectedTemplate.assetPath;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _loadTemplate(t);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? const Color(0xFFB33A2E) : Theme.of(context).dividerColor,
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(t.assetPath, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 4),
                          Text(t.name, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Position on Template'),
        actions: [
          IconButton(
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
            tooltip: 'Toggle grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          IconButton(
            icon: const Icon(Icons.wallpaper),
            tooltip: 'Change background',
            onPressed: _pickTemplate,
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: $_error')))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Drag to move, pinch to resize', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _centerHorizontally,
                            icon: const Icon(Icons.align_horizontal_center, size: 18),
                            label: const Text('Center X'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _centerVertically,
                            icon: const Icon(Icons.align_vertical_center, size: 18),
                            label: const Text('Center Y'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _centerBoth,
                            icon: const Icon(Icons.center_focus_strong, size: 18),
                            label: const Text('Center'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: FutureBuilder<img.Image>(
                            future: _decodeTemplate(_selectedTemplate.assetPath),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const CircularProgressIndicator();
                              final tpl = snapshot.data!;
                              return AspectRatio(
                                aspectRatio: tpl.width / tpl.height,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final displayScale = constraints.maxWidth / tpl.width;
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Image.asset(_selectedTemplate.assetPath, fit: BoxFit.fill),
                                          ),
                                          if (_showGrid)
                                            const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                                          Positioned(
                                            left: (_cutoutCenter.dx * displayScale) -
                                                (widget.cutout.width * _cutoutScale * displayScale / 2),
                                            top: (_cutoutCenter.dy * displayScale) -
                                                (widget.cutout.height * _cutoutScale * displayScale / 2),
                                            width: widget.cutout.width * _cutoutScale * displayScale,
                                            height: widget.cutout.height * _cutoutScale * displayScale,
                                            child: IgnorePointer(
                                              child: Image.memory(_cutoutPngBytes, fit: BoxFit.fill),
                                            ),
                                          ),
                                          Positioned.fill(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.translucent,
                                              onScaleStart: (d) {
                                                _gestureStartFocal = d.focalPoint;
                                                _gestureStartCenter = _cutoutCenter;
                                                _gestureStartScale = _cutoutScale;
                                              },
                                              onScaleUpdate: (d) {
                                                setState(() {
                                                  _cutoutScale = (_gestureStartScale * d.scale).clamp(0.05, 6.0);
                                                  final deltaTemplateSpace =
                                                      (d.focalPoint - _gestureStartFocal) / displayScale;
                                                  _cutoutCenter = _gestureStartCenter + deltaTemplateSpace;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: _tapContinue,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continue'),
                        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    for (final fx in [1 / 3, 2 / 3]) {
      final x = size.width * fx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), shadow);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (final fy in [1 / 3, 2 / 3]) {
      final y = size.height * fy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), shadow);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
