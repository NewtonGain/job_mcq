$ErrorActionPreference = 'SilentlyContinue'
$roots = @(
  (Join-Path $env:APPDATA 'Code\Backups'),
  (Join-Path $env:APPDATA 'Code\User\History'),
  (Join-Path $env:APPDATA 'Code\User\workspaceStorage')
) | Where-Object { Test-Path $_ }
foreach ($root in $roots) {
  Get-ChildItem $root -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 3000000 } | ForEach-Object {
    try {
      $text = [System.IO.File]::ReadAllText($_.FullName)
      if ($text.Contains('class _HomeScreenState') -and $text.Contains("'EXAM DESK'")) {
        Write-Output $_.FullName
      }
    } catch {}
  }
}
