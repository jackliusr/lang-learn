import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stats.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ApiService _api = ApiService();
  Stats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      _stats = await _api.getStats();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: theme.colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? const Center(child: Text('Could not load stats'))
              : _buildStats(theme),
    );
  }

  Widget _buildStats(ThemeData theme) {
    final s = _stats!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview
          Text('Learning Overview', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox(theme, 'Total', '${s.totalWords}', Icons.abc, null,
                  null),
              const SizedBox(width: 8),
              _statBox(
                  theme, 'Learned', '${s.wordsLearned}', Icons.check_circle,
                  Colors.green, Colors.green[50]),
              const SizedBox(width: 8),
              _statBox(theme, 'Learning', '${s.wordsLearning}',
                  Icons.school, Colors.orange, Colors.orange[50]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statBox(theme, 'New', '${s.wordsNew}', Icons.fiber_new,
                  theme.colorScheme.primary, theme.colorScheme.primaryContainer),
              const SizedBox(width: 8),
              _statBox(theme, 'Due Today', '${s.dueToday}',
                  Icons.today_outlined, Colors.red, Colors.red[50]),
              const SizedBox(width: 8),
              _statBox(theme, 'Reviews', '${s.reviewsToday}',
                  Icons.rate_review, Colors.blue, Colors.blue[50]),
            ],
          ),

          const SizedBox(height: 32),

          // Stability section
          Text('Memory Stability', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 40, color: theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.averageStability.toStringAsFixed(1)} days',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Average Stability',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Learning distribution
          Text('Learning Distribution', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _progressRow(theme, 'Learned', s.wordsLearned, s.totalWords,
                      Colors.green),
                  const SizedBox(height: 12),
                  _progressRow(theme, 'Learning', s.wordsLearning, s.totalWords,
                      Colors.orange),
                  const SizedBox(height: 12),
                  _progressRow(theme, 'New', s.wordsNew, s.totalWords,
                      theme.colorScheme.primary),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Tips
          Card(
            color: theme.colorScheme.primaryContainer.withAlpha(100),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FSRS Tip',
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          s.averageStability > 7
                              ? 'Great job! Your memory stability is solid. Keep reviewing consistently.'
                              : s.dueToday > 0
                                  ? 'You have ${s.dueToday} card${s.dueToday > 1 ? 's' : ''} due. Regular reviews build long-term memory!'
                                  : 'Add more words to grow your vocabulary.',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statBox(ThemeData theme, String label, String value, IconData icon,
      Color? iconColor, Color? bgColor) {
    return Expanded(
      child: Card(
        color: bgColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, size: 24, color: iconColor ?? Colors.grey[600]),
              const SizedBox(height: 8),
              Text(value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressRow(ThemeData theme, String label, int count, int total,
      Color color) {
    final ratio = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text('$count / $total',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withAlpha(30),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
