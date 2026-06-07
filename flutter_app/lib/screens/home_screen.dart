import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stats.dart';
import 'word_list_screen.dart';
import 'add_word_screen.dart';
import 'review_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  Stats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      _stats = await _api.getStats();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('LangLearn'),
        backgroundColor: theme.colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildDashboard(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddWordScreen()),
          );
          _loadStats();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Word'),
      ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Could not connect to backend',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(ThemeData theme) {
    final stats = _stats!;
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Due today card
          _buildDueCard(theme, stats),
          const SizedBox(height: 20),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  Icons.check_circle_outline,
                  'Learned',
                  '${stats.wordsLearned}',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  Icons.school_outlined,
                  'Learning',
                  '${stats.wordsLearning}',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  Icons.fiber_new_outlined,
                  'New',
                  '${stats.wordsNew}',
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Review activity & stability
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  theme,
                  Icons.today_outlined,
                  'Reviews Today',
                  '${stats.reviewsToday}',
                  Icons.auto_awesome,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  theme,
                  Icons.trending_up,
                  'Avg Stability',
                  '${stats.averageStability.toStringAsFixed(1)}d',
                  Icons.shield_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick actions
          Text('Quick Actions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  theme,
                  Icons.menu_book_rounded,
                  'Word List',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WordListScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  theme,
                  Icons.rate_review_outlined,
                  'Review',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReviewScreen()),
                  ).then((_) => _loadStats()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDueCard(ThemeData theme, Stats stats) {
    final due = stats.dueToday;
    return Card(
      color: due > 0 ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReviewScreen()),
          ).then((_) => _loadStats());
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: due > 0
                      ? theme.colorScheme.primary
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.rate_review_rounded,
                  size: 36,
                  color: due > 0 ? Colors.white : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      due > 0 ? 'Cards Due Today' : 'All Caught Up!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      due > 0
                          ? '$due word${due > 1 ? 's' : ''} need${due > 1 ? '' : 's'} review'
                          : 'No cards due. Add more words!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (due > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '$due',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      ThemeData theme, IconData icon, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, IconData icon, String label,
      String value, IconData trailingIcon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const Spacer(),
                Icon(trailingIcon, size: 16, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: theme.colorScheme.primary,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.menu_book), label: 'Words'),
        BottomNavigationBarItem(
            icon: Icon(Icons.rate_review), label: 'Review'),
      ],
      onTap: (index) {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WordListScreen()),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReviewScreen()),
          ).then((_) => _loadStats());
        }
      },
    );
  }
}
