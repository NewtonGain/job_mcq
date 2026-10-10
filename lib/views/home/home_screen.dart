import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../core/question_bank_loader.dart';
import '../../models/attempt.dart';
import '../../models/category.dart';
import '../../models/exam_bank.dart';
import '../../models/question.dart';
import '../quiz/quiz_screen.dart';
import '../pdf/pdf_viewer.dart';
import '../results/results_view.dart';
import '../settings/settings_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  final attempts = <Attempt>[];
  List<ExamBank> banks = const [];
  bool assetLoading = true;
  int invalidQuestionCount = 0;
  int failedBankCount = 0;
  String selectedGroup = 'All';
  String searchQuery = '';
  SharedPreferences? _cachedPrefs;
  Set<String> bookmarkedKeys = {};
  final Map<String, List<Question>> customQuestions = {};
  final List<ExamBank> customCategories = [];
  String? activeQuizSource;
  int activeQuizAnswered = 0;
  int activeQuizTotal = 0;

  @override
  void initState() {
    super.initState();
    loadAssetQuestions();
    _initStorage();
  }

  Future<void> _initStorage() async {
    try {
      _cachedPrefs = await SharedPreferences.getInstance();
      appDailyQuestionGoal.value =
          _cachedPrefs?.getInt('daily_question_goal') ?? 10;
      _loadBookmarks();
      _checkActiveQuiz();
    } catch (_) {}
  }

  void _loadBookmarks() {
    final list = _cachedPrefs?.getStringList('bookmarks') ?? [];
    bookmarkedKeys = list.toSet();
  }

  void _checkActiveQuiz() {
    final stored = _cachedPrefs?.getString('active_quiz');
    if (stored != null) {
      try {
        final map = jsonDecode(stored) as Map<String, dynamic>;
        final source = map['source']?.toString();
        final answers = (map['answers'] as List<dynamic>? ?? []);
        setState(() {
          activeQuizSource = source;
          activeQuizAnswered = answers.whereType<int>().length;
          activeQuizTotal = answers.length;
        });
      } catch (_) {}
    } else {
      setState(() {
        activeQuizSource = null;
      });
    }
  }

  Future<void> loadAssetQuestions() async {
    try {
      final result = await QuestionBankLoader.load();
      if (!mounted) return;
      setState(() {
        banks = result.banks;
        assetLoading = false;
        invalidQuestionCount = result.invalidQuestionCount;
        failedBankCount = result.failedBankCount;
      });
    } on Object catch (error) {
      debugPrint('Could not read question assets: $error');
      if (mounted) {
        setState(() {
          assetLoading = false;
          failedBankCount = 1;
        });
      }
      return;
    }

    await _restoreCustomCategories();
    await _restoreCustomQuestions();
    await restoreAttempts();
  }

  Future<void> _restoreCustomCategories() async {
    final preferences = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = preferences;
    final stored = preferences.getString('custom_categories');
    if (stored == null) return;

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List<dynamic>) return;
      for (final item in decoded.whereType<Map>()) {
        final data = Map<String, dynamic>.from(item);
        final title = data['title']?.toString().trim() ?? '';
        final group = data['group']?.toString().trim() ?? 'Custom';
        final fileName = data['fileName']?.toString().trim() ?? '';
        if (title.isEmpty || fileName.isEmpty) continue;
        if (banks.any((bank) => bank.fileName == fileName)) continue;
        final bank = ExamBank(title, group, fileName, const []);
        customCategories.add(bank);
        banks.add(bank);
      }
      if (mounted) setState(() {});
    } on Object {
      // Ignore malformed persisted custom categories.
    }
  }

  Future<void> _saveCustomCategories() async {
    final preferences = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = preferences;
    await preferences.setString(
      'custom_categories',
      jsonEncode(_customCategoriesPayload()),
    );
  }

  Future<void> _addCategory() async {
    final draft = await showDialog<_NewCategoryDraft>(
      context: context,
      builder: (context) => const _AddCategoryDialog(),
    );
    if (draft == null || !mounted) return;

    final baseSlug = draft.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final fileName =
        'custom_${baseSlug.isEmpty ? 'category' : baseSlug}_${DateTime.now().microsecondsSinceEpoch}';
    final bank = ExamBank(draft.title, draft.group, fileName, const []);
    setState(() {
      banks.add(bank);
      customCategories.add(bank);
    });
    await _saveCustomCategories();
  }

  Future<void> _restoreCustomQuestions() async {
    final preferences = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = preferences;
    final stored = preferences.getString('custom_questions');
    final managedStored = preferences.getString('managed_questions');
    if (stored == null && managedStored == null) return;

    try {
      final decoded = stored == null ? <String, dynamic>{} : jsonDecode(stored);
      final customDecoded = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      for (final entry in customDecoded.entries) {
        final rawQuestions = entry.value;
        if (rawQuestions is! List<dynamic>) continue;
        final questions = rawQuestions
            .whereType<Map>()
            .map((item) => Question.fromAsset(Map<String, dynamic>.from(item)))
            .whereType<Question>()
            .toList();
        if (questions.isEmpty) continue;
        customQuestions[entry.key] = questions;
        final bankIndex = banks.indexWhere(
          (bank) => bank.fileName == entry.key,
        );
        if (bankIndex < 0) continue;
        final bank = banks[bankIndex];
        banks[bankIndex] = ExamBank(bank.title, bank.group, bank.fileName, [
          ...bank.questions,
          ...questions,
        ]);
      }
      if (managedStored != null) {
        final managedDecoded = jsonDecode(managedStored);
        if (managedDecoded is Map<String, dynamic>) {
          for (final entry in managedDecoded.entries) {
            final rawQuestions = entry.value;
            if (rawQuestions is! List<dynamic>) continue;
            final questions = rawQuestions
                .whereType<Map>()
                .map(
                  (item) => Question.fromAsset(Map<String, dynamic>.from(item)),
                )
                .whereType<Question>()
                .toList();
            final bankIndex = banks.indexWhere(
              (bank) => bank.fileName == entry.key,
            );
            if (bankIndex < 0) continue;
            final bank = banks[bankIndex];
            banks[bankIndex] = ExamBank(
              bank.title,
              bank.group,
              bank.fileName,
              questions,
            );
          }
        }
      }
      if (mounted) setState(() {});
    } on Object catch (error) {
      debugPrint('Failed to restore custom questions: $error');
    }
  }

  Future<void> _saveCustomQuestions() async {
    final preferences = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = preferences;
    await preferences.setString(
      'custom_questions',
      jsonEncode(
        customQuestions.map(
          (key, questions) => MapEntry(
            key,
            questions.map((question) => question.toStorageJson()).toList(),
          ),
        ),
      ),
    );
    await preferences.setString(
      'managed_questions',
      jsonEncode(_managedQuestionsPayload()),
    );
  }

  Future<void> _addQuestionToBank(ExamBank bank) async {
    final question = await showDialog<Question>(
      context: context,
      builder: (context) => const _AddQuestionDialog(),
    );
    if (question == null || !mounted) return;

    final bankIndex = banks.indexWhere(
      (candidate) => candidate.fileName == bank.fileName,
    );
    if (bankIndex < 0) return;
    await _clearActiveQuizForSource(bank.fileName);
    final updatedCustom = customQuestions.putIfAbsent(
      bank.fileName,
      () => <Question>[],
    );
    updatedCustom.add(question);
    final currentBank = banks[bankIndex];
    setState(() {
      banks[bankIndex] = ExamBank(
        currentBank.title,
        currentBank.group,
        currentBank.fileName,
        [...currentBank.questions, question],
      );
    });
    await _saveCustomQuestions();
  }

  Future<void> _openPdf(ExamBank bank) async {
    if (bank.fileName.startsWith('custom_') ||
        bank.fileName.startsWith('grade_11_20_')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF is not available for this paper.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerScreen(
          title: bank.title,
          assetPath: 'assets/pdf/${_pdfFileName(bank.fileName)}.pdf',
        ),
      ),
    );
  }

  String _pdfFileName(String fileName) {
    return fileName.replaceFirst(RegExp(r'_questions$'), '');
  }

  Future<void> _manageQuestions(ExamBank bank) async {
    final action = await showModalBottomSheet<_QuestionAction>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _QuestionManagerSheet(bank: bank),
    );
    if (action == null || !mounted) return;

    final currentBank = banks.firstWhere(
      (candidate) => candidate.fileName == bank.fileName,
    );
    if (action.type == _QuestionActionType.edit) {
      final updatedQuestion = await showDialog<Question>(
        context: context,
        builder: (context) => _AddQuestionDialog(
          initialQuestion: currentBank.questions[action.index],
        ),
      );
      if (updatedQuestion == null || !mounted) return;
      await _clearActiveQuizForSource(currentBank.fileName);
      final questions = List<Question>.from(currentBank.questions)
        ..[action.index] = updatedQuestion;
      setState(() {
        banks[banks.indexWhere(
          (candidate) => candidate.fileName == bank.fileName,
        )] = ExamBank(
          currentBank.title,
          currentBank.group,
          currentBank.fileName,
          questions,
        );
      });
      await _saveCustomQuestions();
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete question?'),
        content: const Text('This question will be removed from the category.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    await _clearActiveQuizForSource(currentBank.fileName);

    final questions = List<Question>.from(currentBank.questions)
      ..removeAt(action.index);
    final bankIndex = banks.indexWhere(
      (candidate) => candidate.fileName == currentBank.fileName,
    );
    setState(() {
      banks[bankIndex] = ExamBank(
        currentBank.title,
        currentBank.group,
        currentBank.fileName,
        questions,
      );
    });
    await _removeBookmarkAndShift(currentBank.fileName, action.index);
    await _saveCustomQuestions();
  }

  Future<void> _clearActiveQuizForSource(String source) async {
    final preferences = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = preferences;
    final stored = preferences.getString('active_quiz');
    if (stored == null) return;
    try {
      final record = jsonDecode(stored) as Map<String, dynamic>;
      if (record['source']?.toString() == source) {
        await preferences.remove('active_quiz');
        _checkActiveQuiz();
      }
    } on Object {
      await preferences.remove('active_quiz');
    }
  }

  Future<void> _removeBookmarkAndShift(String source, int deletedIndex) async {
    final prefix = '$source:';
    final updated = <String>{};
    for (final key in bookmarkedKeys) {
      if (!key.startsWith(prefix)) {
        updated.add(key);
        continue;
      }
      final index = int.tryParse(key.substring(prefix.length));
      if (index == null || index == deletedIndex) continue;
      updated.add('$prefix${index > deletedIndex ? index - 1 : index}');
    }
    setState(() => bookmarkedKeys = updated);
    final preferences = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = preferences;
    await preferences.setStringList('bookmarks', bookmarkedKeys.toList());
  }

  Future<void> restoreAttempts() async {
    try {
      final preferences = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = preferences;
      final stored = preferences.getString('attempts');
      if (stored == null) return;
      final decoded = jsonDecode(stored);
      if (decoded is! List<dynamic>) return;
      final restored = <Attempt>[];
      for (final item in decoded.whereType<Map>()) {
        final record = Map<String, dynamic>.from(item);
        final source = record['source']?.toString();
        ExamBank? bank;
        for (final candidate in banks) {
          if (candidate.fileName == source) {
            bank = candidate;
            break;
          }
        }
        final questions =
            _questionsFromRecord(record) ??
            bank?.questions ??
            const <Question>[];
        if (questions.isEmpty) continue;
        final answers = _answersFromRecord(record, questions);
        final category = bank == null
            ? Category(
                record['name']?.toString() ?? 'Practice',
                source ?? '',
                Icons.history_rounded,
                AppTheme.primaryColor,
                questions,
              )
            : Category(
                bank.title,
                bank.fileName,
                bank.icon,
                bank.color,
                questions,
              );
        restored.add(
          Attempt(
            category,
            (record['score'] as num?)?.toDouble() ?? 0,
            selectedAnswers: answers,
            completedAt: DateTime.tryParse(
              record['completedAt']?.toString() ?? '',
            ),
            mode: record['mode']?.toString() ?? 'Practice',
            negativeMarking:
                (record['negativeMarking'] as num?)?.toDouble() ?? 0.25,
          ),
        );
      }
      if (mounted) setState(() => attempts.addAll(restored));
    } on Object catch (error, stackTrace) {
      debugPrint('Failed to restore attempts: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'job_mcq',
          context: ErrorDescription('while restoring saved attempts'),
        ),
      );
    }
  }

  List<Question>? _questionsFromRecord(Map<String, dynamic> record) {
    final rawQuestions = record['questions'];
    if (rawQuestions is! List<dynamic>) return null;
    final questions = rawQuestions
        .whereType<Map>()
        .map((item) => Question.fromAsset(Map<String, dynamic>.from(item)))
        .whereType<Question>()
        .toList();
    return questions.isEmpty ? null : questions;
  }

  List<int?> _answersFromRecord(
    Map<String, dynamic> record,
    List<Question> questions,
  ) {
    final rawAnswers = record['answers'] as List<dynamic>? ?? [];
    return List<int?>.generate(questions.length, (index) {
      if (index >= rawAnswers.length || rawAnswers[index] is! num) {
        return null;
      }
      final answer = (rawAnswers[index] as num).toInt();
      return answer >= 0 && answer < questions[index].options.length
          ? answer
          : null;
    });
  }

  Future<void> saveAttempts() async {
    final preferences = _cachedPrefs ?? await SharedPreferences.getInstance();
    await preferences.setString(
      'attempts',
      jsonEncode(attempts.map((attempt) => attempt.toJson()).toList()),
    );
  }

  Future<void> toggleBookmark(String questionKey) async {
    setState(() {
      if (bookmarkedKeys.contains(questionKey)) {
        bookmarkedKeys.remove(questionKey);
      } else {
        bookmarkedKeys.add(questionKey);
      }
    });
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarks', bookmarkedKeys.toList());
  }

  List<Map<String, dynamic>> _customCategoriesPayload() => [
    for (final bank in customCategories)
      {'title': bank.title, 'group': bank.group, 'fileName': bank.fileName},
  ];

  Map<String, dynamic> _managedQuestionsPayload() => {
    for (final bank in banks)
      bank.fileName: bank.questions
          .map((question) => question.toStorageJson())
          .toList(),
  };

  Future<void> _deleteCategory(ExamBank bank) async {
    if (!bank.fileName.startsWith('custom_')) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete ${bank.title} and all of its questions? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    customCategories.removeWhere(
      (category) => category.fileName == bank.fileName,
    );
    customQuestions.remove(bank.fileName);
    banks.removeWhere((candidate) => candidate.fileName == bank.fileName);
    final prefix = '${bank.fileName}:';
    bookmarkedKeys.removeWhere((key) => key.startsWith(prefix));
    if (mounted) setState(() {});

    final preferences = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = preferences;
    await preferences.setString(
      'custom_categories',
      jsonEncode(_customCategoriesPayload()),
    );
    await preferences.setString(
      'managed_questions',
      jsonEncode(_managedQuestionsPayload()),
    );
    await preferences.setStringList('bookmarks', bookmarkedKeys.toList());
  }

  Future<void> startQuiz(Category category, {bool isExamMode = false}) async {
    if (category.questions.isEmpty) return;
    SharedPreferences? preferences = _cachedPrefs;
    if (preferences == null) {
      try {
        preferences = await SharedPreferences.getInstance();
        _cachedPrefs = preferences;
      } on Object {
        // Resume data is optional; continue with a fresh quiz when loading fails.
      }
    }

    var initialIndex = 0;
    var initialSecondsLeft = isExamMode
        ? category.questions.length * 60
        : QuizScreen.questionDuration;
    var initialAnswers = <int?>[];

    if (!isExamMode) {
      final stored = preferences?.getString('active_quiz');
      if (stored != null) {
        try {
          final record = jsonDecode(stored) as Map<String, dynamic>;
          if (record['source'] == category.subtitle) {
            initialIndex = (record['index'] as num?)?.toInt() ?? 0;
            initialSecondsLeft =
                (record['secondsLeft'] as num?)?.toInt() ??
                QuizScreen.questionDuration;
            initialAnswers = (record['answers'] as List<dynamic>? ?? [])
                .map((value) => value is num ? value.toInt() : null)
                .toList();
            if (!mounted) return;
            final resume = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('Resume this paper?'),
                content: const Text(
                  'You have an unfinished session for this paper.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Start over'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Resume'),
                  ),
                ],
              ),
            );
            if (!mounted) return;
            if (resume != true) {
              await preferences?.remove('active_quiz');
              initialIndex = 0;
              initialAnswers = <int?>[];
            }
          }
        } on Object {
          await preferences?.remove('active_quiz');
        }
      }
    }

    if (!mounted) return;
    final enableTimer = isExamMode
        ? true
        : (preferences?.getBool('timer') ?? false);
    final timerDuration = isExamMode
        ? (category.questions.length * 60)
        : (preferences?.getInt('timer_duration') ?? 30);
    final negativeMarking = preferences?.getDouble('negative_marking') ?? 0.25;

    final result = await Navigator.push<Attempt>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => QuizScreen(
          category: category,
          initialIndex: initialIndex,
          initialAnswers: initialAnswers,
          initialSecondsLeft: initialSecondsLeft,
          enableTimer: enableTimer,
          durationSeconds: timerDuration,
          bookmarkedKeys: bookmarkedKeys,
          isExamMode: isExamMode,
          negativeMarking: negativeMarking,
          onToggleBookmark: toggleBookmark,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: FadeTransition(opacity: curvedAnimation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
    if (!mounted) return;
    _checkActiveQuiz();
    if (result != null) {
      setState(() => attempts.insert(0, result));
      await saveAttempts();
    }
  }

  List<Question> _buildDailyChallengeQuestions() {
    final allQuestions = <Question>[];
    for (final bank in banks) {
      allQuestions.addAll(bank.questions);
    }
    if (allQuestions.isEmpty) return const [];

    final seed =
        DateTime.now().year * 10000 +
        DateTime.now().month * 100 +
        DateTime.now().day;
    final random = Random(seed);
    final shuffled = List<Question>.from(allQuestions)..shuffle(random);
    return shuffled.take(min(5, shuffled.length)).toList();
  }

  List<Question> _buildWeakAreaQuestions() {
    final weakByBank = <String, Map<int, int>>{};
    for (final attempt in attempts) {
      final bankFile = attempt.category.subtitle;
      final bank = banks.firstWhere(
        (candidate) => candidate.fileName == bankFile,
        orElse: () => const ExamBank('', '', '', []),
      );
      if (bank.fileName.isEmpty || bank.questions.isEmpty) continue;
      final counts = weakByBank.putIfAbsent(bank.fileName, () => <int, int>{});
      for (
        var i = 0;
        i < bank.questions.length && i < attempt.selectedAnswers.length;
        i++
      ) {
        final selected = attempt.selectedAnswers[i];
        if (selected == null || selected == bank.questions[i].answer) continue;
        counts[i] = (counts[i] ?? 0) + 1;
      }
    }

    final weakQuestions = <Question>[];
    final seenKeys = <String>{};
    for (final bank in banks) {
      final counts = weakByBank[bank.fileName] ?? const {};
      final ranked = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in ranked.take(3)) {
        final index = entry.key;
        if (index < 0 || index >= bank.questions.length) continue;
        final key = '${bank.fileName}:$index';
        if (seenKeys.add(key)) {
          weakQuestions.add(bank.questions[index]);
        }
      }
    }

    final fillerQuestions = <Question>[];
    for (final bank in banks) {
      for (var i = 0; i < bank.questions.length; i++) {
        final key = '${bank.fileName}:$i';
        if (seenKeys.contains(key)) continue;
        if (fillerQuestions.length >= 8) break;
        fillerQuestions.add(bank.questions[i]);
        seenKeys.add(key);
      }
      if (fillerQuestions.length >= 8) break;
    }

    final combined = [...weakQuestions, ...fillerQuestions];
    if (combined.isEmpty) return const [];

    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final shuffled = List<Question>.from(combined)..shuffle(random);
    return shuffled.take(min(6, shuffled.length)).toList();
  }

  Future<void> _startDailyChallenge() async {
    final questions = _buildDailyChallengeQuestions();
    if (questions.isEmpty) return;
    await startQuiz(
      Category(
        'Daily Challenge',
        'daily_challenge',
        Icons.local_fire_department_rounded,
        const Color(0xFFD97706),
        questions,
      ),
    );
  }

  Future<void> _startWeakAreaReview() async {
    final questions = _buildWeakAreaQuestions();
    if (questions.isEmpty) return;
    await startQuiz(
      Category(
        'Weak Area Review',
        'weak_area_review',
        Icons.psychology_outlined,
        const Color(0xFF8B5CF6),
        questions,
      ),
    );
  }

  void _startRandomQuiz() {
    if (banks.isEmpty) return;
    final allQuestions = <Question>[];
    for (final bank in banks) {
      allQuestions.addAll(bank.questions);
    }
    if (allQuestions.isEmpty) return;
    allQuestions.shuffle();
    final sample = allQuestions.take(10).toList();
    startQuiz(
      Category(
        'Quick 10 Sprint',
        'random_quick_10',
        Icons.bolt_rounded,
        const Color(0xFFD97706),
        sample,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      examDashboard(context),
      SavedQuestionsView(
        banks: banks,
        bookmarkedKeys: bookmarkedKeys,
        onToggleBookmark: toggleBookmark,
      ),
      ResultsView(
        attempts: attempts,
        onOpenReview: (attempt) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReviewScreen(attempt: attempt)),
        ),
      ),
      AnalyticsView(attempts: attempts),
      SettingsView(
        banks: banks,
        onAddQuestion: _addQuestionToBank,
        onManageQuestions: _manageQuestions,
        onAddCategory: _addCategory,
        onDeleteCategory: _deleteCategory,
        onClearHistory: () async {
          setState(() => attempts.clear());
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('attempts');
          await prefs.remove('active_quiz');
          _checkActiveQuiz();
        },
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            for (var index = 0; index < pages.length; index++)
              TickerMode(enabled: index == tab, child: pages[index]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
          if (value == 0) _checkActiveQuiz();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Attempts',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget examDashboard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visibleBanks = banks.where((bank) {
      final matchesGroup =
          selectedGroup == 'All' || bank.group == selectedGroup;
      final matchesSearch =
          searchQuery.isEmpty ||
          '${bank.title} ${bank.fileName}'.toLowerCase().contains(searchQuery);
      return matchesGroup && matchesSearch;
    }).toList();

    final totalQuestions = banks.fold<int>(
      0,
      (runningTotal, bank) => runningTotal + bank.questions.length,
    );

    final totalSolved = attempts.fold<int>(
      0,
      (runningTotal, a) => runningTotal + a.answeredCount,
    );
    final today = DateTime.now();
    final questionsCompletedToday = attempts
        .where((attempt) {
          final completedAt = attempt.completedAt;
          return completedAt.year == today.year &&
              completedAt.month == today.month &&
              completedAt.day == today.day;
        })
        .fold<int>(0, (total, attempt) => total + attempt.answeredCount);
    final standardGroups = <String>['BCS', 'NTRCA', 'Primary', 'Grade 11-20'];
    final availableGroups = [
      ...standardGroups.where(
        (group) => banks.any((bank) => bank.group == group),
      ),
      ...banks
          .map((bank) => bank.group)
          .where((group) => !standardGroups.contains(group))
          .toSet(),
    ];
    final filterGroups = ['All', ...availableGroups];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'EXAM DESK',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 13,
                            color: Color(0xFFD97706),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Active Prep',
                            style: TextStyle(
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Newton Gain.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _startRandomQuiz,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E7490), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0E7490).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                    SizedBox(height: 2),
                    Text(
                      'Sprint',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (banks.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: _challengeCard(
                  title: 'Daily Challenge',
                  subtitle: '5 focused questions',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFD97706),
                  onTap: _startDailyChallenge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _challengeCard(
                  title: 'Weak Area Review',
                  subtitle: 'Retry missed questions',
                  icon: Icons.psychology_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: _startWeakAreaReview,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.offline_pin_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assetLoading
                              ? 'Preparing your library'
                              : 'Offline library ready',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          assetLoading
                              ? 'Reading your local exam papers...'
                              : '$totalQuestions questions across ${banks.length} papers',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      '100% Free',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _quickStat(
                      'SOLVED',
                      '$totalSolved Qs',
                      Icons.check_circle_outline,
                    ),
                    Container(width: 1, height: 26, color: Colors.white12),
                    _quickStat(
                      'ATTEMPTS',
                      '${attempts.length}',
                      Icons.timer_outlined,
                    ),
                    Container(width: 1, height: 26, color: Colors.white12),
                    _quickStat(
                      'SAVED',
                      '${bookmarkedKeys.length}',
                      Icons.bookmark_border_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<int>(
          valueListenable: appDailyQuestionGoal,
          builder: (context, dailyGoal, _) {
            final progress = (questionsCompletedToday / dailyGoal).clamp(
              0.0,
              1.0,
            );
            final goalReached = questionsCompletedToday >= dailyGoal;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          goalReached
                              ? Icons.task_alt_rounded
                              : Icons.flag_outlined,
                          color: goalReached
                              ? const Color(0xFF059669)
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Today's study goal",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '$questionsCompletedToday / $dailyGoal',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(8),
                      color: goalReached
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      goalReached
                          ? 'Daily target reached. Great work.'
                          : '${dailyGoal - questionsCompletedToday} more to reach your target',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (activeQuizSource != null) ...[
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              for (final bank in banks) {
                if (bank.fileName == activeQuizSource) {
                  startQuiz(
                    Category(
                      bank.title,
                      bank.fileName,
                      bank.icon,
                      bank.color,
                      bank.questions,
                    ),
                  );
                  break;
                }
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: isDark ? 0.32 : 0.55,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unfinished Paper In Progress',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$activeQuizAnswered of $activeQuizTotal questions answered • Tap to resume',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          onChanged: (value) =>
              setState(() => searchQuery = value.toLowerCase().trim()),
          decoration: InputDecoration(
            hintText: 'Search papers or exams...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => searchQuery = ''),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filterGroups.map((group) {
              final selected = selectedGroup == group;
              final count = group == 'All'
                  ? banks.length
                  : banks.where((b) => b.group == group).length;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('$group ($count)'),
                  selected: selected,
                  onSelected: (_) => setState(() => selectedGroup = group),
                  showCheckmark: false,
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  selectedColor: isDark
                      ? const Color(0xFF0369A1)
                      : const Color(0xFFE0F2FE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected
                          ? (isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0E7490))
                          : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? (isDark ? Colors.white : const Color(0xFF0E7490))
                        : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569)),
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedGroup == 'All'
                  ? 'All exam papers'
                  : '$selectedGroup papers',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${visibleBanks.length} available',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (assetLoading)
          Column(children: List.generate(3, (i) => _shimmerCard(theme, isDark)))
        else if (visibleBanks.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.hintColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 36,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No papers found',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try a different search or select "All" from the filter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.hintColor, height: 1.4),
                ),
              ],
            ),
          )
        else
          ...visibleBanks.map(bankTile),
      ],
    );
  }

  Widget _shimmerCard(ThemeData theme, bool isDark) {
    final base = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final highlight = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: highlight,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: highlight,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  width: 100,
                  decoration: BoxDecoration(
                    color: highlight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _challengeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget bankTile(ExamBank bank) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pastAttempts = attempts
        .where((a) => a.category.subtitle == bank.fileName)
        .toList();
    final hasCompleted = pastAttempts.isNotEmpty;
    final bestScore = hasCompleted
        ? pastAttempts.map((a) => a.score).reduce(max)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bank.color.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: bank.color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(bank.icon, color: bank.color, size: 24),
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
                              bank.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (hasCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 12,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Best: ${bestScore.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _groupBadge(bank.group, bank.color),
                          Text(
                            '${bank.questions.length} questions',
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: theme.dividerColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openPdf(bank),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: bank.questions.isEmpty
                      ? null
                      : () => startQuiz(
                          Category(
                            bank.title,
                            bank.fileName,
                            bank.icon,
                            bank.color,
                            bank.questions,
                          ),
                          isExamMode: false,
                        ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Practice'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                FilledButton.icon(
                  onPressed: bank.questions.isEmpty
                      ? null
                      : () => startQuiz(
                          Category(
                            bank.title,
                            bank.fileName,
                            bank.icon,
                            bank.color,
                            bank.questions,
                          ),
                          isExamMode: true,
                        ),
                  icon: const Icon(Icons.timer_rounded, size: 16),
                  label: const Text('Mock Exam'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupBadge(String group, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        group,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _QuestionActionType { edit, delete }

class _QuestionAction {
  const _QuestionAction(this.type, this.index);

  final _QuestionActionType type;
  final int index;
}

class _QuestionManagerSheet extends StatelessWidget {
  const _QuestionManagerSheet({required this.bank});

  final ExamBank bank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Manage ${bank.title}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: bank.questions.length,
                separatorBuilder: (_, _) => const Divider(height: 20),
                itemBuilder: (context, index) {
                  final question = bank.questions[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${index + 1}. ${question.cleanText}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit question',
                        onPressed: () => Navigator.pop(
                          context,
                          _QuestionAction(_QuestionActionType.edit, index),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete question',
                        onPressed: () => Navigator.pop(
                          context,
                          _QuestionAction(_QuestionActionType.delete, index),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: theme.colorScheme.error,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCategoryDraft {
  const _NewCategoryDraft(this.title, this.group);

  final String title;
  final String group;
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final newGroupController = TextEditingController();
  String group = 'New group';

  @override
  void dispose() {
    titleController.dispose();
    newGroupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add category'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Category name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: group,
              decoration: const InputDecoration(labelText: 'Group'),
              items: const [
                DropdownMenuItem(
                  value: 'New group',
                  child: Text('New group name'),
                ),
                DropdownMenuItem(value: 'BCS', child: Text('BCS')),
                DropdownMenuItem(value: 'NTRCA', child: Text('NTRCA')),
                DropdownMenuItem(value: 'Primary', child: Text('Primary')),
                DropdownMenuItem(
                  value: 'Grade 11-20',
                  child: Text('Grade 11-20'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => group = value);
              },
            ),
            if (group == 'New group') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: newGroupController,
                decoration: const InputDecoration(labelText: 'New group name'),
                validator: (value) =>
                    group == 'New group' &&
                        (value == null || value.trim().isEmpty)
                    ? 'Enter a group name'
                    : null,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final selectedGroup = group == 'New group'
                ? newGroupController.text.trim()
                : group;
            Navigator.pop(
              context,
              _NewCategoryDraft(titleController.text.trim(), selectedGroup),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add category'),
        ),
      ],
    );
  }
}

class _AddQuestionDialog extends StatefulWidget {
  const _AddQuestionDialog({this.initialQuestion});

  final Question? initialQuestion;

  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  final formKey = GlobalKey<FormState>();
  final questionController = TextEditingController();
  final optionControllers = List.generate(4, (_) => TextEditingController());
  final explanationController = TextEditingController();
  final tagController = TextEditingController();
  int correctAnswer = 0;
  final List<String> tags = [];

  @override
  void initState() {
    super.initState();
    final question = widget.initialQuestion;
    if (question == null) return;
    questionController.text = question.text;
    for (var index = 0; index < optionControllers.length; index++) {
      optionControllers[index].text = question.options[index];
    }
    explanationController.text = question.explanation;
    correctAnswer = question.answer;
    tags.addAll(question.tags);
  }

  @override
  void dispose() {
    questionController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
    explanationController.dispose();
    tagController.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Question(
        questionController.text.trim(),
        optionControllers.map((controller) => controller.text.trim()).toList(),
        correctAnswer,
        explanationController.text.trim(),
        tags: tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialQuestion == null ? 'Add question' : 'Edit question',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: questionController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    alignLabelWithHint: true,
                  ),
                  validator: requiredField,
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < optionControllers.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextFormField(
                      controller: optionControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Option ${String.fromCharCode(65 + index)}',
                      ),
                      validator: requiredField,
                    ),
                  ),
                DropdownButtonFormField<int>(
                  initialValue: correctAnswer,
                  decoration: const InputDecoration(
                    labelText: 'Correct answer',
                  ),
                  items: [
                    for (
                      var index = 0;
                      index < optionControllers.length;
                      index++
                    )
                      DropdownMenuItem(
                        value: index,
                        child: Text(
                          'Option ${String.fromCharCode(65 + index)}',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => correctAnswer = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: explanationController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Explanation (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: tagController,
                        decoration: const InputDecoration(
                          labelText: 'Add Topic Tag (e.g., Algebra)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        final t = tagController.text.trim();
                        if (t.isNotEmpty && !tags.contains(t)) {
                          setState(() {
                            tags.add(t);
                            tagController.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            onDeleted: () => setState(() => tags.remove(tag)),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: submit,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            widget.initialQuestion == null ? 'Add question' : 'Save changes',
          ),
        ),
      ],
    );
  }

  String? requiredField(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }
}

class SavedQuestionsView extends StatelessWidget {
  const SavedQuestionsView({
    super.key,
    required this.banks,
    required this.bookmarkedKeys,
    required this.onToggleBookmark,
  });

  final List<ExamBank> banks;
  final Set<String> bookmarkedKeys;
  final Future<void> Function(String) onToggleBookmark;

  List<_SavedQuestion> get _savedQuestions {
    final saved = <_SavedQuestion>[];
    for (final key in bookmarkedKeys) {
      final separator = key.lastIndexOf(':');
      if (separator <= 0) continue;
      final source = key.substring(0, separator);
      final index = int.tryParse(key.substring(separator + 1));
      if (index == null) continue;
      for (final bank in banks) {
        if (bank.fileName == source &&
            index >= 0 &&
            index < bank.questions.length) {
          saved.add(_SavedQuestion(key, bank, index, bank.questions[index]));
          break;
        }
      }
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = _savedQuestions;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Questions')),
      body: questions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      size: 52,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No saved questions yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the bookmark icon while practicing to keep a question here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: questions.length,
              itemBuilder: (context, itemIndex) {
                final saved = questions[itemIndex];
                final question = saved.question;
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                saved.bank.title,
                                style: TextStyle(
                                  color: saved.bank.color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove saved question',
                              onPressed: () => onToggleBookmark(saved.key),
                              icon: const Icon(Icons.bookmark_rounded),
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        Text(
                          question.cleanText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(question.options.length, (
                          optionIndex,
                        ) {
                          final isCorrect = optionIndex == question.answer;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isCorrect
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: isCorrect
                                      ? const Color(0xFF059669)
                                      : theme.hintColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    question.getCleanOption(optionIndex),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (question.explanation.isNotEmpty) ...[
                          const Divider(height: 20),
                          Text(
                            question.explanation,
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 12,
                              height: 1.3,
                            ),
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

class _SavedQuestion {
  const _SavedQuestion(this.key, this.bank, this.index, this.question);

  final String key;
  final ExamBank bank;
  final int index;
  final Question question;
}

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key, required this.attempts});
  final List<Attempt> attempts;

  Map<String, List<bool>> get _tagPerformance {
    final stats = <String, List<bool>>{};
    for (final attempt in attempts) {
      final questions = attempt.category.questions;
      for (
        var i = 0;
        i < questions.length && i < attempt.selectedAnswers.length;
        i++
      ) {
        final selected = attempt.selectedAnswers[i];
        if (selected == null) continue;
        final correct = selected == questions[i].answer;
        final tags = questions[i].tags;
        if (tags.isEmpty) {
          stats.putIfAbsent('General', () => []).add(correct);
        } else {
          for (final tag in tags) {
            stats.putIfAbsent(tag, () => []).add(correct);
          }
        }
      }
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalQuestions = attempts.fold<int>(
      0,
      (runningTotal, item) => runningTotal + item.category.questions.length,
    );
    final totalAnswered = attempts.fold<int>(
      0,
      (runningTotal, item) => runningTotal + item.answeredCount,
    );
    final totalCorrect = attempts.fold<int>(
      0,
      (runningTotal, item) => runningTotal + item.correctCount,
    );
    final totalScore = attempts.fold<double>(
      0,
      (runningTotal, item) => runningTotal + item.score,
    );
    final average = totalQuestions == 0
        ? 0
        : (totalScore / totalQuestions * 100).round();
    final accuracy = totalAnswered == 0
        ? 0
        : ((totalCorrect / totalAnswered) * 100).round();

    final tagStats = _tagPerformance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          'Insights',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Understand your exam strengths and readiness.',
          style: TextStyle(color: theme.hintColor),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                'Average score',
                '$average%',
                Icons.speed_rounded,
                const Color(0xFF0E7490),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                context,
                'Accuracy',
                '$accuracy%',
                Icons.track_changes_rounded,
                const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                'Tests Done',
                '${attempts.length}',
                Icons.done_all_rounded,
                const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                context,
                'Questions',
                '$totalAnswered',
                Icons.quiz_outlined,
                const Color(0xFFD97706),
              ),
            ),
          ],
        ),
        if (tagStats.isNotEmpty) ...[
          const SizedBox(height: 26),
          Text(
            'Topic Heatmap',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          ...tagStats.entries.map((entry) {
            final results = entry.value;
            final correct = results.where((r) => r).length;
            final ratio = results.isEmpty ? 0.0 : correct / results.length;
            final percent = (ratio * 100).round();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('$percent% accuracy ($correct/${results.length})'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: ratio,
                      color: ratio >= 0.7
                          ? Colors.green
                          : (ratio >= 0.4 ? Colors.orange : Colors.red),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 26),
        Text(
          'Paper performance',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        if (attempts.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.insights_rounded, size: 48, color: theme.hintColor),
                const SizedBox(height: 10),
                Text(
                  'Complete a paper to unlock insights.',
                  style: TextStyle(
                    color: theme.hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          ...attempts.map((attempt) {
            final value = attempt.total == 0
                ? 0.0
                : (attempt.score / attempt.total).clamp(0.0, 1.0);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          attempt.category.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${(value * 100).round()}%',
                          style: TextStyle(
                            color: attempt.category.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: value,
                      color: attempt.category.color,
                      backgroundColor: attempt.category.color.withValues(
                        alpha: 0.15,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
