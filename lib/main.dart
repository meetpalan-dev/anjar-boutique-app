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
import 'product_id_store.dart';
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
  final costPriceCtrl = TextEditingController();
  final sellingPriceCtrl = TextEditingController();
  final discountPriceCtrl = TextEditingController();

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

  // Parent product: null = "New Product" (fresh parent ID generated on
  // submit); otherwise the parentId of an existing product this is a new
  // color/variant of.
  List<ParentProductSummary> _existingParents = const [];
  String? _selectedParentId;

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
    _loadExistingParents();
  }

  Future<void> _loadExistingParents() async {
    final parents = await ProductIdStore.getExistingParents();
    if (!mounted) return;
    setState(() {
      _existingParents = parents;
      final pending = PendingParentSelection.consume();
      if (pending != null) _selectedParentId = pending;
    });
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
    costPriceCtrl.dispose();
    sellingPriceCtrl.dispose();
    discountPriceCtrl.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
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

  Future<void> _generate() async {
    final category = _selectedCategory ?? '';
    final productName = productNameCtrl.text.trim();

    final parentId = _selectedParentId ?? await ProductIdStore.generateParentId();
    final primaryColor = _selectedColors.isNotEmpty ? _selectedColors.first : null;
    final suffix = ProductIdStore.suffixFromColor(primaryColor);
    final id = await ProductIdStore.makeUniqueVariantId(parentId, suffix);

    final hashtags = _buildHashtags(productName);
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

    double? parseMoney(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          composited: widget.composited,
          caption: caption,
          id: id,
          parentId: parentId,
          category: category,
          productName: productName,
          description: descriptionCtrl.text.trim(),
          size: _computedSize,
          color: _computedColor,
          stitching: stitchingCtrl.text.trim(),
          fabric: fabricCtrl.text.trim(),
          work: workCtrl.text.trim(),
          extraNote: extraCtrl.text.trim(),
          hashtags: hashtags,
          costPrice: parseMoney(costPriceCtrl.text),
          sellingPrice: parseMoney(sellingPriceCtrl.text),
          discountPrice: parseMoney(discountPriceCtrl.text),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      );

  void _openExistingProductPicker() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final results = query.isEmpty
                ? _existingParents
                : _existingParents.where((p) {
                    return p.parentId.toLowerCase().contains(query) ||
                        p.productName.toLowerCase().contains(query) ||
                        p.category.toLowerCase().contains(query);
                  }).toList();
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
              child: SafeArea(
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.75,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Search by Product ID, name, or category',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: results.isEmpty
                            ? const Center(child: Text('No matching products'))
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (context, i) {
                                  final p = results[i];
                                  final file = File(p.imagePath);
                                  return ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: file.existsSync()
                                          ? Image.file(file, width: 48, height: 48, fit: BoxFit.cover)
                                          : Container(
                                              width: 48,
                                              height: 48,
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              child: const Icon(Icons.image_not_supported, size: 20),
                                            ),
                                    ),
                                    title: Text(p.productName.isEmpty ? '(no name)' : p.productName),
                                    subtitle: Text(
                                      [
                                        p.parentId,
                                        if (p.category.isNotEmpty) p.category,
                                        if (p.colors.isNotEmpty) p.colors.join(', '),
                                      ].join(' · '),
                                    ),
                                    onTap: () {
                                      setState(() => _selectedParentId = p.parentId);
                                      Navigator.pop(sheetContext);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseSizes = _sizeMap.where((e) => !_hiddenByDefault.contains(e.key)).toList();

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

            if (_existingParents.isNotEmpty) ...[
              _sectionLabel('Product'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _selectedParentId = null),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _selectedParentId == null
                            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                            : null,
                      ),
                      child: const Text('New Product', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _openExistingProductPicker,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _selectedParentId != null
                            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                            : null,
                      ),
                      child: const Text('Existing Product', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _selectedParentId == null
                    ? 'A new Product ID will be generated for this.'
                    : 'This will be saved as a new color/variant of $_selectedParentId.',
                style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
            ],

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
            if (_showMoreSizes)
              _chipGrid(_sizeMap.map(_sizeChip).toList())
            else
              _chipGrid(baseSizes.map(_sizeChip).toList()),
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

            _divider(),
            _groupLabel('Pricing (internal only — never appears in the caption)'),
            Row(
              children: [
                Expanded(child: _field(costPriceCtrl, 'Cost Price (₹)', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 8),
                Expanded(child: _field(sellingPriceCtrl, 'Selling Price (₹)', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              ],
            ),
            _field(discountPriceCtrl, 'Discount Price (₹) — optional', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            AnimatedBuilder(
              animation: Listenable.merge([costPriceCtrl, sellingPriceCtrl, discountPriceCtrl]),
              builder: (context, _) {
                final cost = double.tryParse(costPriceCtrl.text.trim());
                final selling = double.tryParse(sellingPriceCtrl.text.trim());
                final discount = double.tryParse(discountPriceCtrl.text.trim());
                final base = discount ?? selling;
                if (cost == null || base == null) return const SizedBox.shrink();
                final profit = base - cost;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${discount != null ? "Actual " : ""}Profit: ₹${profit.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                  ),
                );
              },
            ),

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
  final String parentId;
  final String category;
  final String productName;
  final String description;
  final String size;
  final String color;
  final String stitching;
  final String fabric;
  final String work;
  final String extraNote;
  final List<String> hashtags;
  final double? costPrice;
  final double? sellingPrice;
  final double? discountPrice;

  const ResultScreen({
    super.key,
    required this.composited,
    required this.caption,
    required this.id,
    required this.parentId,
    required this.category,
    required this.productName,
    required this.description,
    required this.size,
    required this.color,
    required this.stitching,
    required this.fabric,
    required this.work,
    required this.extraNote,
    required this.hashtags,
    this.costPrice,
    this.sellingPrice,
    this.discountPrice,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _saving = false;
  bool _done = false;

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

  /// The one, single completion action: this is the only place a post
  /// actually gets written to Post History. Backing out of this screen
  /// without pressing Done leaves no record behind.
  Future<void> _tapDone() async {
    setState(() => _saving = true);
    try {
      await PostHistoryStore.save(
        id: widget.id,
        parentId: widget.parentId,
        imageBytes: widget.composited,
        caption: widget.caption,
        hashtags: widget.hashtags,
        category: widget.category,
        productName: widget.productName,
        description: widget.description,
        size: widget.size,
        color: widget.color,
        stitching: widget.stitching,
        fabric: widget.fabric,
        work: widget.work,
        extraNote: widget.extraNote,
        costPrice: widget.costPrice,
        sellingPrice: widget.sellingPrice,
        discountPrice: widget.discountPrice,
      );
      _done = true;
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save this post: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Backing out without Done is allowed, and intentionally leaves no
        // Post History record — nothing to do here, just don't save.
      },
      child: Scaffold(
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(widget.caption),
              ),
              const SizedBox(height: 12),
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
                    child: OutlinedButton.icon(
                      onPressed: () => _share(context),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving || _done ? null : _tapDone,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Done'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
