import '../../../core/network/api_client.dart';

class VocabEntry {
  VocabEntry({
    required this.id,
    required this.word,
    required this.translationUz,
  });

  final String id;
  final String word;
  final String translationUz;

  factory VocabEntry.fromJson(Map<String, dynamic> json) {
    return VocabEntry(
      id: json['id'] as String,
      word: json['word'] as String,
      translationUz: json['translation_uz'] as String,
    );
  }
}

class VocabStats {
  VocabStats({
    required this.totalWords,
    required this.masteredCount,
    required this.learningCount,
    required this.masteryPercent,
  });

  final int totalWords;
  final int masteredCount;
  final int learningCount;
  final double masteryPercent;

  factory VocabStats.fromJson(Map<String, dynamic> json) {
    return VocabStats(
      totalWords: json['totalWords'] as int? ?? 0,
      masteredCount: json['masteredCount'] as int? ?? 0,
      learningCount: json['learningCount'] as int? ?? 0,
      masteryPercent:
          (json['masteryPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VocabRepository {
  VocabRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<VocabEntry>> listEntries() async {
    final json = await _apiClient.getJson('/vocab', authenticated: true);
    final items = json is List ? json : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(VocabEntry.fromJson)
        .toList();
  }

  Future<VocabStats> loadStats() async {
    final json =
        await _apiClient.getJson('/vocab/stats', authenticated: true)
            as Map<String, dynamic>;
    return VocabStats.fromJson(json);
  }
}

