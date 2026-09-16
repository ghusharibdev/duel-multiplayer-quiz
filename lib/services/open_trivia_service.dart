import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question.dart';

class OpenTriviaService {
  static const String _baseUrl = 'https://opentdb.com/api.php';

  /// Available trivia categories from Open Trivia DB
  static const Map<int, String> categories = {
    9: 'General Knowledge',
    10: 'Entertainment: Books',
    11: 'Entertainment: Film',
    12: 'Entertainment: Music',
    13: 'Entertainment: Musicals & Theatre',
    14: 'Entertainment: Television',
    15: 'Entertainment: Video Games',
    16: 'Entertainment: Board Games',
    17: 'Science & Nature',
    18: 'Science: Computers',
    19: 'Science: Mathematics',
    20: 'Mythology',
    21: 'Sports',
    22: 'Geography',
    23: 'History',
    24: 'Politics',
    25: 'Art',
    26: 'Celebrities',
    27: 'Animals',
    28: 'Vehicles',
    29: 'Entertainment: Comics',
    30: 'Science: Gadgets',
    31: 'Entertainment: Japanese Anime & Manga',
    32: 'Entertainment: Cartoon & Animations',
  };

  static const Map<int, String> difficultyLabels = {
    1: 'easy',
    2: 'medium',
    3: 'hard',
  };

  /// Fetch [count] random questions, optionally filtered by category and difficulty.
  /// [categoryId] = null means random categories.
  /// [difficulty] = null means random difficulty.
  Future<List<Question>> fetchRandomQuestions(
    int count, {
    int? categoryId,
    int? difficulty,
  }) async {
    try {
      final params = <String, String>{
        'amount': '$count',
        'type': 'multiple',
      };
      if (categoryId != null) {
        params['category'] = '$categoryId';
      }
      if (difficulty != null && difficultyLabels.containsKey(difficulty)) {
        params['difficulty'] = difficultyLabels[difficulty]!;
      }

      final url = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch questions: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['response_code'] != 0) {
        throw Exception('API error: response_code ${data['response_code']}');
      }

      final results = data['results'] as List<dynamic>;
      final questions = <Question>[];

      for (int i = 0; i < results.length; i++) {
        final item = results[i] as Map<String, dynamic>;

        // Decode HTML entities and strip tags
        final questionText = _decodeHtml(item['question'] ?? '');
        final correctAnswer = _decodeHtml(item['correct_answer'] ?? '');
        final incorrectAnswers = (item['incorrect_answers'] as List<dynamic>?)
                ?.map((a) => _decodeHtml(a.toString()))
                .toList() ??
            [];

        // Shuffle options and track correct index
        final options = [correctAnswer, ...incorrectAnswers]..shuffle();
        final correctIndex = options.indexOf(correctAnswer);

        questions.add(Question(
          id: 'opentdb_${DateTime.now().millisecondsSinceEpoch}_$i',
          text: questionText,
          options: options,
          correctIndex: correctIndex,
          category: _decodeHtml(item['category'] ?? 'General'),
          difficulty: _difficultyToInt(item['difficulty'] ?? 'easy'),
        ));
      }

      return questions;
    } catch (e) {
      throw Exception('Failed to fetch questions: $e');
    }
  }

  String _decodeHtml(String html) {
    String result = html
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&Eacute;', 'É')
        .replaceAll('&ntilde;', 'ñ')
        .replaceAll('&Ntilde;', 'Ñ')
        .replaceAll('&ouml;', 'ö')
        .replaceAll('&Ouml;', 'Ö')
        .replaceAll('&uuml;', 'ü')
        .replaceAll('&Uuml;', 'Ü')
        .replaceAll('&iacute;', 'í')
        .replaceAll('&Iacute;', 'Í')
        .replaceAll('&oacute;', 'ó')
        .replaceAll('&Oacute;', 'Ó')
        .replaceAll('&uacute;', 'ú')
        .replaceAll('&Uacute;', 'Ú')
        .replaceAll('&aacute;', 'á')
        .replaceAll('&Aacute;', 'Á')
        .replaceAll('&agrave;', 'à')
        .replaceAll('&egrave;', 'è')
        .replaceAll('&igrave;', 'ì')
        .replaceAll('&ograve;', 'ò')
        .replaceAll('&ugrave;', 'ù')
        .replaceAll('&acirc;', 'â')
        .replaceAll('&ecirc;', 'ê')
        .replaceAll('&icirc;', 'î')
        .replaceAll('&ocirc;', 'ô')
        .replaceAll('&ucirc;', 'û')
        .replaceAll('&ccedil;', 'ç')
        .replaceAll('&Ccedil;', 'Ç')
        .replaceAll('&szlig;', 'ß')
        .replaceAll('&deg;', '°')
        .replaceAll('&shy;', '\u00AD')
        .replaceAll('&lrm;', '\u200E')
        .replaceAll('&rlm;', '\u200F')
        .replaceAll('&nbsp;', ' ');

    // Decode numeric entities: &#123; and &#x7B;
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final codePoint = int.parse(match.group(1)!);
        return String.fromCharCode(codePoint);
      },
    );
    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) {
        final codePoint = int.parse(match.group(1)!, radix: 16);
        return String.fromCharCode(codePoint);
      },
    );

    // Strip any remaining HTML tags
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    return result;
  }

  int _difficultyToInt(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 1;
      case 'medium':
        return 2;
      case 'hard':
        return 3;
      default:
        return 1;
    }
  }
}
