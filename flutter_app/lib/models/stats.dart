class Stats {
  final int totalWords;
  final int wordsLearned;
  final int wordsLearning;
  final int wordsNew;
  final int dueToday;
  final int reviewsToday;
  final double averageStability;

  Stats({
    required this.totalWords,
    required this.wordsLearned,
    required this.wordsLearning,
    required this.wordsNew,
    required this.dueToday,
    required this.reviewsToday,
    required this.averageStability,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalWords: json['total_words'] as int,
      wordsLearned: json['words_learned'] as int,
      wordsLearning: json['words_learning'] as int,
      wordsNew: json['words_new'] as int,
      dueToday: json['due_today'] as int,
      reviewsToday: json['reviews_today'] as int,
      averageStability: (json['average_stability'] as num).toDouble(),
    );
  }
}
