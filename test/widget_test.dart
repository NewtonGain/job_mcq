// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:job_mcq/main.dart';
import 'package:job_mcq/views/home/home_screen.dart';
import 'package:job_mcq/views/settings/settings_view.dart';

Future<void> _pumpUntilLibraryReady(WidgetTester tester) async {
  final readyLabel = find.text('Offline library ready');
  for (
    var attempt = 0;
    attempt < 50 && readyLabel.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(readyLabel, findsOneWidget);
}

void main() {
  testWidgets('shows the asset-driven exam library', (tester) async {
    await tester.pumpWidget(const JobPrepApp());

    expect(find.text('EXAM DESK'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await _pumpUntilLibraryReady(tester);
    await tester.pumpAndSettle();
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('Weak Area Review'), findsOneWidget);
    expect(find.textContaining('questions'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('All exam papers'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('All exam papers'), findsOneWidget);
  });

  testWidgets('shows the saved questions empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SavedQuestionsView(
          banks: const [],
          bookmarkedKeys: const {},
          onToggleBookmark: (_) async {},
        ),
      ),
    );

    expect(find.text('Saved Questions'), findsOneWidget);
    expect(find.text('No saved questions yet'), findsOneWidget);
  });

  testWidgets('settings fit a narrow phone viewport', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsView())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('About Job Prep MCQ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('persists the wrong-answer penalty setting', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsView())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('0.5').last);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('negative_marking'), 0.5);
  });

  testWidgets('persists the daily question goal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsView())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('daily_question_goal'), 20);
  });

  testWidgets('opens the daily challenge in practice mode', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('active_quiz');
    await preferences.setBool('timer', false);
    await tester.pumpWidget(const JobPrepApp());
    await _pumpUntilLibraryReady(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daily Challenge').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Daily Challenge'), findsAtLeastNWidgets(1));
    expect(find.textContaining('QUESTION'), findsOneWidget);
    expect(find.text('Finish paper now'), findsOneWidget);
  });

  testWidgets('can manually add a question to a category', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('custom_questions');
    await preferences.remove('active_quiz');
    await preferences.setBool('timer', false);
    await tester.pumpWidget(const JobPrepApp());
    await _pumpUntilLibraryReady(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add question').first);
    await tester.pumpAndSettle();

    expect(find.text('Add question'), findsWidgets);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Which option is correct?');
    await tester.enterText(fields.at(1), 'Option A');
    await tester.enterText(fields.at(2), 'Option B');
    await tester.enterText(fields.at(3), 'Option C');
    await tester.enterText(fields.at(4), 'Option D');
    await tester.tap(find.widgetWithText(FilledButton, 'Add question'));
    await tester.pumpAndSettle();

    expect(find.text('Which option is correct?'), findsOneWidget);
  });
}
