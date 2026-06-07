import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/word.dart';
import '../models/card.dart';
import '../models/stats.dart';

class ApiService {
  // Change this to your backend URL
  static const String baseUrl = 'http://10.0.2.2:8000';

  Future<List<Word>> getWords() async {
    final res = await http.get(Uri.parse('$baseUrl/api/words'));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((json) => Word.fromJson(json)).toList();
    }
    throw Exception('Failed to load words: ${res.statusCode}');
  }

  Future<Word> addWord(String word, String translation, String language) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/words'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'word': word,
        'translation': translation,
        'language': language,
      }),
    );
    if (res.statusCode == 200) {
      return Word.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to add word: ${res.body}');
  }

  Future<void> deleteWord(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/words/$id'));
    if (res.statusCode != 200) {
      throw Exception('Failed to delete word');
    }
  }

  Future<List<ReviewSession>> getDueReviews({int limit = 10}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/review/due?limit=$limit'),
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((json) => ReviewSession.fromJson(json)).toList();
    }
    throw Exception('Failed to load due reviews: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> submitReview(int cardId, int grade) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/review/submit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'card_id': cardId, 'grade': grade}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to submit review: ${res.body}');
  }

  Future<Stats> getStats() async {
    final res = await http.get(Uri.parse('$baseUrl/api/stats'));
    if (res.statusCode == 200) {
      return Stats.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load stats: ${res.statusCode}');
  }
}
