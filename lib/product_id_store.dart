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
  static Future<List<ParentProductSummary>> getExistingParents() async {
    final all = await PostHistoryStore.getAll(); // newest first
    final seen = <String>{};
    final summaries = <ParentProductSummary>[];
    for (final r in all) {
      if (r.parentId.isEmpty || seen.contains(r.parentId)) continue;
      seen.add(r.parentId);
      summaries.add(ParentProductSummary(parentId: r.parentId, productName: r.productName));
    }
    return summaries;
  }
}

class ParentProductSummary {
  final String parentId;
  final String productName;
  const ParentProductSummary({required this.parentId, required this.productName});
}
