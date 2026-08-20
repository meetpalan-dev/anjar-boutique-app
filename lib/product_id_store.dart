import 'package:shared_preferences/shared_preferences.dart';
import 'post_history_store.dart';

/// Generates parent Product IDs (e.g. "AJB-00125") and variant IDs
/// (e.g. "AJB-00125-R" for the Red variant of that same product).
class ProductIdStore {
  static const _counterKey = 'parent_id_counter';

  /// A brand-new product gets a fresh, never-reused parent ID.
  static Future<String> generateParentId() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_counterKey) ?? 0) + 1;
    await prefs.setInt(_counterKey, next);
    return 'AJB-${next.toString().padLeft(5, '0')}';
  }

  /// Derives a short suffix from the primary color name (e.g. "Red" -> "R").
  /// Falls back to "V" (variant) if no color was picked.
  static String suffixFromColor(String? primaryColorName) {
    if (primaryColorName == null || primaryColorName.trim().isEmpty) return 'V';
    return primaryColorName.trim()[0].toUpperCase();
  }

  /// Combines a parent ID with a suffix, adding a number if that exact
  /// variant ID is somehow already taken (e.g. two variants both starting
  /// with "R" — Red and Rose) so IDs never collide.
  static Future<String> makeUniqueVariantId(String parentId, String desiredSuffix) async {
    final existing = await PostHistoryStore.getAll();
    final existingIds = existing.map((r) => r.id).toSet();
    var suffix = desiredSuffix;
    var attempt = 1;
    while (existingIds.contains('$parentId-$suffix')) {
      attempt++;
      suffix = '$desiredSuffix$attempt';
    }
    return '$parentId-$suffix';
  }

  /// All distinct parent products already in history, newest first —
  /// used to populate the "add a variant to an existing product" picker.
  /// Each summary uses its most recent post as the representative
  /// thumbnail/category, and collects every color seen across its variants.
  static Future<List<ParentProductSummary>> getExistingParents() async {
    final all = await PostHistoryStore.getAll(); // newest first
    final order = <String>[]; // first-seen order = most recent post per parent
    final representative = <String, PostRecord>{};
    final colorsByParent = <String, Set<String>>{};

    for (final r in all) {
      if (r.parentId.isEmpty) continue;
      if (!representative.containsKey(r.parentId)) {
        representative[r.parentId] = r;
        order.add(r.parentId);
      }
      if (r.color.isNotEmpty) {
        colorsByParent.putIfAbsent(r.parentId, () => {}).add(r.color);
      }
    }

    return order.map((parentId) {
      final rep = representative[parentId]!;
      return ParentProductSummary(
        parentId: parentId,
        productName: rep.productName,
        category: rep.category,
        imagePath: rep.imagePath,
        colors: (colorsByParent[parentId] ?? {}).toList(),
      );
    }).toList();
  }
}

class ParentProductSummary {
  final String parentId;
  final String productName;
  final String category;
  final String imagePath;
  final List<String> colors;
  const ParentProductSummary({
    required this.parentId,
    required this.productName,
    required this.category,
    required this.imagePath,
    required this.colors,
  });
}

/// A one-shot handoff: "Create New Post" on an existing product sets this,
/// then returns to Home so the user can pick a new photo. Product Details
/// checks it once on load and applies it as the pre-selected parent product.
class PendingParentSelection {
  static String? parentId;
  static String? consume() {
    final v = parentId;
    parentId = null;
    return v;
  }
}
