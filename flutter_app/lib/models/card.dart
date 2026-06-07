class ReviewContent {
  final int id;
  final String contentType;
  final Map<String, dynamic> content;
  final String createdAt;

  ReviewContent({
    required this.id,
    required this.contentType,
    required this.content,
    required this.createdAt,
  });

  factory ReviewContent.fromJson(Map<String, dynamic> json) {
    return ReviewContent(
      id: json['id'] as int,
      contentType: json['content_type'] as String,
      content: json['content'] as Map<String, dynamic>,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class ReviewSession {
  final int cardId;
  final int wordId;
  final String word;
  final String translation;
  final List<ReviewContent> content;
  final Map<String, dynamic> stats;

  ReviewSession({
    required this.cardId,
    required this.wordId,
    required this.word,
    required this.translation,
    required this.content,
    required this.stats,
  });

  factory ReviewSession.fromJson(Map<String, dynamic> json) {
    return ReviewSession(
      cardId: json['card_id'] as int,
      wordId: json['word_id'] as int,
      word: json['word'] as String,
      translation: json['translation'] as String,
      content: (json['content'] as List)
          .map((c) => ReviewContent.fromJson(c as Map<String, dynamic>))
          .toList(),
      stats: json['stats'] as Map<String, dynamic>,
    );
  }
}
