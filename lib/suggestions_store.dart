import 'package:shared_preferences/shared_preferences.dart';

/// Manages the default + user-added suggestion chips shown on the
/// Product Details form. Custom additions persist across app restarts.
class SuggestionsStore {
  static const _productNameKey = 'suggestions_product_name';
  static const _stitchingKey = 'suggestions_stitching';
  static const _fabricKey = 'suggestions_fabric';
  static const _workKey = 'suggestions_work';
  static const _categoryKey = 'suggestions_category';

  static const List<String> defaultCategories = [
    'Short Kurti',
    'Kurti Set with Salwar',
    'Kurti Set with Palazzos',
    'Chaniya Choli',
  ];

  static const List<String> defaultProductNames = [
    'Angrakha Kurti',
    'Straight Kurti',
    'Kurti with Salwar & With Dupatta',
    'Kurti with Palazzos & With Dupatta',
    'Lehenga With Choli & Dupatta',
  ];

  static const List<String> defaultStitching = [
    'Unstitched',
    'Fully Stitched',
    'Semi Stitched',
  ];

  static const List<String> defaultFabric = [
    'Cotton', 'Cotton Blend', 'Rayon', 'Silk', 'Gaji Silk', 'Organza',
    'Chiffon', 'Georgette', 'Crepe', 'Velvet', 'Linen', 'Chanderi',
    'Banarasi', 'Net', 'Satin',
  ];

  static const List<String> defaultWork = [
    'Printed', 'Embroidery', 'Hand Embroidery', 'Thread Work',
    'Mirror Work', 'Zari Work', 'Sequin Work', 'Aari Work',
    'Foil Print', 'Block Print', 'Handwork', 'Embellished', 'Plain',
  ];

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

  static Future<List<String>> getProductNames() async =>
      [...defaultProductNames, ...await _getCustom(_productNameKey)];
  static Future<List<String>> getStitching() async =>
      [...defaultStitching, ...await _getCustom(_stitchingKey)];
  static Future<List<String>> getFabric() async =>
      [...defaultFabric, ...await _getCustom(_fabricKey)];
  static Future<List<String>> getWork() async =>
      [...defaultWork, ...await _getCustom(_workKey)];
  static Future<List<String>> getCategories() async =>
      [...defaultCategories, ...await _getCustom(_categoryKey)];

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
