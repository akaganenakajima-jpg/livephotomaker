# setup-dev.ps1
# Installs the baseline Windows toolchain needed to develop this Expo project
# WITHOUT a Mac. Safe to re-run; each step checks if the tool is already there.
#
# What this script installs:
#   - Node LTS (20.x) via winget
#   - Git
#   - Visual Studio Code
#   - GitHub CLI (gh)
#   - pnpm (optional, enabled by $InstallPnpm)
#
# What this script does NOT install:
#   - Xcode (Mac only, not needed — we use EAS Build in the cloud)
#   - Android Studio (only needed if you add Android later)
#
# Usage (PowerShell, as your normal user — not admin):
#   ./scripts/windows/setup-dev.ps1
#
# If a winget install prompts for consent, accept it. The script will
# continue with the next tool either way.

[CmdletBinding()]
param(
  [switch]$InstallPnpm
)

$ErrorActionPreference = 'Stop'

function Install-IfMissing {
  param(
    [string]$Name,
    [string]$WingetId,
    [string]$CheckCommand
  )

  $exists = $null
  try {
    $exists = Get-Command $CheckCommand -ErrorAction SilentlyContinue
  } catch {
    $exists = $null
  }

  if ($null -ne $exists) {
    Write-Host "[skip] $Name already installed" -ForegroundColor DarkGray
    return
  }

  Write-Host "[install] $Name ($WingetId)" -ForegroundColor Cyan
  winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
}

Write-Host "=== Expo dev toolchain (Windows) ===" -ForegroundColor Green

Install-IfMissing -Name 'Node.js LTS'     -WingetId 'OpenJS.NodeJS.LTS'     -CheckCommand 'node'
Install-IfMissing -Name 'Git for Windows' -WingetId 'Git.Git'               -CheckCommand 'git'
Install-IfMissing -Name 'Visual Studio Code' -WingetId 'Microsoft.VisualStudioCode' -CheckCommand 'code'
Install-IfMissing -Name 'GitHub CLI'      -WingetId 'GitHub.cli'            -CheckCommand 'gh'

if ($InstallPnpm) {
  Install-IfMissing -Name 'pnpm' -WingetId 'pnpm.pnpm' -CheckCommand 'pnpm'
}

Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Yellow
Write-Host '  1. Close and re-open your terminal so PATH updates take effect.'
Write-Host '  2. Run: npm install'
Write-Host '  3. Run: npm run typecheck'
Write-Host '  4. Read README.md for the EAS login + build flow.'
