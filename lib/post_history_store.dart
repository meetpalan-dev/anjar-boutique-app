import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class PostRecord {
  final String id; // variant id, e.g. "AJB-00125-R"
  final String parentId; // e.g. "AJB-00125" — shared across color variants
  final DateTime createdAt;
  final String category;
  final String productName;
  final String description;
  final String size;
  final String color;
  final String stitching;
  final String fabric;
  final String work;
  final String extraNote;
  final String caption; // full rendered caption, for display/copy/share
  final List<String> hashtags;
  final String imagePath;

  // Internal-only. Never included in caption/image/share output.
  final double? costPrice;
  final double? sellingPrice;
  final double? discountPrice;

  PostRecord({
    required this.id,
    required this.parentId,
    required this.createdAt,
    required this.category,
    required this.productName,
    required this.description,
    required this.size,
    required this.color,
    required this.stitching,
    required this.fabric,
    required this.work,
    required this.extraNote,
    required this.caption,
    required this.hashtags,
    required this.imagePath,
    this.costPrice,
    this.sellingPrice,
    this.discountPrice,
  });

  /// Profit uses the discount price when set, otherwise the selling price.
  /// Null if the numbers needed to compute it aren't available.
  double? get profit {
    final base = discountPrice ?? sellingPrice;
    if (base == null || costPrice == null) return null;
    return base - costPrice!;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'createdAt': createdAt.toIso8601String(),
        'category': category,
        'productName': productName,
        'description': description,
        'size': size,
        'color': color,
        'stitching': stitching,
        'fabric': fabric,
        'work': work,
        'extraNote': extraNote,
        'caption': caption,
        'hashtags': hashtags,
        'imagePath': imagePath,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'discountPrice': discountPrice,
      };

  factory PostRecord.fromJson(Map<String, dynamic> j) => PostRecord(
        id: j['id'] as String,
        parentId: j['parentId'] as String? ?? (j['id'] as String? ?? ''),
        createdAt: DateTime.parse(j['createdAt'] as String),
        category: j['category'] as String? ?? '',
        productName: j['productName'] as String? ?? '',
        description: j['description'] as String? ?? '',
        size: j['size'] as String? ?? '',
        color: j['color'] as String? ?? '',
        stitching: j['stitching'] as String? ?? '',
        fabric: j['fabric'] as String? ?? '',
        work: j['work'] as String? ?? '',
        extraNote: j['extraNote'] as String? ?? '',
        caption: j['caption'] as String? ?? '',
        hashtags: (j['hashtags'] as List?)?.cast<String>() ?? const [],
        imagePath: j['imagePath'] as String? ?? '',
        costPrice: (j['costPrice'] as num?)?.toDouble(),
        sellingPrice: (j['sellingPrice'] as num?)?.toDouble(),
        discountPrice: (j['discountPrice'] as num?)?.toDouble(),
      );
}

/// Stores every generated post as: one PNG file per post, plus a single
/// JSON index file listing all of them. No database plugin needed — plain
/// files via path_provider (already a dependency).
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

  static Future<void> _writeAll(List<PostRecord> chronologicalAscending) async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode(chronologicalAscending.map((r) => r.toJson()).toList()));
  }

  static Future<PostRecord> save({
    required String id,
    required String parentId,
    required Uint8List imageBytes,
    required String caption,
    required List<String> hashtags,
    required String category,
    required String productName,
    required String description,
    required String size,
    required String color,
    required String stitching,
    required String fabric,
    required String work,
    required String extraNote,
    double? costPrice,
    double? sellingPrice,
    double? discountPrice,
  }) async {
    final dir = await _postsDir();
    final imageFile = File('${dir.path}/$id.png');
    await imageFile.writeAsBytes(imageBytes);

    final record = PostRecord(
      id: id,
      parentId: parentId,
      createdAt: DateTime.now(),
      category: category,
      productName: productName,
      description: description,
      size: size,
      color: color,
      stitching: stitching,
      fabric: fabric,
      work: work,
      extraNote: extraNote,
      caption: caption,
      hashtags: hashtags,
      imagePath: imageFile.path,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      discountPrice: discountPrice,
    );

    final existing = await getAll(); // newest first
    final ascending = existing.reversed.toList();
    ascending.add(record);
    await _writeAll(ascending);
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
            r.parentId.toLowerCase().contains(q) ||
            r.productName.toLowerCase().contains(q) ||
            r.caption.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  /// Permanently removes a post (and its saved image) from history.
  static Future<void> delete(String id) async {
    final all = await getAll(); // newest first
    PostRecord? target;
    for (final r in all) {
      if (r.id == id) {
        target = r;
        break;
      }
    }
    final remaining = all.where((r) => r.id != id).toList();
    await _writeAll(remaining.reversed.toList());
    if (target != null && target.imagePath.isNotEmpty) {
      try {
        final f = File(target.imagePath);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // best-effort — an orphaned image file isn't worth failing the delete over
      }
    }
  }

  /// Merges imported records in, skipping any whose ID already exists
  /// locally — so importing the same backup twice never creates duplicates.
  /// Returns how many were actually added.
  static Future<int> importRecords(List<PostRecord> records) async {
    final existing = await getAll(); // newest first
    final existingIds = existing.map((r) => r.id).toSet();
    final toAdd = records.where((r) => !existingIds.contains(r.id)).toList();
    if (toAdd.isEmpty) return 0;

    final ascending = existing.reversed.toList();
    ascending.addAll(toAdd);
    await _writeAll(ascending);
    return toAdd.length;
  }
}
