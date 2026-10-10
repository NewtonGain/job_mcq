import 'package:flutter/material.dart';

import 'question.dart';

class Category {
  const Category(
    this.name,
    this.subtitle,
    this.icon,
    this.color,
    this.questions,
  );

  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Question> questions;
}
