# submit-ios.ps1
# Uploads the latest EAS-built IPA to TestFlight / App Store Connect.
# Requires that eas.json has `submit.production.ios` filled in with your
# APPLE_TEAM_ID and ASC_APP_ID (see README "Placeholders").
#
# Usage:
#   ./scripts/eas/submit-ios.ps1

$ErrorActionPreference = 'Stop'
Write-Host 'Submitting latest iOS production build to App Store Connect...' -ForegroundColor Cyan
npx --yes eas-cli@latest submit --platform ios --latest --non-interactive
