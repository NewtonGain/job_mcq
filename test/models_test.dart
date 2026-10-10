import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_mcq/models/attempt.dart';
import 'package:job_mcq/models/category.dart';
import 'package:job_mcq/models/question.dart';

void main() {
  group('Question', () {
    test('restores the answer from persisted score values', () {
      const question = Question(
        'Which option is correct?',
        ['First', 'Second', 'Third'],
        1,
        'The second option is correct.',
      );

      final restored = Question.fromAsset(question.toStorageJson());

      expect(restored, isNotNull);
      expect(restored!.text, question.text);
      expect(restored.options, question.options);
      expect(restored.answer, question.answer);
      expect(restored.explanation, question.explanation);
    });

    test('rejects questions with ambiguous scored answers', () {
      final question = Question.fromAsset({
        'question': 'Which option is correct?',
        'answers': [
          {'text': 'First', 'score': 1},
          {'text': 'Second', 'score': 1},
        ],
      });

      expect(question, isNull);
    });
  });

  test('calculates attempt totals, accuracy, and negative marking', () {
    const questions = [
      Question('First?', ['A', 'B'], 0, ''),
      Question('Second?', ['A', 'B'], 0, ''),
      Question('Third?', ['A', 'B'], 1, ''),
    ];
    final category = Category(
      'Practice',
      'test',
      Icons.quiz,
      Colors.blue,
      questions,
    );
    final attempt = Attempt(
      category,
      0.75,
      selectedAnswers: const [0, 1, null],
      negativeMarking: 0.25,
    );

    expect(attempt.correctCount, 1);
    expect(attempt.wrongCount, 1);
    expect(attempt.skippedCount, 1);
    expect(attempt.accuracy, 50);
    expect(attempt.netScore, 0.75);
  });
}
