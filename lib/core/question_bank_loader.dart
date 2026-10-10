import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/exam_bank.dart';
import '../models/question.dart';

final class QuestionBankLoadResult {
  const QuestionBankLoadResult({
    required this.banks,
    required this.invalidQuestionCount,
    required this.failedBankCount,
  });

  final List<ExamBank> banks;
  final int invalidQuestionCount;
  final int failedBankCount;
}

abstract final class QuestionBankLoader {
  static Future<QuestionBankLoadResult> load() async {
    final paths = await _assetPaths();
    final results = await Future.wait(paths.map(_loadBank));
    return QuestionBankLoadResult(
      banks: [
        for (final result in results)
          if (result.bank != null) result.bank!,
      ],
      invalidQuestionCount: results.fold(
        0,
        (total, result) => total + result.invalidQuestionCount,
      ),
      failedBankCount: results.where((result) => result.bank == null).length,
    );
  }

  static Future<List<String>> _assetPaths() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where(
          (path) =>
              path.startsWith('assets/questions/') && path.endsWith('.json'),
        )
        .toList();
    paths.sort();
    return paths;
  }

  static Future<_BankLoadResult> _loadBank(String path) async {
    try {
      final decoded = jsonDecode(
        await rootBundle.loadString(path).timeout(const Duration(seconds: 2)),
      );
      final rawQuestions = decoded is List<dynamic>
          ? decoded
          : decoded is Map<String, dynamic>
          ? decoded['questions']
          : null;
      if (rawQuestions is! List<dynamic>) return const _BankLoadResult.failed();

      final parsedQuestions = rawQuestions
          .whereType<Map>()
          .map((item) => Question.fromAsset(Map<String, dynamic>.from(item)))
          .toList();
      final questions = parsedQuestions.whereType<Question>().toList();
      final baseFileName = path.split('/').last.replaceFirst('.json', '');
      final isGrade11To20 = path.contains('/grade_11_20/');
      final fileName = isGrade11To20
          ? 'grade_11_20_$baseFileName'
          : baseFileName;
      final gradeFolder = isGrade11To20
          ? path.split('/')[path.split('/').length - 2]
          : '';
      final group = isGrade11To20
          ? 'Grade 11-20'
          : baseFileName.startsWith('bcs')
          ? 'BCS'
          : baseFileName.startsWith('ntrca')
          ? 'NTRCA'
          : 'Primary';
      final title = isGrade11To20
          ? '$group • ${gradeFolder.replaceAll('_', ' ')} • ${baseFileName.replaceAll('_', ' ')}'
          : _standardTitle(baseFileName, group);

      return _BankLoadResult(
        ExamBank(title, group, fileName, questions),
        parsedQuestions.length - questions.length,
      );
    } on Object {
      return const _BankLoadResult.failed();
    }
  }

  static String _standardTitle(String fileName, String group) {
    final suffix = fileName.replaceFirst('${group.toLowerCase()}_', '');
    return suffix == 'questions'
        ? '$group Foundation'
        : '$group Paper ${suffix.replaceAll('_questions', '')}';
  }
}

final class _BankLoadResult {
  const _BankLoadResult(this.bank, [this.invalidQuestionCount = 0]);

  const _BankLoadResult.failed() : bank = null, invalidQuestionCount = 0;

  final ExamBank? bank;
  final int invalidQuestionCount;
}
