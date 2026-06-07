import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/word.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final ApiService _api = ApiService();
  List<Word> _words = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() => _loading = true);
    try {
      _words = await _api.getWords();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteWord(Word word) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text('Remove "${word.word}" and all its progress?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _api.deleteWord(word.id);
      _loadWords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word List'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No words yet', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Add your first word to start learning!',
                          style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWords,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _words.length,
                    itemBuilder: (context, index) {
                      final word = _words[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              word.word[0].toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(word.word,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${word.translation}${word.language.isNotEmpty ? '  •  ${word.language}' : ''}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteWord(word),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
