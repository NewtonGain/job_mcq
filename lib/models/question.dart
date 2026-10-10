class Question {
  const Question(
    this.text,
    this.options,
    this.answer,
    this.explanation, {
    this.tags = const [],
  });

  final String text;
  final List<String> options;
  final int answer;
  final String explanation;
  final List<String> tags;

  String getCleanOption(int index) {
    if (index < 0 || index >= options.length) return '';
    final opt = options[index].trim();
    final cleanRegex = RegExp(r'^[A-Da-d1-4][\.\)]\s*');
    return opt.replaceAll(cleanRegex, '').trim();
  }

  String get cleanText {
    final cleanRegex = RegExp(r'^\d+[\.\)]\s*');
    return text.replaceAll(cleanRegex, '').trim();
  }

  static Question? fromAsset(Map<String, dynamic> json) {
    final rawAnswers = json['answers'];
    if (rawAnswers is! List<dynamic>) return null;
    final answers = rawAnswers
        .whereType<Map>()
        .map((answer) => Map<String, dynamic>.from(answer))
        .toList();
    if (answers.length < 2) return null;
    final options = answers.map((item) => _cleanText(item['text'])).toList();
    if (options.any((option) => option.isEmpty)) return null;

    final rawCorrect = json['correct_answer'];
    int correctIndex = -1;
    if (rawCorrect is num) {
      correctIndex = rawCorrect.toInt();
    } else {
      final cleanCorrect = _cleanText(rawCorrect);
      correctIndex = int.tryParse(cleanCorrect) ?? -1;
      if (correctIndex < 0 || correctIndex >= options.length) {
        if (cleanCorrect.length == 1) {
          final upper = cleanCorrect.toUpperCase();
          if (upper.codeUnitAt(0) >= 65 &&
              upper.codeUnitAt(0) < 65 + options.length) {
            correctIndex = upper.codeUnitAt(0) - 65;
          }
        }
      }
      if (correctIndex < 0 || correctIndex >= options.length) {
        correctIndex = answers.indexWhere(
          (item) => _cleanText(item['text']) == cleanCorrect,
        );
      }
    }

    final scored = answers
        .map((item) => _scoreValue(item['score']))
        .where((score) => score == 1)
        .length;
    final answerIndex = correctIndex >= 0 && correctIndex < options.length
        ? correctIndex
        : scored == 1
        ? answers.indexWhere((item) => _scoreValue(item['score']) == 1)
        : -1;
    final text = _cleanText(json['question']);
    if (text.isEmpty || answerIndex < 0) return null;

    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];

    return Question(
      text,
      options,
      answerIndex,
      _cleanText(json['hint']),
      tags: tags,
    );
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'question': text,
      'answers': [
        for (var index = 0; index < options.length; index++)
          {'text': options[index], 'score': index == answer ? 1 : 0},
      ],
      'hint': explanation,
      'tags': tags,
    };
  }

  static String _cleanText(Object? value) => value?.toString().trim() ?? '';

  static num? _scoreValue(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString().trim() ?? '');
  }
}
