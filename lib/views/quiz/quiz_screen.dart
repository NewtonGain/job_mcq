import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/attempt.dart';
import '../../models/category.dart';
import '../../models/question.dart';

class QuizScreen extends StatefulWidget {
  static const questionDuration = 30;

  const QuizScreen({
    super.key,
    required this.category,
    this.initialIndex = 0,
    this.initialAnswers = const [],
    this.initialSecondsLeft = _QuizScreenState.questionDuration,
    this.enableTimer = false,
    this.durationSeconds = _QuizScreenState.questionDuration,
    this.bookmarkedKeys = const {},
    this.isExamMode = false,
    this.negativeMarking = 0.25,
    this.onToggleBookmark,
  });

  final Category category;
  final int initialIndex;
  final List<int?> initialAnswers;
  final int initialSecondsLeft;
  final bool enableTimer;
  final int durationSeconds;
  final Set<String> bookmarkedKeys;
  final bool isExamMode;
  final double negativeMarking;
  final Future<void> Function(String)? onToggleBookmark;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const questionDuration = 30;
  late int index;
  int? selected;
  double score = 0;
  bool answered = false;
  int secondsLeft = questionDuration;
  Timer? questionTimer;
  late List<int?> selectedAnswers;
  late List<bool> flaggedQuestions;
  late Set<String> localBookmarks;
  final ScrollController scrollController = ScrollController();
  Future<void> _progressWrite = Future<void>.value();
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex.clamp(0, widget.category.questions.length - 1);
    selectedAnswers = List<int?>.filled(widget.category.questions.length, null);
    flaggedQuestions = List<bool>.filled(
      widget.category.questions.length,
      false,
    );
    localBookmarks = Set<String>.from(widget.bookmarkedKeys);

