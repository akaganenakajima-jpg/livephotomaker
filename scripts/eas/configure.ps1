# configure.ps1
# Runs `eas init` + `eas build:configure` in sequence so the project gets a
# valid EXPO_PROJECT_ID and an `eas.json` wired up to the Expo servers.
#
# Re-running this on a project that is already configured is safe — the CLI
# detects the existing IDs and is a no-op.

$ErrorActionPreference = 'Stop'
Write-Host 'Initialising EAS project (will update app.config.ts if needed)...' -ForegroundColor Cyan
npx --yes eas-cli@latest init
npx --yes eas-cli@latest build:configure --platform ios
