import 'package:shared_preferences/shared_preferences.dart';

/// Manages user-added suggestion chips shown on the Product Details form.
/// There are no built-in defaults — only what the user explicitly adds in
/// Settings appears here, and it persists across app restarts.
class SuggestionsStore {
  static const _productNameKey = 'suggestions_product_name';
  static const _stitchingKey = 'suggestions_stitching';
  static const _fabricKey = 'suggestions_fabric';
  static const _workKey = 'suggestions_work';
  static const _categoryKey = 'suggestions_category';

  static Future<List<String>> _getCustom(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  static Future<void> _addCustom(String key, String value) async {
    if (value.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    if (!list.contains(value)) {
      list.add(value);
      await prefs.setStringList(key, list);
    }
  }

  static Future<void> _removeCustom(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    list.remove(value);
    await prefs.setStringList(key, list);
  }

  static Future<List<String>> getProductNames() => _getCustom(_productNameKey);
  static Future<List<String>> getStitching() => _getCustom(_stitchingKey);
  static Future<List<String>> getFabric() => _getCustom(_fabricKey);
  static Future<List<String>> getWork() => _getCustom(_workKey);
  static Future<List<String>> getCategories() => _getCustom(_categoryKey);

  static Future<List<String>> getCustomProductNames() => _getCustom(_productNameKey);
  static Future<List<String>> getCustomStitching() => _getCustom(_stitchingKey);
  static Future<List<String>> getCustomFabric() => _getCustom(_fabricKey);
  static Future<List<String>> getCustomWork() => _getCustom(_workKey);
  static Future<List<String>> getCustomCategories() => _getCustom(_categoryKey);

  static Future<void> addProductName(String v) => _addCustom(_productNameKey, v);
  static Future<void> addStitching(String v) => _addCustom(_stitchingKey, v);
  static Future<void> addFabric(String v) => _addCustom(_fabricKey, v);
  static Future<void> addWork(String v) => _addCustom(_workKey, v);
  static Future<void> addCategory(String v) => _addCustom(_categoryKey, v);

  static Future<void> removeProductName(String v) => _removeCustom(_productNameKey, v);
  static Future<void> removeStitching(String v) => _removeCustom(_stitchingKey, v);
  static Future<void> removeFabric(String v) => _removeCustom(_fabricKey, v);
  static Future<void> removeWork(String v) => _removeCustom(_workKey, v);
  static Future<void> removeCategory(String v) => _removeCustom(_categoryKey, v);
}
