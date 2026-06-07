import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/card.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<ReviewSession> _cards = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _showAnswer = false;
  int? _selectedGrade;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _loadDueCards();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDueCards() async {
    setState(() => _loading = true);
    try {
      _cards = await _api.getDueReviews(limit: 20);
      _currentIndex = 0;
      _showAnswer = false;
      _selectedGrade = null;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submitGrade(int grade) async {
    if (_currentIndex >= _cards.length) return;
    final card = _cards[_currentIndex];
    setState(() => _selectedGrade = grade);

    try {
      await _api.submitReview(card.cardId, grade);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      setState(() {
        if (_currentIndex < _cards.length - 1) {
          _currentIndex++;
          _showAnswer = false;
          _selectedGrade = null;
          _animCtrl.forward(from: 0);
        } else {
          _cards = [];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? _buildEmptyState(theme)
              : _buildReviewSession(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.celebration_outlined,
                  size: 64, color: Colors.green),
            ),
            const SizedBox(height: 24),
            Text('All caught up!',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'No cards due for review right now.\nCome back later or add new words!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _loadDueCards,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSession(ThemeData theme) {
    final card = _cards[_currentIndex];
    final progress = '${_currentIndex + 1} / ${_cards.length}';

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _cards.length,
          backgroundColor: theme.colorScheme.primaryContainer,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(progress, style: TextStyle(color: Colors.grey[600])),
              Text(
                '${card.stats['retrievability'] != null ? (card.stats['retrievability'] * 100).toStringAsFixed(0) : '?'}% recall',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        // Card content
        Expanded(
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _showAnswer ? _buildAnswerCard(theme, card) : _buildQuestionCard(theme, card),
            ),
          ),
        ),

        // Bottom actions
        _buildBottomBar(theme, card),
      ],
    );
  }

  Widget _buildQuestionCard(ThemeData theme, ReviewSession card) {
    // Find the generated content
    final fullContent = card.content
        .where((c) => c.contentType == 'full_content')
        .firstOrNull;
    final sentences = fullContent?.content['sentences'] as List? ?? [];
    final quiz = card.content
        .where((c) => c.contentType == 'quiz')
        .firstOrNull;

    return Column(
      children: [
        // Word display
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              children: [
                Text(
                  card.word,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.translation,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer
                        .withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildChip(theme, '${card.stats['reps']} reps', Icons.repeat),
            const SizedBox(width: 8),
            _buildChip(theme,
                '${card.stats['difficulty']?.toStringAsFixed(1) ?? '?'} difficulty',
                Icons.speed),
            const SizedBox(width: 8),
            _buildChip(theme, card.stats['state'] as String? ?? '',
                Icons.circle_outlined),
          ],
        ),

        const SizedBox(height: 16),

        // Example sentences (if available)
        if (sentences.isNotEmpty) ...[
          Text('Example Sentences', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...sentences.take(2).map<Widget>((s) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['sentence'] ?? '',
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        s['translation'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],

        // Quiz question
        if (quiz != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.amber[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quiz.content['question'] ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Reveal button
        FilledButton.icon(
          onPressed: () => setState(() => _showAnswer = true),
          icon: const Icon(Icons.visibility),
          label: const Text('Show Answer'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerCard(ThemeData theme, ReviewSession card) {
    final fullContent = card.content
        .where((c) => c.contentType == 'full_content')
        .firstOrNull;
    final definition = fullContent?.content['definition'] as String?;
    final mnemonic = fullContent?.content['mnemonic'] as String?;
    final cloze = fullContent?.content['cloze'] as String?;

    return Column(
      children: [
        // Word + translation
        Card(
          color: Colors.green[50],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              children: [
                Text(
                  card.word,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.translation,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Definition
        if (definition != null) ...[
          _buildInfoSection(theme, 'Definition', definition, Icons.book_outlined),
          const SizedBox(height: 8),
        ],

        // Cloze
        if (cloze != null) ...[
          _buildInfoSection(
              theme, 'Fill in the blank', cloze, Icons.space_bar),
          const SizedBox(height: 8),
        ],

        // Mnemonic
        if (mnemonic != null) ...[
          _buildInfoSection(
              theme, 'Memory Aid', mnemonic, Icons.auto_awesome),
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 16),

        // Rate yourself
        Text('How well did you know it?',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),

        // Grade buttons
        Row(
          children: [
            Expanded(
              child: _gradeButton(theme, 1, 'Again', Icons.block, Colors.red),
            ),
            const SizedBox(width: 8),
            Expanded(
              child:
                  _gradeButton(theme, 2, 'Hard', Icons.sentiment_dissatisfied, Colors.orange),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _gradeButton(theme, 3, 'Good', Icons.sentiment_satisfied, Colors.green),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _gradeButton(theme, 4, 'Easy', Icons.rocket_launch, Colors.blue),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gradeButton(ThemeData theme, int grade, String label,
      IconData icon, Color color) {
    final selected = _selectedGrade == grade;
    return SizedBox(
      height: 80,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? color.withAlpha(30)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _selectedGrade == null ? () => _submitGrade(grade) : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 22,
                    color: selected ? color : Colors.grey[600]),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? color : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(ThemeData theme, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
      ThemeData theme, String title, String content, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(content, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, ReviewSession card) {
    if (!_showAnswer) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _currentIndex > 0
                ? () => setState(() {
                      _currentIndex--;
                      _showAnswer = false;
                      _selectedGrade = null;
                    })
                : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
          ),
          TextButton.icon(
            onPressed: _currentIndex < _cards.length - 1
                ? () => setState(() {
                      _currentIndex++;
                      _showAnswer = false;
                      _selectedGrade = null;
                      _animCtrl.forward(from: 0);
                    })
                : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}
