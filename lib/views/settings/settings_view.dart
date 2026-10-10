import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../models/exam_bank.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    this.banks = const [],
    this.onAddQuestion,
    this.onManageQuestions,
    this.onAddCategory,
    this.onDeleteCategory,
    this.onClearHistory,
  });

  final List<ExamBank> banks;
  final Future<void> Function(ExamBank)? onAddQuestion;
  final Future<void> Function(ExamBank)? onManageQuestions;
  final Future<void> Function()? onAddCategory;
  final Future<void> Function(ExamBank)? onDeleteCategory;
  final VoidCallback? onClearHistory;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  static const _timerDurations = [15, 30, 45, 60];
  static const _negativeMarkingOptions = [0.0, 0.25, 0.5, 1.0];
  static const _dailyQuestionGoals = [5, 10, 20, 30];

  bool notifications = true;
  bool timer = false;
  bool sound = true;
  int timerDuration = 30;
  double negativeMarking = 0.25;
  int dailyQuestionGoal = 10;

  @override
  void initState() {
    super.initState();
    restoreSettings();
  }

  Future<void> restoreSettings() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notifications = preferences.getBool('notifications') ?? true;
      timer = preferences.getBool('timer') ?? false;
      sound = preferences.getBool('sound') ?? true;
      final savedPenalty = preferences.getDouble('negative_marking') ?? 0.25;
      negativeMarking = _negativeMarkingOptions.contains(savedPenalty)
          ? savedPenalty
          : 0.25;
      final savedDailyGoal = preferences.getInt('daily_question_goal') ?? 10;
      dailyQuestionGoal = _dailyQuestionGoals.contains(savedDailyGoal)
          ? savedDailyGoal
          : 10;
      appDailyQuestionGoal.value = dailyQuestionGoal;
      final savedDuration = preferences.getInt('timer_duration') ?? 30;
      timerDuration = _timerDurations.contains(savedDuration)
          ? savedDuration
          : 30;
    });
  }

  Future<void> updateSetting(String key, bool value) async {
    setState(() {
      if (key == 'notifications') notifications = value;
      if (key == 'timer') timer = value;
      if (key == 'sound') sound = value;
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }

  Future<void> _setTheme(String mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('theme_mode', mode);
    appThemeMode.value = switch (mode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  Future<void> _setTimerDuration(int duration) async {
    setState(() => timerDuration = duration);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('timer_duration', duration);
  }

  Future<void> _setNegativeMarking(double value) async {
    setState(() => negativeMarking = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('negative_marking', value);
  }

  Future<void> _setDailyQuestionGoal(int value) async {
    setState(() => dailyQuestionGoal = value);
    appDailyQuestionGoal.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('daily_question_goal', value);
  }

  Future<void> _restoreDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore default settings?'),
        content: const Text(
          'Your appearance and quiz preferences will return to their defaults. Practice history will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore defaults'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('notifications');
    await preferences.remove('timer');
    await preferences.remove('sound');
    await preferences.remove('timer_duration');
    await preferences.remove('negative_marking');
    await preferences.remove('daily_question_goal');
    await preferences.remove('theme_mode');
    if (!mounted) return;
    setState(() {
      notifications = true;
      timer = false;
      sound = true;
      timerDuration = 30;
      negativeMarking = 0.25;
      dailyQuestionGoal = 10;
      appDailyQuestionGoal.value = dailyQuestionGoal;
    });
    appThemeMode.value = ThemeMode.system;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings restored to defaults.')),
    );
  }

  Future<void> _clearHistory() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset history?'),
        content: const Text(
          'This will delete all your attempts and insights records. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    widget.onClearHistory?.call();
    messenger?.showSnackBar(
      const SnackBar(content: Text('Practice history cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                _sectionIcon(context, Icons.tune_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Personalize your study experience.',
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _sectionLabel(context, 'APPEARANCE'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _settingHeading(
                      context,
                      Icons.palette_outlined,
                      'Color theme',
                      'Choose how the app looks',
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: appThemeMode,
                      builder: (context, currentMode, _) => SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.settings_suggest_outlined),
                              label: Text('System'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {currentMode},
                          onSelectionChanged: (selection) {
                            final mode = selection.first;
                            _setTheme(
                              mode == ThemeMode.dark
                                  ? 'dark'
                                  : mode == ThemeMode.light
                                  ? 'light'
                                  : 'system',
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'STUDY PREFERENCES'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: const Text('Daily reminder'),
                    subtitle: const Text(
                      'Stay consistent with your daily targets',
                    ),
                    trailing: Switch(
                      value: notifications,
                      onChanged: (value) =>
                          updateSetting('notifications', value),
                    ),
                  ),
                  const Divider(height: 1),
                  _segmentedSetting<int>(
                    icon: Icons.flag_outlined,
                    title: 'Daily question goal',
                    subtitle: 'Questions to complete each day',
                    selected: dailyQuestionGoal,
                    segments: _dailyQuestionGoals
                        .map(
                          (goal) => ButtonSegment<int>(
                            value: goal,
                            label: Text('$goal'),
                          ),
                        )
                        .toList(),
                    onSelected: _setDailyQuestionGoal,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Quiz timer'),
                    subtitle: Text(
                      'Enable $timerDuration-second timer per question',
                    ),
                    trailing: Switch(
                      value: timer,
                      onChanged: (value) => updateSetting('timer', value),
                    ),
                  ),
                  if (timer)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: _timerDurations
                              .map(
                                (duration) => ButtonSegment<int>(
                                  value: duration,
                                  label: Text('${duration}s'),
                                ),
                              )
                              .toList(),
                          selected: {timerDuration},
                          onSelectionChanged: (selection) =>
                              _setTimerDuration(selection.first),
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.volume_up_outlined),
                    title: const Text('Sound effects'),
                    subtitle: const Text(
                      'Play sound on right and wrong answers',
                    ),
                    trailing: Switch(
                      value: sound,
                      onChanged: (value) => updateSetting('sound', value),
                    ),
                  ),
                  const Divider(height: 1),
                  _segmentedSetting<double>(
                    icon: Icons.remove_circle_outline_rounded,
                    title: 'Wrong-answer penalty',
                    subtitle: 'Points deducted per incorrect answer',
                    selected: negativeMarking,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('0')),
                      ButtonSegment(value: 0.25, label: Text('0.25')),
                      ButtonSegment(value: 0.5, label: Text('0.5')),
                      ButtonSegment(value: 1, label: Text('1.0')),
                    ],
                    onSelected: _setNegativeMarking,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'QUESTION LIBRARY'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.library_books_outlined, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Manage question library',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add category',
                          onPressed: widget.onAddCategory == null
                              ? null
                              : () => widget.onAddCategory!(),
                          icon: const Icon(Icons.create_new_folder_outlined),
                        ),
                      ],
                    ),
                  ),
                  if (widget.banks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text('No question categories are available yet.'),
                    )
                  else
                    ...widget.banks.asMap().entries.map((entry) {
                      final bank = entry.value;
                      return Column(
                        children: [
                          if (entry.key > 0) const Divider(height: 1),
                          ListTile(
                            leading: Icon(bank.icon, color: bank.color),
                            title: Text(bank.title),
                            subtitle: Text(
                              '${bank.questions.length} questions • Local',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Add question',
                                  onPressed: widget.onAddQuestion == null
                                      ? null
                                      : () => widget.onAddQuestion!(bank),
                                  icon: const Icon(
                                    Icons.add_circle_outline_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Manage questions',
                                  onPressed: widget.onManageQuestions == null
                                      ? null
                                      : () => widget.onManageQuestions!(bank),
                                  icon: const Icon(Icons.edit_note_rounded),
                                ),
                                if (bank.fileName.startsWith('custom_'))
                                  IconButton(
                                    tooltip: 'Delete category',
                                    onPressed: widget.onDeleteCategory == null
                                        ? null
                                        : () => widget.onDeleteCategory!(bank),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'DATA & ABOUT'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text('Clear practice history'),
                    subtitle: const Text('Reset past quiz scores and attempts'),
                    onTap: _clearHistory,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded),
                    title: const Text('Restore default settings'),
                    subtitle: const Text(
                      'Reset appearance and quiz preferences',
                    ),
                    onTap: _restoreDefaults,
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('About Job Prep MCQ'),
                    subtitle: Text(
                      'Offline preparation for your next opportunity. Includes BCS, NTRCA, and Primary exam banks.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingHeading(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _sectionIcon(context, icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _segmentedSetting<T>({
    required IconData icon,
    required String title,
    required String subtitle,
    required T selected,
    required List<ButtonSegment<T>> segments,
    required ValueChanged<T> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _settingHeading(context, icon, title, subtitle),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: segments,
              selected: {selected},
              onSelectionChanged: (selection) => onSelected(selection.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _sectionIcon(BuildContext context, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: theme.colorScheme.primary, size: 20),
    );
  }
}
