import '../../../core/network/api_client.dart';

/// Single vocabulary row for the current local calendar day (server prunes older rows on fetch).
class VocabEntry {
  VocabEntry({
    required this.id,
    required this.word,
    required this.translationUz,
    required this.progress,
    required this.displayTag,
  });

  final String id;
  final String word;
  final String translationUz;
  final double progress;
  final String displayTag;

  factory VocabEntry.fromJson(Map<String, dynamic> json) {
    return VocabEntry(
      id: json['id'] as String,
      word: json['word'] as String,
      translationUz: json['translation_uz'] as String,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      displayTag: json['display_tag'] as String? ?? 'Saved',
    );
  }
}

class VocabRepository {
  VocabRepository(this._apiClient);

  final ApiClient _apiClient;

  /// [now] should be `DateTime.now()` in the device local timezone.
  Future<List<VocabEntry>> listForLocalDay(DateTime now) async {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final qs =
        '?dayStart=${Uri.encodeComponent(start.toUtc().toIso8601String())}'
        '&dayEnd=${Uri.encodeComponent(end.toUtc().toIso8601String())}';
    final json = await _apiClient.getJson('/vocab$qs', authenticated: true);
    final items = json is List ? json : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(VocabEntry.fromJson)
        .toList();
  }

  /// Records quiz or flashcard practice. See backend `POST /vocab/practice` for [action] values.
  Future<void> recordPractice({
    required String vocabId,
    required String action,
  }) async {
    await _apiClient.postJson(
      '/vocab/practice',
      body: {'vocab_id': vocabId, 'action': action},
      authenticated: true,
    );
  }
}
