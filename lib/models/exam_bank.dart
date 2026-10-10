import 'package:flutter/material.dart';

import 'question.dart';

class ExamBank {
  const ExamBank(this.title, this.group, this.fileName, this.questions);

  final String title;
  final String group;
  final String fileName;
  final List<Question> questions;

  IconData get icon => switch (group) {
    'BCS' => Icons.account_balance_rounded,
    'NTRCA' => Icons.school_rounded,
    'Grade 11-20' => Icons.workspace_premium_rounded,
    _ => Icons.menu_book_rounded,
  };

  Color get color => switch (group) {
    'BCS' => const Color(0xFF0E7490),
    'NTRCA' => const Color(0xFFD97706),
    'Grade 11-20' => const Color(0xFF7C3AED),
    _ => const Color(0xFF059669),
  };
}
