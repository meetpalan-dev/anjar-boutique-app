import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class PostRecord {
  final String id;
  final DateTime createdAt;
  final String category;
  final String productName;
  final String caption;
  final String imagePath;

  PostRecord({
    required this.id,
    required this.createdAt,
    required this.category,
    required this.productName,
    required this.caption,
    required this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'category': category,
        'productName': productName,
        'caption': caption,
        'imagePath': imagePath,
      };

  factory PostRecord.fromJson(Map<String, dynamic> j) => PostRecord(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        category: j['category'] as String? ?? '',
        productName: j['productName'] as String? ?? '',
        caption: j['caption'] as String? ?? '',
        imagePath: j['imagePath'] as String? ?? '',
      );
}

/// Stores every generated post as: one PNG file per post, plus a single
/// JSON index file listing all of them. No database plugin needed — plain
/// files via path_provider (already a dependency), simple to reason about
/// for a shop's product-post volume.
class PostHistoryStore {
  static Future<Directory> _postsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/posts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _indexFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/posts_index.json');
  }

  /// A short, unique, human-scannable ID — no counter/state needed, so
  /// there's nothing that can get out of sync or collide across installs.
  static String generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'AJB-$ts';
  }

  static Future<PostRecord> save({
    required String id,
    required Uint8List imageBytes,
    required String caption,
    required String category,
    required String productName,
  }) async {
    final dir = await _postsDir();
    final imageFile = File('${dir.path}/$id.png');
    await imageFile.writeAsBytes(imageBytes);

    final record = PostRecord(
      id: id,
      createdAt: DateTime.now(),
      category: category,
      productName: productName,
      caption: caption,
      imagePath: imageFile.path,
    );

    final f = await _indexFile();
    List<Map<String, dynamic>> raw = [];
    if (await f.exists()) {
      raw = (jsonDecode(await f.readAsString()) as List).cast<Map<String, dynamic>>();
    }
    raw.add(record.toJson());
    await f.writeAsString(jsonEncode(raw));
    return record;
  }

  /// Newest first.
  static Future<List<PostRecord>> getAll() async {
    final f = await _indexFile();
    if (!await f.exists()) return [];
    final raw = (jsonDecode(await f.readAsString()) as List).cast<Map<String, dynamic>>();
    return raw.map(PostRecord.fromJson).toList().reversed.toList();
  }

  static Future<List<PostRecord>> search({String? query, String? category, DateTime? date}) async {
    final all = await getAll();
    return all.where((r) {
      if (category != null && category.isNotEmpty && r.category != category) return false;
      if (date != null &&
          !(r.createdAt.year == date.year && r.createdAt.month == date.month && r.createdAt.day == date.day)) {
        return false;
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matches = r.id.toLowerCase().contains(q) ||
            r.productName.toLowerCase().contains(q) ||
            r.caption.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }
}
