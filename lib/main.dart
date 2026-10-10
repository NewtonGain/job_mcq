import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'views/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JobPrepApp());
}

class JobPrepApp extends StatefulWidget {
  const JobPrepApp({super.key});

  @override
  State<JobPrepApp> createState() => _JobPrepAppState();
}

class _JobPrepAppState extends State<JobPrepApp> {
  @override
  void initState() {
    super.initState();
    ThemePreferences.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Job Prep MCQ',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const HomeScreen(),
        );
      },
    );
  }
}
