import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'suggestions_store.dart';

/// Bundles all five suggestion lists into one exportable/importable file.
class SuggestionsIO {
  static const _formatKey = 'anjar_boutique_suggestions_v1';

  static Future<void> export() async {
    final data = {
      'format': _formatKey,
      'productName': await SuggestionsStore.getProductNames(),
      'category': await SuggestionsStore.getCategories(),
      'stitching': await SuggestionsStore.getStitching(),
      'fabric': await SuggestionsStore.getFabric(),
      'work': await SuggestionsStore.getWork(),
    };

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/anjar_boutique_suggestions.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

    await Share.shareXFiles([XFile(file.path)], text: 'Anjar Boutique suggestions export');
  }

  /// Returns null on success, or an error message to show the user.
  static Future<String?> import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null; // user cancelled

    final path = result.files.single.path;
    if (path == null) return 'Could not read the selected file.';

    late String raw;
    try {
      raw = await File(path).readAsString();
    } catch (_) {
      return 'Could not read the selected file.';
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) throw const FormatException('not an object');
      data = decoded;
    } catch (_) {
      return 'This doesn\'t look like a valid suggestions file.';
    }

    if (data['format'] != _formatKey) {
      return 'This file isn\'t an Anjar Boutique suggestions export.';
    }

    Future<void> importGroup(String key, Future<void> Function(String) add) async {
      final list = data[key];
      if (list is! List) return;
      for (final item in list) {
        if (item is String && item.trim().isNotEmpty) {
          // addProductName/addStitching/etc. already skip duplicates
          // internally, so importing the same file twice is a no-op.
          await add(item);
        }
      }
    }

    await importGroup('productName', SuggestionsStore.addProductName);
    await importGroup('category', SuggestionsStore.addCategory);
    await importGroup('stitching', SuggestionsStore.addStitching);
    await importGroup('fabric', SuggestionsStore.addFabric);
    await importGroup('work', SuggestionsStore.addWork);

    return null; // success
  }
}
