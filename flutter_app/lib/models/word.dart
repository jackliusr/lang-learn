class Word {
  final int id;
  final String word;
  final String translation;
  final String language;
  final String notes;
  final String createdAt;

  Word({
    required this.id,
    required this.word,
    required this.translation,
    this.language = '',
    this.notes = '',
    this.createdAt = '',
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as int,
      word: json['word'] as String,
      translation: json['translation'] as String,
      language: json['language'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'translation': translation,
        'language': language,
        'notes': notes,
      };
}
