import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordCtrl = TextEditingController();
  final _transCtrl = TextEditingController();
  final _langCtrl = TextEditingController();
  final ApiService _api = ApiService();
  bool _saving = false;

  @override
  void dispose() {
    _wordCtrl.dispose();
    _transCtrl.dispose();
    _langCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _api.addWord(
        _wordCtrl.text.trim(),
        _transCtrl.text.trim(),
        _langCtrl.text.trim().isNotEmpty ? _langCtrl.text.trim() : 'English',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${_wordCtrl.text}"'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Word'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Word field
              TextFormField(
                controller: _wordCtrl,
                decoration: InputDecoration(
                  labelText: 'Word',
                  hintText: 'e.g. serendipity',
                  prefixIcon: const Icon(Icons.text_fields),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Translation field
              TextFormField(
                controller: _transCtrl,
                decoration: InputDecoration(
                  labelText: 'Translation',
                  hintText: 'e.g. 意外发现的幸运',
                  prefixIcon: const Icon(Icons.translate),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Language field
              TextFormField(
                controller: _langCtrl,
                decoration: InputDecoration(
                  labelText: 'Language (optional)',
                  hintText: 'e.g. English',
                  prefixIcon: const Icon(Icons.language),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),

              // Save button
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Adding...' : 'Add Word'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
