# Job Prep MCQ

Job Prep MCQ is an offline Flutter app for preparing for competitive and public
sector exams. It loads question banks bundled with the app; custom questions,
bookmarks, quiz progress, and attempt history are stored on the device.

## Features

- Browse question banks by exam group and search by paper name.
- Practice with daily challenges, weak-area review, and timed exam modes.
- Save questions, review completed attempts, and track performance.
- Add and manage custom categories and questions.
- Choose system, light, or dark appearance.

## Content

- Question-bank JSON files are under `assets/questions/`.
- Asset directories are declared in `pubspec.yaml`; update the declarations
	when adding a new nested directory.

The app reads question data at runtime from the bundled asset manifest. Keep
question files valid JSON and ensure each question has a usable prompt, at least
two non-empty answers, and one identifiable correct answer.

## Development

Requirements: a Flutter SDK whose bundled Dart SDK satisfies the constraint in
`pubspec.yaml`.

```sh
flutter pub get
flutter run
flutter test
flutter analyze
```
# job_mcq
