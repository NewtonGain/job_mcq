$history = Join-Path $env:APPDATA 'Code\User\History\-12d0e112'
$tempPath = 'C:\src\project\job_mcq\lib\_history_candidate.dart'
$ids = @('1WIp.dart', 'hNOE.dart', 'SEs3.dart', 'byRl.dart', '5KmD.dart', 'DlyU.dart')
foreach ($id in $ids) {
  $candidate = Join-Path $history $id
  if (-not (Test-Path $candidate)) { continue }
  [System.IO.File]::Copy($candidate, $tempPath, $true)
  $output = & dart format --output=none $tempPath 2>&1
  $exitCode = $LASTEXITCODE
  $summary = ($output | Select-Object -Last 2) -join ' '
  Write-Output ("{0} parseExit={1} {2}" -f $id, $exitCode, $summary)
}
Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
