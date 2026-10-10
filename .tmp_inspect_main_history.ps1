$history = Join-Path $env:APPDATA 'Code\User\History\-12d0e112'
$metadata = Get-Content (Join-Path $history 'entries.json') -Raw | ConvertFrom-Json
foreach ($entry in $metadata.entries) {
  $path = Join-Path $history $entry.id
  if (-not (Test-Path $path)) { continue }
  $text = [System.IO.File]::ReadAllText($path)
  if ($text.Contains('class _HomeScreenState')) {
    $hasQuiz = $text.Contains('class QuizScreen extends StatefulWidget')
    $hasSettings = $text.Contains('class SettingsView extends StatefulWidget')
    $hasPdf = $text.Contains('class PdfRevisionView extends StatefulWidget')
    $hasSaved = $text.Contains('class SavedQuestionsView extends StatelessWidget')
    Write-Output ("{0} timestamp={1} length={2} quiz={3} settings={4} pdf={5} saved={6}" -f $entry.id, $entry.timestamp, $text.Length, $hasQuiz, $hasSettings, $hasPdf, $hasSaved)
  }
}
