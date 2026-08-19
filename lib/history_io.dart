import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'post_history_store.dart';

/// Exports/imports the full Post History database (metadata + pricing —
/// not the image files themselves) as one portable JSON file.
class HistoryIO {
  static const _formatKey = 'anjar_boutique_history_v1';

  static Future<void> export() async {
    final all = await PostHistoryStore.getAll();
    final data = {
      'format': _formatKey,
      'products': all.map((r) => r.toJson()).toList(),
    };

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/anjar_boutique_products.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

    await Share.shareXFiles([XFile(file.path)], text: 'Anjar Boutique product backup');
  }

  /// Returns a result message to show the user (success or error).
  static Future<String> import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return ''; // cancelled, no message

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
      return 'This doesn\'t look like a valid backup file.';
    }

    if (data['format'] != _formatKey) {
      return 'This file isn\'t an Anjar Boutique product backup.';
    }

    final productsRaw = data['products'];
    if (productsRaw is! List) {
      return 'This backup file has no product data in it.';
    }

    List<PostRecord> records;
    try {
      records = productsRaw.cast<Map<String, dynamic>>().map(PostRecord.fromJson).toList();
    } catch (_) {
      return 'This backup file is corrupted or in an unexpected format.';
    }

    final added = await PostHistoryStore.importRecords(records);
    final skipped = records.length - added;
    if (added == 0) {
      return 'Nothing new to import — all products already exist.';
    }
    return skipped > 0
        ? 'Imported $added product(s), skipped $skipped already-existing.'
        : 'Imported $added product(s).';
  }
}