    for (
      var i = 0;
      i < widget.initialAnswers.length && i < selectedAnswers.length;
      i++
    ) {
      selectedAnswers[i] = widget.initialAnswers[i];
    }
    selected = selectedAnswers[index];
    answered = selected != null;
    score = calculateScore();
    if (widget.enableTimer) {
      startQuestionTimer(initialSeconds: widget.initialSecondsLeft);
    }
  }

  void startQuestionTimer({int? initialSeconds}) {
    questionTimer?.cancel();
    secondsLeft = (initialSeconds ?? widget.durationSeconds).clamp(
      1,
      widget.durationSeconds,
    );
    questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (secondsLeft <= 1) {
        timer.cancel();
        if (widget.isExamMode) {
          unawaited(completeQuiz());
        } else {
          skipQuestion();
        }
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    questionTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }

  String get _currentQuestionKey => '${widget.category.subtitle}:$index';

  void _toggleCurrentBookmark() {
    final key = _currentQuestionKey;
    setState(() {
      if (localBookmarks.contains(key)) {
        localBookmarks.remove(key);
      } else {
        localBookmarks.add(key);
      }
    });
    widget.onToggleBookmark?.call(key);
  }

  void _showQuestionPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question Palette',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${selectedAnswers.whereType<int>().length} / ${widget.category.questions.length} Answered',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _legendItem(const Color(0xFF10B981), 'Answered'),
                  _legendItem(const Color(0xFFF59E0B), 'Flagged'),
                  _legendItem(Colors.grey.shade400, 'Unanswered'),
                  _legendItem(theme.colorScheme.primary, 'Current'),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: widget.category.questions.length,
                  itemBuilder: (context, qIdx) {
                    final isCurrent = qIdx == index;
                    final isAnswered = selectedAnswers[qIdx] != null;
                    final isFlagged = flaggedQuestions[qIdx];

                    Color bgColor = Colors.grey.shade200;
                    Color textColor = Colors.black87;
                    if (isCurrent) {
                      bgColor = theme.colorScheme.primary;
                      textColor = Colors.white;
                    } else if (isFlagged) {
                      bgColor = const Color(0xFFFEF3C7);
                      textColor = const Color(0xFFB45309);
                    } else if (isAnswered) {
                      bgColor = const Color(0xFFD1FAE5);
                      textColor = const Color(0xFF065F46);
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          index = qIdx;
                          selected = selectedAnswers[index];
                          answered = selected != null;
                        });
                        if (scrollController.hasClients) {
                          scrollController.jumpTo(0);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : (isFlagged
                                      ? const Color(0xFFF59E0B)
                                      : Colors.transparent),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${qIdx + 1}',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.category.questions[index];
    final isBookmarked = localBookmarks.contains(_currentQuestionKey);
    final isFlagged = flaggedQuestions[index];

    final minutes = secondsLeft ~/ 60;
    final remainingSecs = secondsLeft % 60;
    final timeFormatted =
        '${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final navigator = Navigator.of(context);
        confirmExit().then((shouldLeave) {
          if (shouldLeave && mounted) navigator.pop();
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isExamMode
                    ? 'Exam Mode: ${widget.category.name}'
                    : widget.category.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                widget.isExamMode
                    ? 'Strict Simulation • No instant feedback'
                    : '${selectedAnswers.whereType<int>().length} of ${widget.category.questions.length} answered',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                color: isFlagged ? const Color(0xFFF59E0B) : null,
              ),
              tooltip: 'Flag for review',
              onPressed: () {
                setState(
                  () => flaggedQuestions[index] = !flaggedQuestions[index],
                );
              },
            ),
            IconButton(
              icon: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isBookmarked ? const Color(0xFF0E7490) : null,
              ),
              tooltip: 'Bookmark question',
              onPressed: _toggleCurrentBookmark,
            ),
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: 'Question palette',
              onPressed: _showQuestionPalette,
            ),
            if (widget.enableTimer)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: secondsLeft <= 60
                        ? Colors.red.withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: secondsLeft <= 60
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        widget.isExamMode ? timeFormatted : '$secondsLeft s',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: secondsLeft <= 60
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 14),
                child: Text(
                  '${index + 1}/${widget.category.questions.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (index + 1) / widget.category.questions.length,
                minHeight: 7,
                color: widget.category.color,
                backgroundColor: widget.category.color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'QUESTION ${index + 1}',
                    style: TextStyle(
                      color: widget.category.color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (question.tags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...question.tags.map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.text,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            ...List.generate(
              question.options.length,
              (option) => optionTile(question, option),
            ),
            if (!widget.isExamMode &&
                answered &&
                question.explanation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question.explanation,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.85),
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: skipQuestion,
                    icon: const Icon(Icons.skip_next_outlined),
                    label: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: widget.isExamMode || answered ? next : null,
                    child: Text(
                      index == widget.category.questions.length - 1
                          ? 'Finish exam'
                          : 'Next question',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: finishQuiz,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Finish paper now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> confirmExit() async {
    if (index == 0 && !answered && !widget.isExamMode) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave this paper?'),
        content: Text(
          widget.isExamMode
              ? 'Exam mode is active. Leaving now will submit your exam with current progress.'
              : 'Your current progress is saved, but you can resume later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave / Submit'),
          ),
        ],
      ),
    );
    if (leave == true && widget.isExamMode) {
      await completeQuiz();
    }
    return leave ?? false;
  }

  Widget optionTile(Question question, int option) {
    final correct = option == question.answer;
    final chosen = option == selected;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    Color bubbleColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF1F5F9);
    Color bubbleTextColor = isDark ? Colors.white70 : const Color(0xFF475569);
    Color textColor = theme.colorScheme.onSurface;
    IconData? trailingIcon;
    Color? trailingColor;

    if (!widget.isExamMode && answered) {
      if (correct) {
        bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
        borderColor = const Color(0xFF10B981);
        bubbleColor = const Color(0xFF10B981);
        bubbleTextColor = Colors.white;
        textColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
        trailingIcon = Icons.check_circle_rounded;
        trailingColor = const Color(0xFF10B981);
      } else if (chosen) {
        bgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFEF4444);
        bubbleColor = const Color(0xFFEF4444);
        bubbleTextColor = Colors.white;
        textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
        trailingIcon = Icons.cancel_rounded;
        trailingColor = const Color(0xFFEF4444);
      }
    } else if (widget.isExamMode && chosen) {
      bgColor = isDark ? const Color(0xFF0369A1) : const Color(0xFFE0F2FE);
      borderColor = const Color(0xFF0284C7);
      bubbleColor = const Color(0xFF0284C7);
      bubbleTextColor = Colors.white;
      textColor = isDark ? Colors.white : const Color(0xFF0C4A6E);
    }

    final letter = String.fromCharCode(65 + option);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: !widget.isExamMode && answered && (correct || chosen)
                ? 2.0
                : 1.5,
          ),
          boxShadow: !widget.isExamMode && answered && correct
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              choose(option);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: bubbleTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      child: Text(question.options[option]),
                    ),
                  ),
                  if (!widget.isExamMode && trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: Icon(trailingIcon, color: trailingColor, size: 22),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void choose(int value) => setState(() {
    selected = value;
    answered = true;
    selectedAnswers[index] = value;
    score = calculateScore();
    if (!widget.isExamMode) {
      saveProgress();
    }
  });

  void next() {
    if (!widget.isExamMode) {
      questionTimer?.cancel();
    }
    if (index == widget.category.questions.length - 1) {
      unawaited(completeQuiz());
    } else {
      setState(() {
        index++;
        selected = selectedAnswers[index];
        answered = selected != null;
      });
      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
      if (!widget.isExamMode && widget.enableTimer) {
        startQuestionTimer();
      }
      if (!widget.isExamMode) {
        saveProgress();
      }
    }
  }

  double calculateScore() =>
      selectedAnswers.asMap().entries.fold<double>(0, (total, entry) {
        if (entry.value == null) return total;
        return total +
            (entry.value == widget.category.questions[entry.key].answer
                ? 1.0
                : -widget.negativeMarking);
      });

  void skipQuestion() {
    if (!mounted) return;
    if (!widget.isExamMode) {
      questionTimer?.cancel();
    }
    selectedAnswers[index] = null;
    score = calculateScore();
    if (index == widget.category.questions.length - 1) {
      unawaited(completeQuiz());
      return;
    }
    setState(() {
      index++;
      selected = selectedAnswers[index];
      answered = selected != null;
    });
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    if (!widget.isExamMode && widget.enableTimer) {
      startQuestionTimer();
    }
    if (!widget.isExamMode) {
      saveProgress();
    }
  }

  Future<void> finishQuiz() async {
    final unanswered = selectedAnswers.where((answer) => answer == null).length;
    final flaggedCount = flaggedQuestions.where((f) => f).length;

    String content = widget.isExamMode
        ? 'Are you ready to submit your final exam answers?'
        : 'Are you ready to submit your paper?';
    if (unanswered > 0 || flaggedCount > 0) {
      content =
          'You have $unanswered unanswered questions and $flaggedCount flagged questions.';
    }

    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          widget.isExamMode ? 'Submit Exam Now?' : 'Finish paper now?',
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (shouldFinish != true) return;
    await completeQuiz();
  }

  Future<void> completeQuiz() async {
    if (_completed) return;
    _completed = true;
    questionTimer?.cancel();
    score = calculateScore();
    await _progressWrite;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('active_quiz');
    } on Object {
      // Best-effort cleanup: ignore persistence failures on exit.
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      Attempt(
        widget.category,
        score,
        selectedAnswers: selectedAnswers,
        mode: widget.isExamMode ? 'Mock Exam' : 'Practice',
        negativeMarking: widget.negativeMarking,
      ),
    );
  }

  Future<void> saveProgress() {
    if (widget.isExamMode) return Future.value();
    final progress = {
      'source': widget.category.subtitle,
      'index': index,
      'secondsLeft': secondsLeft,
      'answers': List<int?>.from(selectedAnswers),
    };
    _progressWrite = _progressWrite.then((_) async {
      if (_completed) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('active_quiz', jsonEncode(progress));
    });
    return _progressWrite;
  }
}
