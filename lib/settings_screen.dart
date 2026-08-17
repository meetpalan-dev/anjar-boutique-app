import 'package:flutter/material.dart';
import 'suggestions_store.dart';
import 'theme_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, List<String>> _custom = {
    'Product Name': [],
    'Stitching': [],
    'Fabric': [],
    'Work': [],
    'Category': [],
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final pn = await SuggestionsStore.getCustomProductNames();
    final st = await SuggestionsStore.getCustomStitching();
    final fb = await SuggestionsStore.getCustomFabric();
    final wk = await SuggestionsStore.getCustomWork();
    final cat = await SuggestionsStore.getCustomCategories();
    if (!mounted) return;
    setState(() {
      _custom = {'Product Name': pn, 'Stitching': st, 'Fabric': fb, 'Work': wk, 'Category': cat};
    });
  }

  Future<void> _add(String category) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $category Suggestion'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    switch (category) {
      case 'Product Name':
        await SuggestionsStore.addProductName(value);
        break;
      case 'Stitching':
        await SuggestionsStore.addStitching(value);
        break;
      case 'Fabric':
        await SuggestionsStore.addFabric(value);
        break;
      case 'Work':
        await SuggestionsStore.addWork(value);
        break;
      case 'Category':
        await SuggestionsStore.addCategory(value);
        break;
    }
    _reload();
  }

  Future<void> _remove(String category, String value) async {
    switch (category) {
      case 'Product Name':
        await SuggestionsStore.removeProductName(value);
        break;
      case 'Stitching':
        await SuggestionsStore.removeStitching(value);
        break;
      case 'Fabric':
        await SuggestionsStore.removeFabric(value);
        break;
      case 'Work':
        await SuggestionsStore.removeWork(value);
        break;
      case 'Category':
        await SuggestionsStore.removeCategory(value);
        break;
    }
    _reload();
  }

  Widget _section(String category) {
    final items = _custom[category] ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$category Suggestions', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              TextButton.icon(
                onPressed: () => _add(category),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('No custom suggestions added yet — defaults are always shown on the form.',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items.map((v) => Chip(label: Text(v), onDeleted: () => _remove(category, v))).toList(),
            ),
        ],
      ),
    );
  }

  Widget _themeSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeStore.mode,
            builder: (context, mode, _) {
              return SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                  ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto)),
                ],
                selected: {mode},
                onSelectionChanged: (s) => ThemeStore.set(s.first),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _themeSection(),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Manage extra suggestions shown on the Product Details form. Default suggestions are always available and can\'t be removed here.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _section('Product Name'),
          _section('Category'),
          _section('Stitching'),
          _section('Fabric'),
          _section('Work'),
        ],
      ),
    );
  }
}
