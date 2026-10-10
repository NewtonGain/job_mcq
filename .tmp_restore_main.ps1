$historyPath = Join-Path $env:APPDATA 'Code\User\History\-12d0e112\hNOE.dart'
$mainPath = 'C:\src\project\job_mcq\lib\main.dart'
$historyText = [System.IO.File]::ReadAllText($historyPath)
if (-not $historyText.Contains('class _HomeScreenState') -or -not $historyText.Contains('class QuizScreen extends StatefulWidget') -or -not $historyText.Contains('TickerMode(enabled: index == tab')) {
  throw 'The selected history snapshot is not a valid pre-extraction main.dart.'
}
[System.IO.File]::WriteAllText($mainPath, $historyText, [System.Text.UTF8Encoding]::new($false))
Write-Output 'Restored main.dart from its pre-extraction VS Code history snapshot.'
