# git-bootstrap.ps1
# One-shot helper that turns the current folder into a private GitHub repo,
# using the GitHub CLI. Intended for when you cloned the scaffold locally
# and want to push it to your own account without opening the browser.
#
# Usage:
#   ./scripts/windows/git-bootstrap.ps1 -RepoName 'video-to-livephoto'
#
# What it does:
#   1. git init (if not already a repo)
#   2. git add . && git commit (if there's anything to commit)
#   3. gh auth status (prompts to login if not logged in)
#   4. gh repo create <name> --private --source . --push

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$RepoName,

  [string]$Description = 'Expo + TypeScript Live Photo maker (iOS)'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path '.git')) {
  Write-Host 'Initialising git repository...' -ForegroundColor Cyan
  git init --initial-branch=main
}

$status = git status --porcelain
if ($status) {
  git add .
  git commit -m 'chore: initial Expo scaffold'
}

Write-Host 'Checking GitHub CLI auth...' -ForegroundColor Cyan
gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Not logged in. Running `gh auth login`...' -ForegroundColor Yellow
  gh auth login
}

Write-Host "Creating private repo '$RepoName'..." -ForegroundColor Cyan
gh repo create $RepoName --private --source . --remote origin --push --description $Description

Write-Host ''
Write-Host "Done. Repo created and pushed." -ForegroundColor Green
