$path = Join-Path $env:APPDATA 'Code\User\History\-12d0e112\1WIp.dart'
$text = [System.IO.File]::ReadAllText($path)
foreach ($needle in @('TickerMode(enabled: index == tab', 'views/pdf_revision_view.dart', 'views/results_view.dart', 'views/review_screen.dart', 'views/saved_questions_view.dart', 'class ResultsView', 'class ReviewScreen', 'class SavedQuestionsView', 'class QuizScreen extends StatefulWidget', 'class SettingsView extends StatefulWidget', 'class PdfRevisionView extends StatefulWidget')) {
  Write-Output ("{0}={1}" -f $needle, $text.Contains($needle))
}
