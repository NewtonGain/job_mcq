import 'package:flutter/material.dart';

import '../../models/attempt.dart';

class ResultsView extends StatelessWidget {
  const ResultsView({
    super.key,
    required this.attempts,
    required this.onOpenReview,
  });

  final List<Attempt> attempts;
  final void Function(Attempt) onOpenReview;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          'Attempts',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A focused record of your practice sessions and mock tests.',
          style: TextStyle(color: theme.hintColor),
        ),
        const SizedBox(height: 20),
        if (attempts.isEmpty)
          _emptyState(context)
        else
          ...attempts.map((attempt) => _attemptCard(context, attempt, isDark)),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_turned_in_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No attempts yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a quiz to see your results and review answers here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _attemptCard(BuildContext context, Attempt attempt, bool isDark) {
    final theme = Theme.of(context);
    final percent = attempt.total == 0
        ? 0
        : ((attempt.correctCount / attempt.total) * 100).round();
    final passed = percent >= 50;
    final passColor = passed
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onOpenReview(attempt),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CustomPaint(
                  painter: _ScoreCirclePainter(
                    progress: attempt.total == 0
                        ? 0
                        : attempt.correctCount / attempt.total,
                    color: passColor,
                    background: passColor.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        color: passColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            attempt.category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (attempt.mode == 'Mock Exam')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Mock Exam',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _statPill(
                          '${attempt.correctCount}✓',
                          const Color(0xFF10B981),
                          isDark,
                        ),
                        const SizedBox(width: 5),
                        _statPill(
                          '${attempt.wrongCount}✕',
                          const Color(0xFFEF4444),
                          isDark,
                        ),
                        const SizedBox(width: 5),
                        if (attempt.skippedCount > 0)
                          _statPill(
                            '${attempt.skippedCount}–',
                            Colors.grey,
                            isDark,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(attempt.completedAt),
                      style: TextStyle(color: theme.hintColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: passColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      passed ? 'Passed' : 'Retry',
                      style: TextStyle(
                        color: passColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.hintColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statPill(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ScoreCirclePainter extends CustomPainter {
  const _ScoreCirclePainter({
    required this.progress,
    required this.color,
    required this.background,
  });

  final double progress;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = background
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.141592653589793 / 2,
      2 * 3.141592653589793 * progress.clamp(0.0, 1.0),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreCirclePainter old) =>
      old.progress != progress || old.color != color;
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.attempt});
  final Attempt attempt;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final questions = widget.attempt.category.questions;

    final filteredIndices = <int>[];
    for (var i = 0; i < questions.length; i++) {
      final selected = i < widget.attempt.selectedAnswers.length
          ? widget.attempt.selectedAnswers[i]
          : null;
      final correct = selected == questions[i].answer;

      if (filter == 'All') {
        filteredIndices.add(i);
      } else if (filter == 'Incorrect' && selected != null && !correct) {
        filteredIndices.add(i);
      } else if (filter == 'Correct' && correct) {
        filteredIndices.add(i);
      } else if (filter == 'Skipped' && selected == null) {
        filteredIndices.add(i);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review answers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: ['All', 'Incorrect', 'Correct', 'Skipped'].map((f) {
                final selected = filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: filteredIndices.isEmpty
          ? Center(
              child: Text(
                'No questions in this filter.',
                style: TextStyle(color: theme.hintColor),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredIndices.length,
              itemBuilder: (context, listIdx) {
                final index = filteredIndices[listIdx];
                final question = questions[index];
                final selected = index < widget.attempt.selectedAnswers.length
                    ? widget.attempt.selectedAnswers[index]
                    : null;
                final correct = selected == question.answer;

                Color statusColor = Colors.grey;
                IconData statusIcon = Icons.remove_circle_outline;
                if (selected != null) {
                  if (correct) {
                    statusColor = const Color(0xFF10B981);
                    statusIcon = Icons.check_circle_rounded;
                  } else {
                    statusColor = const Color(0xFFEF4444);
                    statusIcon = Icons.cancel_rounded;
                  }
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: widget.attempt.category.color.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Q${index + 1}',
                                style: TextStyle(
                                  color: widget.attempt.category.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${selected == null
                                  ? '0.00'
                                  : correct
                                  ? '1.00'
                                  : '-0.25'} marks',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(statusIcon, color: statusColor, size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          question.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Your answer: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      selected == null
                                          ? 'Not answered'
                                          : question.options[selected],
                                      style: TextStyle(
                                        color: selected == null
                                            ? Colors.grey
                                            : (correct
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFDC2626)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    'Correct answer: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      question.options[question.answer],
                                      style: const TextStyle(
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (question.explanation.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  question.explanation,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.hintColor,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
