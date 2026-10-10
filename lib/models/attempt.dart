import 'dart:math';


import 'category.dart';

class Attempt {
  Attempt(
    this.category,
    this.score, {
    List<int?>? selectedAnswers,
    DateTime? completedAt,
    this.mode = 'Practice',
    this.negativeMarking = 0.25,
  }) : selectedAnswers =
           selectedAnswers ??
           List<int?>.filled(category.questions.length, null),
       completedAt = completedAt ?? DateTime.now();

  final Category category;
  final double score;
  final List<int?> selectedAnswers;
  final DateTime completedAt;
  final String mode;
  final double negativeMarking;

  int get total => category.questions.length;
  int get correctCount => selectedAnswers
      .asMap()
      .entries
      .where(
        (entry) =>
            entry.value != null &&
            entry.key < category.questions.length &&
            entry.value == category.questions[entry.key].answer,
      )
      .length;
  int get answeredCount => selectedAnswers.whereType<int>().length;
  int get wrongCount => answeredCount - correctCount;
  int get skippedCount => max(0, total - answeredCount);

  double get netScore {
    final net = (correctCount * 1.0) - (wrongCount * negativeMarking);
    return max(0.0, net);
  }

  double get accuracy =>
      answeredCount == 0 ? 0.0 : (correctCount / answeredCount) * 100;

  Map<String, dynamic> toJson() => {
    'name': category.name,
    'source': category.subtitle,
    'score': score,
    'total': total,
    'answers': selectedAnswers,
    'questions': category.questions
        .map((question) => question.toStorageJson())
        .toList(),
    'completedAt': completedAt.toIso8601String(),
    'mode': mode,
    'negativeMarking': negativeMarking,
  };
}
