# check-placeholders.ps1
# Scans the repo for unreplaced placeholder tokens and fails loudly so you
# don't ship a build with example values. The bash twin is
# `scripts/hooks/check-placeholders.sh` and both must stay in sync.
#
# Usage:
#   ./scripts/windows/check-placeholders.ps1

$ErrorActionPreference = 'Stop'

$patterns = @(
  'EXPO_PROJECT_ID_PLACEHOLDER',
  'APPLE_TEAM_ID_PLACEHOLDER',
  'ASC_APP_ID_PLACEHOLDER',
  'APPLE_ID_PLACEHOLDER',
  'BUNDLE_IDENTIFIER_PLACEHOLDER',
  'jp\.example\.livephotomaker'
)

$excludeDirs = @(
  '\.git\\', 'node_modules\\', '\.expo\\', '\.eas\\', '_legacy-swift\\',
  'build\\', 'dist\\', 'coverage\\', 'DerivedData\\'
)

# Files that are allowed to mention the placeholders for documentation
# reasons. Every other hit is treated as unreplaced.
$allowedFiles = @(
  'scripts\windows\check-placeholders.ps1',
  'scripts\hooks\check-placeholders.sh',
  'app.config.ts',
  'eas.json',
  'README.md',
  'docs\実機検証チェックリスト.md',
  '.env.example'
)

$files = Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue
$hits = @()
foreach ($file in $files) {
  $path = $file.FullName
  $skip = $false
  foreach ($e in $excludeDirs) {
    if ($path -match $e) { $skip = $true; break }
  }
  if ($skip) { continue }

  # Skip allowed documentation files.
  $relative = Resolve-Path -LiteralPath $path -Relative -ErrorAction SilentlyContinue
  if ($relative) {
    foreach ($allow in $allowedFiles) {
      if ($relative -like "*$allow*") { $skip = $true; break }
    }
  }
  if ($skip) { continue }

  $content = Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue
  if (-not $content) { continue }

  foreach ($pat in $patterns) {
    if ($content -match $pat) {
      $hits += [pscustomobject]@{ File = $path; Pattern = $pat }
    }
  }
}

if ($hits.Count -eq 0) {
  Write-Host 'No placeholders found.' -ForegroundColor Green
  exit 0
}

Write-Host 'Unreplaced placeholders detected:' -ForegroundColor Red
$hits | Format-Table -AutoSize
Write-Host ''
Write-Host 'Replace them with real values (see README "プレースホルダ一覧" section) before shipping.' -ForegroundColor Yellow
exit 1
