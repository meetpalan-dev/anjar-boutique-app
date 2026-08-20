import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'post_history_store.dart';
import 'suggestions_store.dart';
import 'history_io.dart';
import 'product_id_store.dart';

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

  Future<void> _confirmDelete(PostRecord r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this product?'),
        content: const Text('This will remove the product from Post History.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PostHistoryStore.softDelete(r.id);
      _runSearch();
    }
  }

  Future<void> _import() async {
    final message = await HistoryIO.import();
    if (message.isEmpty) return; // cancelled
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Export',
            onPressed: () => HistoryIO.export(),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import',
            onPressed: _import,
          ),
        ],
      ),
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No posts found', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          final priceLabel = r.sellingPrice != null ? '₹${r.sellingPrice!.toStringAsFixed(0)}' : null;
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: File(r.imagePath).existsSync()
                                  ? Image.file(File(r.imagePath), width: 48, height: 48, fit: BoxFit.cover)
                                  : const SizedBox(width: 48, height: 48),
                            ),
                            title: Text(r.productName.isEmpty ? '(no name)' : r.productName),
                            subtitle: Text(
                              '${r.parentId} · ${r.color.isEmpty ? r.category : r.color}\n'
                              '${priceLabel != null ? '$priceLabel · ' : ''}${_formatDate(r.createdAt)}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                              onPressed: () => _confirmDelete(r),
                            ),
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
    final profit = record.profit;
    final productDisplayName = record.productName.isEmpty ? record.parentId : record.productName;
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
            if (record.costPrice != null || record.sellingPrice != null || record.discountPrice != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pricing (internal only)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (record.costPrice != null) Text('Cost Price: ₹${record.costPrice!.toStringAsFixed(0)}'),
                    if (record.sellingPrice != null) Text('Selling Price: ₹${record.sellingPrice!.toStringAsFixed(0)}'),
                    if (record.discountPrice != null) Text('Discount Price: ₹${record.discountPrice!.toStringAsFixed(0)}'),
                    if (profit != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Profit: ₹${profit.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                PendingParentSelection.parentId = record.parentId;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text('Create New Post for $productDisplayName'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
            ),
          ],
        ),
      ),
    );
  }
}
