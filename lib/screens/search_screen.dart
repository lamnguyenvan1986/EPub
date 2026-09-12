import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  final String bookTitle;
  final String content;
  
  const SearchScreen({
    super.key,
    required this.bookTitle,
    required this.content,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _matches = <String>[];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _matches = [];
      });
      return;
    }

    final matches = <String>[];
    final lines = widget.content.split('\n');
    lines.asMap().forEach((index, line) {
      if (line.toLowerCase().contains(query)) {
        matches.add(line);
      }
    });

    setState(() {
      _matches = matches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tìm kiếm trong: ${widget.bookTitle}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _search();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Nhập từ khóa...',
                hintText: 'Ví dụ: yêu thương',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _search();
                      },
                    )
                  : null,
              ),
              onChanged: (_) => _search(),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: _matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary.withAlpha(128),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Không tìm thấy kết quả',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thử từ khóa khác hoặc kiểm tra chính tả',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final match = _matches[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(match),
                        subtitle: Text(
                          'Vị trí: ${widget.content.indexOf(match)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () {
                          // Scroll to position (would need more implementation)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đang tìm: $match')),
                          );
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
