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
import 'positioning_screen.dart';
import 'settings_screen.dart';
import 'suggestions_store.dart';
import 'theme_store.dart';
import 'post_history_store.dart';
import 'history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeStore.load();
  runApp(const AnjarBoutiqueApp());
}

class AnjarBoutiqueApp extends StatelessWidget {
  const AnjarBoutiqueApp({super.key});

  static const Color brandSeed = Color(0xFFB33A2E);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeStore.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Anjar Boutique',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: brandSeed, brightness: Brightness.light),
            scaffoldBackgroundColor: const Color(0xFFFAF6F1),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: brandSeed, brightness: Brightness.dark),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
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
      appBar: AppBar(
        title: const Text('Anjar Boutique'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checkroom, size: 96, color: Color(0xFFB33A2E)),
              const SizedBox(height: 16),
              Text(
                'Upload a product photo to create\na branded post + caption',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
// BACKGROUND REMOVAL SCREEN
// ---------------------------------------------------------------------------
class BgRemovalScreen extends StatefulWidget {
  final File photoFile;
  const BgRemovalScreen({super.key, required this.photoFile});

  @override
  State<BgRemovalScreen> createState() => _BgRemovalScreenState();
}

class _BgRemovalScreenState extends State<BgRemovalScreen> {
  String? _error;

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

      // Use push, not pushReplacement — the onConfirmed closure below reuses
      // this screen's `context` later (when the user taps Looks Good, which
      // can be much later, after Fix It too). pushReplacement would remove
      // this screen from the tree immediately, leaving that context stale —
      // any later Navigator.push(context, ...) call on it silently fails.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CutoutReviewScreen(
            cutout: cutout,
            onConfirmed: (edited) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PositioningScreen(cutout: edited)),
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
// DETAILS FORM SCREEN
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

  final Set<String> _selectedSizeAlphas = {};
  final Set<String> _selectedColors = {};
  bool _sizeNumberMode = false; // OFF = alphabet (spec default), ON = number
  bool _showMoreSizes = false;

  List<String> _productNameSuggestions = const [];
  List<String> _stitchingSuggestions = const [];
  List<String> _fabricSuggestions = const [];
  List<String> _workSuggestions = const [];
  List<String> _categorySuggestions = const [];
  String? _selectedCategory;

  // alpha size -> inch measurement, in canonical smallest-to-largest order
  static const List<MapEntry<String, int>> _sizeMap = [
    MapEntry('XS', 34),
    MapEntry('S', 36),
    MapEntry('M', 38),
    MapEntry('L', 40),
    MapEntry('XL', 42),
    MapEntry('XXL', 44),
    MapEntry('XXXL', 46),
    MapEntry('4XL', 48),
    MapEntry('5XL', 50),
  ];
  static const int _baseSizeCount = 6; // kept for reference; superseded by _hiddenByDefault below
  // S, M, L, XL, XXL are visible by default; the rest live behind "More sizes".
  static const Set<String> _hiddenByDefault = {'XS', 'XXXL', '4XL', '5XL'};

  static const Map<String, String> _colorEmojis = {
    'Red': '❤️',
    'Orange': '🧡',
    'Yellow': '💛',
    'Green': '💚',
    'Blue': '💙',
    'Purple': '💜',
    'Brown': '🤎',
    'Black': '🖤',
    'White': '🤍',
    'Pink': '🩷',
    'Light Blue': '🩵',
    'Grey': '🩶',
  };

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final pn = await SuggestionsStore.getProductNames();
    final st = await SuggestionsStore.getStitching();
    final fb = await SuggestionsStore.getFabric();
    final wk = await SuggestionsStore.getWork();
    final cat = await SuggestionsStore.getCategories();
    if (!mounted) return;
    setState(() {
      _productNameSuggestions = pn;
      _stitchingSuggestions = st;
      _fabricSuggestions = fb;
      _workSuggestions = wk;
      _categorySuggestions = cat;
    });
  }

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

  /// A normal text field with tappable suggestion chips above it. Tapping a
  /// chip fills the field; the user can still type anything else.
  Widget _suggestionField(TextEditingController ctrl, String label, List<String> suggestions) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions.map((s) {
                  return ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => ctrl.text = s),
                  );
                }).toList(),
              ),
            ),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  /// Lays chips out in a fixed-column grid (rows of [columns]).
  Widget _chipGrid(List<Widget> chips, {int columns = 3}) {
    final rows = <Widget>[];
    for (var i = 0; i < chips.length; i += columns) {
      final end = (i + columns > chips.length) ? chips.length : i + columns;
      final rowItems = chips.sublist(i, end);
      final slots = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (j > 0) slots.add(const SizedBox(width: 8));
        slots.add(Expanded(
          child: j < rowItems.length
              ? Align(alignment: Alignment.centerLeft, child: rowItems[j])
              : const SizedBox(),
        ));
      }
      rows.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: slots)));
    }
    return Column(children: rows);
  }

  Widget _sizeChip(MapEntry<String, int> entry) {
    final selected = _selectedSizeAlphas.contains(entry.key);
    // Alphabet mode: size name is the bold/primary value, inches is secondary.
    // Number mode: inches is the bold/primary value, size name is secondary.
    final primary = _sizeNumberMode ? '${entry.value} inch' : entry.key;
    final secondary = _sizeNumberMode ? '(${entry.key})' : '${entry.value} inch';
    return FilterChip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(primary, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(secondary, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
      selected: selected,
      onSelected: (sel) => setState(() {
        sel ? _selectedSizeAlphas.add(entry.key) : _selectedSizeAlphas.remove(entry.key);
      }),
    );
  }

  // Selected sizes, in canonical smallest->largest order (the _sizeMap list
  // is already ordered, so filtering it preserves that order for free).
  List<MapEntry<String, int>> get _selectedSizeEntries =>
      _sizeMap.where((e) => _selectedSizeAlphas.contains(e.key)).toList();

  String get _computedSize {
    final labels = _sizeNumberMode
        ? _selectedSizeEntries.map((e) => '${e.value}').toList()
        : _selectedSizeEntries.map((e) => e.key).toList();
    final parts = [...labels];
    if (sizeExtraCtrl.text.trim().isNotEmpty) parts.add(sizeExtraCtrl.text.trim());
    return parts.join(', ');
  }

  // Color output includes the emoji alongside the name, e.g. "❤️ Red".
  // Custom "Other colour" text is kept as-is, with no invented emoji.
  String get _computedColor {
    final parts = <String>[for (final c in _selectedColors) '${_colorEmojis[c]} $c'];
    if (colorExtraCtrl.text.trim().isNotEmpty) parts.add(colorExtraCtrl.text.trim());
    return parts.join(', ');
  }

  void _generate() {
    final id = PostHistoryStore.generateId();
    final category = _selectedCategory ?? '';
    final productName = productNameCtrl.text.trim();
    final caption = buildCaption(
      id: id,
      category: category,
      description: descriptionCtrl.text.trim(),
      productName: productName,
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
        builder: (_) => ResultScreen(
          composited: widget.composited,
          caption: caption,
          id: id,
          category: category,
          productName: productName,
        ),
      ),
    );
  }

  Widget _groupLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      );

  @override
  Widget build(BuildContext context) {
    final baseSizes = _sizeMap.where((e) => !_hiddenByDefault.contains(e.key)).toList();
    final moreSizes = _sizeMap.where((e) => _hiddenByDefault.contains(e.key)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _groupLabel('Product'),
            _sectionLabel('Category'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categorySuggestions.map((c) {
                final selected = _selectedCategory == c;
                return FilterChip(
                  label: Text(c, style: const TextStyle(fontSize: 12.5)),
                  selected: selected,
                  onSelected: (sel) => setState(() => _selectedCategory = sel ? c : null),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _field(descriptionCtrl, 'Description (festive hook line)', maxLines: 2),
            _suggestionField(productNameCtrl, 'Product Name', _productNameSuggestions),

            _divider(),
            Row(
              children: [
                Expanded(child: _sectionLabel('Size')),
                Text('Number', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Switch(
                  value: _sizeNumberMode,
                  onChanged: (v) => setState(() => _sizeNumberMode = v),
                ),
              ],
            ),
            _chipGrid(baseSizes.map(_sizeChip).toList()),
            if (_showMoreSizes) _chipGrid(moreSizes.map(_sizeChip).toList()),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showMoreSizes = !_showMoreSizes),
                icon: Icon(_showMoreSizes ? Icons.remove : Icons.add, size: 18),
                label: Text(_showMoreSizes ? 'Fewer sizes' : 'More sizes'),
              ),
            ),
            _field(sizeExtraCtrl, 'Other size'),

            _sectionLabel('Colour'),
            _chipGrid(
              _colorEmojis.entries.map((e) {
                final selected = _selectedColors.contains(e.key);
                return FilterChip(
                  label: Text('${e.value} ${e.key}', style: const TextStyle(fontSize: 13)),
                  selected: selected,
                  onSelected: (sel) => setState(() {
                    sel ? _selectedColors.add(e.key) : _selectedColors.remove(e.key);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            _field(colorExtraCtrl, 'Other colour'),

            _divider(),
            _groupLabel('Product Details'),
            _suggestionField(stitchingCtrl, 'Stitching', _stitchingSuggestions),
            _suggestionField(fabricCtrl, 'Fabric', _fabricSuggestions),
            _suggestionField(workCtrl, 'Work', _workSuggestions),
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

// Product-specific hashtag sets for the predefined Product Name suggestions.
// A custom (typed) Product Name falls back to defaultHashtags instead.
const Map<String, List<String>> productHashtags = {
  'Angrakha Kurti': ['#angrakhakurti', '#kurti', '#IndianEthnicWear'],
  'Straight Kurti': ['#kurti', '#StraightKurti', '#IndianEthnicWear'],
  'Kurti with Salwar & With Dupatta': ['#kurtiset', '#SalwarKurti', '#IndianEthnicWear'],
  'Kurti with Palazzos & With Dupatta': ['#kurtiplazoset', '#PalazzoSet', '#IndianEthnicWear'],
  'Lehenga With Choli & Dupatta': ['#lehengaCholi', '#chaniyacholi', '#LehengaSet'],
};

List<String> _buildHashtags(String productName) {
  final trimmed = productName.trim();
  String matchKey = '';
  for (final key in productHashtags.keys) {
    if (key.toLowerCase() == trimmed.toLowerCase()) {
      matchKey = key;
      break;
    }
  }

  final tags = <String>[];
  if (matchKey.isNotEmpty) {
    tags.addAll(productHashtags[matchKey]!);
  } else {
    tags.addAll(defaultHashtags);
  }
  if (!tags.contains('#anjarboutique')) tags.add('#anjarboutique');

  final seen = <String>{};
  return tags.where((t) => seen.add(t)).toList();
}

String buildCaption({
  required String id,
  required String category,
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
    buffer.writeln(description);
    buffer.writeln('•');
  }

  final fields = <String, String>{
    'Category': category,
    'Product Name': productName,
    'Stitching': stitching,
    'Size': size,
    'Color': color,
    'Fabric': fabric,
    'Work': work,
    'ID': id,
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
  buffer.writeln(_buildHashtags(productName).join(' '));

  return buffer.toString().trim();
}


// ---------------------------------------------------------------------------
// RESULT SCREEN — final image + caption, copy + share
// ---------------------------------------------------------------------------
class ResultScreen extends StatefulWidget {
  final Uint8List composited;
  final String caption;
  final String id;
  final String category;
  final String productName;

  const ResultScreen({
    super.key,
    required this.composited,
    required this.caption,
    required this.id,
    required this.category,
    required this.productName,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-save to history as soon as a post is generated — no separate
    // "Save" step needed. Fire-and-forget: a save failure shouldn't block
    // the user from copying/sharing the caption they already have.
    PostHistoryStore.save(
      id: widget.id,
      imageBytes: widget.composited,
      caption: widget.caption,
      category: widget.category,
      productName: widget.productName,
    ).catchError((_) {
      // Best-effort — the generated post is still usable even if saving
      // to history fails (e.g. disk space).
      return PostRecord(
        id: widget.id,
        createdAt: DateTime.now(),
        category: widget.category,
        productName: widget.productName,
        caption: widget.caption,
        imagePath: '',
      );
    });
  }

  Future<File> _saveTempImage() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/anjar_post_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(widget.composited);
    return file;
  }

  Future<void> _copyCaption(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.caption));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption copied')),
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    final file = await _saveTempImage();
    await Share.shareXFiles([XFile(file.path)], text: widget.caption);
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
              child: Image.memory(widget.composited),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(widget.caption),
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
