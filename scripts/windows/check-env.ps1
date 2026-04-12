# check-env.ps1
# Verifies the local Windows machine has every tool this Expo project needs,
# and prints a tidy pass/fail report. Exits non-zero if anything is missing
# so it can gate a local "pre-commit" workflow.

$ErrorActionPreference = 'Continue'

function Test-Tool {
  param(
    [string]$Name,
    [string]$Command,
    [string]$VersionArg = '--version'
  )
  try {
    $out = & $Command $VersionArg 2>$null
    if ($LASTEXITCODE -eq 0 -and $null -ne $out) {
      Write-Host ("  [ok]   {0,-14} {1}" -f $Name, ($out -split "`n")[0]) -ForegroundColor Green
      return $true
    }
  } catch {}
  Write-Host ("  [fail] {0,-14} missing" -f $Name) -ForegroundColor Red
  return $false
}

Write-Host '=== Environment check ===' -ForegroundColor Cyan

$results = @()
$results += Test-Tool -Name 'node'  -Command 'node'
$results += Test-Tool -Name 'npm'   -Command 'npm'
$results += Test-Tool -Name 'git'   -Command 'git'
$results += Test-Tool -Name 'gh'    -Command 'gh'

# Expo / EAS CLIs may not be installed globally — that is OK, we run them via npx.
try {
  $expoVersion = & npx --yes expo --version 2>$null
  Write-Host ("  [ok]   {0,-14} {1}" -f 'expo', $expoVersion) -ForegroundColor Green
} catch {
  Write-Host '  [warn] expo           not available via npx' -ForegroundColor Yellow
}

$failed = $results | Where-Object { $_ -eq $false }
if ($failed.Count -gt 0) {
  Write-Host ''
  Write-Host 'Missing tools detected. Run scripts/windows/setup-dev.ps1 first.' -ForegroundColor Red
  exit 1
}

Write-Host ''
Write-Host 'All required tools present.' -ForegroundColor Green
exit 0
