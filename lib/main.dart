import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import 'bg_removal.dart';
import 'touchup_screen.dart';
import 'cutout_review_screen.dart';

void main() {
  runApp(const AnjarBoutiqueApp());
}

class AnjarBoutiqueApp extends StatelessWidget {
  const AnjarBoutiqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anjar Boutique',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFB33A2E),
        scaffoldBackgroundColor: const Color(0xFFFAF6F1),
      ),
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// COMPOSITING CONFIG — tweak these if the photo placement looks off.
// Canvas is assumed to match the background template's own size (1080x1080
// for the current asset). Box values are in canvas pixels.
// ---------------------------------------------------------------------------
class CompositeConfig {
  static const int boxLeft = 140;
  static const int boxTop = 170;
  static const int boxWidth = 800;
  static const int boxHeight = 850;
}

// ---------------------------------------------------------------------------
// HOME SCREEN
// ---------------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return;
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BgRemovalScreen(photoFile: File(picked.path))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anjar Boutique')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checkroom, size: 96, color: Color(0xFFB33A2E)),
              const SizedBox(height: 16),
              const Text(
                'Upload a product photo to create\na branded post + caption',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => _pickImage(context, ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: FilledButton.styleFrom(minimumSize: const Size(240, 50)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _pickImage(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(240, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BACKGROUND REMOVAL SCREEN — runs the on-device model, then hands off to
// the touch-up brush before compositing onto the template.
// ---------------------------------------------------------------------------
class BgRemovalScreen extends StatefulWidget {
  final File photoFile;
  const BgRemovalScreen({super.key, required this.photoFile});

  @override
  State<BgRemovalScreen> createState() => _BgRemovalScreenState();
}

class _BgRemovalScreenState extends State<BgRemovalScreen> {
  String? _error;

  // Cap the working resolution so the model + brush stay fast. The final
  // post is already a fixed-size template, so this loses no real quality.
  static const int _maxWorkingDimension = 1400;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final bytes = await widget.photoFile.readAsBytes();
      var photo = img.decodeImage(bytes)!;

      if (photo.width > _maxWorkingDimension || photo.height > _maxWorkingDimension) {
        final scale = photo.width > photo.height
            ? _maxWorkingDimension / photo.width
            : _maxWorkingDimension / photo.height;
        photo = img.copyResize(
          photo,
          width: (photo.width * scale).round(),
          height: (photo.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }

      final cutout = await BackgroundRemover.cutout(photo);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CutoutReviewScreen(
            cutout: cutout,
            onConfirmed: (edited) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CompositeScreen(cutout: edited)),
              );
            },
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Removing Background')),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Something went wrong: $_error', textAlign: TextAlign.center),
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Finding the product in your photo…'),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// COMPOSITE SCREEN — overlays the cut-out product onto the branded template
// ---------------------------------------------------------------------------
class CompositeScreen extends StatefulWidget {
  final img.Image cutout;
  const CompositeScreen({super.key, required this.cutout});

  @override
  State<CompositeScreen> createState() => _CompositeScreenState();
}

class _CompositeScreenState extends State<CompositeScreen> {
  Uint8List? _composited;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runComposite();
  }

  Future<void> _runComposite() async {
    try {
      final result = await compositeOntoTemplate(widget.cutout);
      setState(() => _composited = result);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: Center(
        child: _error != null
            ? Text('Error: $_error')
            : _composited == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_composited!, fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailsFormScreen(composited: _composited!),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continue'),
                          style: FilledButton.styleFrom(minimumSize: const Size(220, 50)),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// Loads the bundled background template and pastes the (already background-
/// removed) cutout on top, scaled to fit CompositeConfig's box (preserving
/// aspect ratio, centered). Transparent pixels let the mandala show through.
Future<Uint8List> compositeOntoTemplate(img.Image photo) async {
  final templateBytes = await rootBundle.load('assets/background_template.png');
  final template = img.decodePng(templateBytes.buffer.asUint8List())!;

  // Scale photo to fit inside the configured box, preserving aspect ratio.
  final boxW = CompositeConfig.boxWidth;
  final boxH = CompositeConfig.boxHeight;
  final scale = (photo.width / boxW > photo.height / boxH)
      ? boxW / photo.width
      : boxH / photo.height;
  final newW = (photo.width * scale).round();
  final newH = (photo.height * scale).round();
  final resizedPhoto = img.copyResize(photo, width: newW, height: newH, interpolation: img.Interpolation.average);

  final canvas = img.Image.from(template);
  final pasteX = CompositeConfig.boxLeft + ((boxW - newW) ~/ 2);
  final pasteY = CompositeConfig.boxTop + ((boxH - newH) ~/ 2);
  img.compositeImage(canvas, resizedPhoto, dstX: pasteX, dstY: pasteY);

  return Uint8List.fromList(img.encodePng(canvas));
}

// ---------------------------------------------------------------------------
// DETAILS FORM SCREEN — all fields optional; blank fields are omitted
// ---------------------------------------------------------------------------
class DetailsFormScreen extends StatefulWidget {
  final Uint8List composited;
  const DetailsFormScreen({super.key, required this.composited});

  @override
  State<DetailsFormScreen> createState() => _DetailsFormScreenState();
}

class _DetailsFormScreenState extends State<DetailsFormScreen> {
  final descriptionCtrl = TextEditingController();
  final productNameCtrl = TextEditingController();
  final sizeExtraCtrl = TextEditingController();
  final stitchingCtrl = TextEditingController();
  final fabricCtrl = TextEditingController();
  final workCtrl = TextEditingController();
  final colorExtraCtrl = TextEditingController();
  final extraCtrl = TextEditingController();

  bool _sizeIsInches = true;
  final Set<String> _selectedInchSizes = {};
  final Set<String> _selectedStandardSizes = {};
  final Set<String> _selectedColors = {};

  static const List<String> _inchSizes = ['26', '28', '30', '32', '34', '36', '38', '40'];
  static const List<String> _standardSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL', 'XXXXL', 'XXXXXL'];
  static const Map<String, String> _colorEmojis = {
    'Red': '🔴',
    'Orange': '🟠',
    'Yellow': '🟡',
    'Green': '🟢',
    'Blue': '🔵',
    'Purple': '🟣',
    'Brown': '🟤',
    'Black': '⚫',
    'White': '⚪',
  };

  @override
  void dispose() {
    descriptionCtrl.dispose();
    productNameCtrl.dispose();
    sizeExtraCtrl.dispose();
    stitchingCtrl.dispose();
    fabricCtrl.dispose();
    workCtrl.dispose();
    colorExtraCtrl.dispose();
    extraCtrl.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  String get _computedSize {
    final chosen = _sizeIsInches ? _selectedInchSizes : _selectedStandardSizes;
    final parts = <String>[...chosen];
    if (sizeExtraCtrl.text.trim().isNotEmpty) parts.add(sizeExtraCtrl.text.trim());
    return parts.join(', ');
  }

  String get _computedColor {
    final parts = <String>[
      for (final c in _selectedColors) '${_colorEmojis[c]} $c',
    ];
    if (colorExtraCtrl.text.trim().isNotEmpty) parts.add(colorExtraCtrl.text.trim());
    return parts.join(', ');
  }

  void _generate() {
    final caption = buildCaption(
      description: descriptionCtrl.text.trim(),
      productName: productNameCtrl.text.trim(),
      size: _computedSize,
      stitching: stitchingCtrl.text.trim(),
      fabric: fabricCtrl.text.trim(),
      color: _computedColor,
      work: workCtrl.text.trim(),
      extra: extraCtrl.text.trim(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(composited: widget.composited, caption: caption),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(descriptionCtrl, 'Description (festive hook line)', maxLines: 2),
            _field(productNameCtrl, 'Product Name'),

            _sectionLabel('Size'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Inches')),
                ButtonSegment(value: false, label: Text('Standard (S/M/L)')),
              ],
              selected: {_sizeIsInches},
              onSelectionChanged: (s) => setState(() => _sizeIsInches = s.first),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (_sizeIsInches ? _inchSizes : _standardSizes).map((s) {
                final selectedSet = _sizeIsInches ? _selectedInchSizes : _selectedStandardSizes;
                return FilterChip(
                  label: Text(s),
                  selected: selectedSet.contains(s),
                  onSelected: (sel) => setState(() {
                    sel ? selectedSet.add(s) : selectedSet.remove(s);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            _field(sizeExtraCtrl, 'Other / notes on size'),

            _sectionLabel('Color'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _colorEmojis.entries.map((e) {
                return FilterChip(
                  label: Text('${e.value} ${e.key}'),
                  selected: _selectedColors.contains(e.key),
                  onSelected: (sel) => setState(() {
                    sel ? _selectedColors.add(e.key) : _selectedColors.remove(e.key);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            _field(colorExtraCtrl, 'Other / notes on color'),

            _field(stitchingCtrl, 'Stitching'),
            _field(fabricCtrl, 'Fabric'),
            _field(workCtrl, 'Work'),
            _field(extraCtrl, 'Extra note (optional)', maxLines: 2),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Caption'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CAPTION TEMPLATE — fixed format, blank fields are skipped
// ---------------------------------------------------------------------------
const List<String> defaultHashtags = [
  '#IndianFashion',
  '#IndoWestern',
  '#ChaniyaCholi',
  '#FestiveFashion',
  '#KutchiFashion',
  '#KutchCulture',
  '#KutchEmbroidery',
];

String buildCaption({
  required String description,
  required String productName,
  required String size,
  required String stitching,
  required String fabric,
  required String color,
  required String work,
  required String extra,
}) {
  final buffer = StringBuffer();

  if (description.isNotEmpty) {
    buffer.writeln('🖤 $description 🖤');
    buffer.writeln('•');
  }

  final fields = <String, String>{
    'Product Name': productName,
    'Size': size,
    'Stitching': stitching,
    'Fabric': fabric,
    'Color': color,
    'Work': work,
  };
  for (final entry in fields.entries) {
    if (entry.value.isNotEmpty) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
  }

  if (extra.isNotEmpty) {
    buffer.writeln(extra);
  }

  buffer.writeln('•');
  buffer.writeln('•');
  buffer.writeln('•');
  buffer.writeln(defaultHashtags.join(' '));

  return buffer.toString().trim();
}

// ---------------------------------------------------------------------------
// RESULT SCREEN — final image + caption, copy + share
// ---------------------------------------------------------------------------
class ResultScreen extends StatelessWidget {
  final Uint8List composited;
  final String caption;
  const ResultScreen({super.key, required this.composited, required this.caption});

  Future<File> _saveTempImage() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/anjar_post_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(composited);
    return file;
  }

  Future<void> _copyCaption(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: caption));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption copied')),
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    final file = await _saveTempImage();
    await Share.shareXFiles([XFile(file.path)], text: caption);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ready to Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(composited),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(caption),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyCaption(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Caption'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _share(context),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
