import '../../../core/local_date.dart';
import '../../../core/network/api_client.dart';

class VocabEntry {
  VocabEntry({
    required this.id,
    required this.word,
    required this.translationUz,
    required this.progress,
    required this.flashcardMastered,
    required this.displayTag,
    required this.savedForPractice,
  });

  final String id;
  final String word;
  final String translationUz;
  final double progress;
  final bool flashcardMastered;
  final String displayTag;
  final bool savedForPractice;

  factory VocabEntry.fromJson(Map<String, dynamic> json) {
    return VocabEntry(
      id: json['id'] as String,
      word: json['word'] as String,
      translationUz: json['translation_uz'] as String,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      flashcardMastered: json['flashcard_mastered'] == true,
      displayTag: json['display_tag'] as String? ?? 'Tapped',
      savedForPractice: json['saved_for_practice'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'translation_uz': translationUz,
        'progress': progress,
        'flashcard_mastered': flashcardMastered,
        'display_tag': displayTag,
        'saved_for_practice': savedForPractice,
      };
}

class LexiconWord {
  LexiconWord({
    required this.word,
    required this.translationBaseUz,
    required this.savedForPractice,
  });

  final String word;
  final String translationBaseUz;
  final bool savedForPractice;

  factory LexiconWord.fromJson(Map<String, dynamic> json) {
    return LexiconWord(
      word: json['word'] as String,
      translationBaseUz: json['translation_base_uz'] as String? ?? '',
      savedForPractice: json['saved_for_practice'] == true,
    );
  }
}

class VocabDaysPayload {
  const VocabDaysPayload({
    required this.dates,
    this.memberSinceIso,
  });

  final List<String> dates;
  final String? memberSinceIso;
}

class VocabRepository {
  VocabRepository(this._apiClient);

  final ApiClient _apiClient;

  static String localDateKey(DateTime local) => formatLocalDate(local);

  Future<VocabDaysPayload> listDaysWithWords() async {
    final json = await _apiClient.getJson(
      '/vocab/days',
      authenticated: true,
    );
    if (json is! Map<String, dynamic>) {
      return const VocabDaysPayload(dates: []);
    }
    final dates = json['dates'];
    final list = dates is List ? dates.whereType<String>().toList() : <String>[];
    final memberSince = json['member_since'] as String?;
    return VocabDaysPayload(dates: list, memberSinceIso: memberSince);
  }

  Future<List<LexiconWord>> fetchLexicon() async {
    final json = await _apiClient.getJson(
      '/vocab/lexicon',
      authenticated: true,
    );
    if (json is! Map<String, dynamic>) return [];
    final words = json['words'];
    if (words is! List) return [];
    return words
        .whereType<Map<String, dynamic>>()
        .map(LexiconWord.fromJson)
        .toList();
  }

  Future<List<VocabEntry>> listForLocalDate(DateTime localDay) async {
    final localDate = localDateKey(localDay);
    final json = await _apiClient.getJson(
      '/vocab?localDate=${Uri.encodeComponent(localDate)}',
      authenticated: true,
    );
    final items = json is List ? json : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(VocabEntry.fromJson)
        .toList();
  }

  Future<void> saveForPractice({
    required String word,
    required String translationUz,
    required String contextSentence,
    String? materialId,
  }) async {
    await _apiClient.postJson(
      '/vocab',
      authenticated: true,
      body: {
        'word': word,
        'translation_uz': translationUz,
        'context_sentence': contextSentence,
        if (materialId != null) 'material_id': materialId,
        'local_date': localDateKey(DateTime.now()),
      },
    );
  }

  Future<Map<String, dynamic>> translateWord({
    required String word,
    required String contextSentence,
    String? materialId,
  }) async {
    final json = await _apiClient.postJson(
      '/translate',
      body: {
        'word': word,
        'context_sentence': contextSentence,
        'local_date': localDateKey(DateTime.now()),
        if (materialId != null) 'material_id': materialId,
      },
      authenticated: true,
    );
    if (json is! Map<String, dynamic>) {
      throw const ApiException('Invalid translate response.');
    }
    return json;
  }

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
