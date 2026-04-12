# login.ps1
# Thin wrapper over `npx eas login`. Keeps one canonical way to authenticate
# so README / CLAUDE.md can link to a single command.

$ErrorActionPreference = 'Stop'
Write-Host 'Launching EAS login. A browser may open to complete auth.' -ForegroundColor Cyan
npx --yes eas-cli@latest login
