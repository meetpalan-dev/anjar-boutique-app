import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'post_history_store.dart';
import 'suggestions_store.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  List<PostRecord> _results = [];
  List<String> _categories = [];
  String? _categoryFilter;
  DateTime? _dateFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _runSearch();
    _searchCtrl.addListener(_runSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await SuggestionsStore.getCategories();
    if (!mounted) return;
    setState(() => _categories = cats);
  }

  Future<void> _runSearch() async {
    setState(() => _loading = true);
    final results = await PostHistoryStore.search(
      query: _searchCtrl.text,
      category: _categoryFilter,
      date: _dateFilter,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateFilter = picked);
      _runSearch();
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, ID, or caption text',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text(_dateFilter == null ? 'Any date' : _formatDate(_dateFilter!)),
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    selected: _dateFilter != null,
                    onSelected: (_) => _pickDate(),
                    onDeleted: _dateFilter == null
                        ? null
                        : () {
                            setState(() => _dateFilter = null);
                            _runSearch();
                          },
                  ),
                  const SizedBox(width: 8),
                  ..._categories.map((c) {
                    final selected = _categoryFilter == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() => _categoryFilter = sel ? c : null);
                          _runSearch();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No posts found', style: TextStyle(color: Colors.black45)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: File(r.imagePath).existsSync()
                                  ? Image.file(File(r.imagePath), width: 48, height: 48, fit: BoxFit.cover)
                                  : const SizedBox(width: 48, height: 48),
                            ),
                            title: Text(r.productName.isEmpty ? '(no name)' : r.productName),
                            subtitle: Text('${r.id} · ${r.category} · ${_formatDate(r.createdAt)}'),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(record: r)));
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class PostDetailScreen extends StatelessWidget {
  final PostRecord record;
  const PostDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final file = File(record.imagePath);
    return Scaffold(
      appBar: AppBar(title: Text(record.id)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (file.existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(file),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(record.caption),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: record.caption));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caption copied')));
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Caption'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: file.existsSync()
                        ? () => Share.shareXFiles([XFile(file.path)], text: record.caption)
                        : null,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
