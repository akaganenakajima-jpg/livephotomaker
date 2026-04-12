# build-ios.ps1
# Kicks off an EAS Build for iOS. Defaults to the 'development' profile so
# you can install the resulting IPA on a physical iPhone via the Expo
# developer menu. Pass -Profile preview or -Profile production to change it.
#
# Usage:
#   ./scripts/eas/build-ios.ps1                    # development build
#   ./scripts/eas/build-ios.ps1 -Profile preview   # internal distribution
#   ./scripts/eas/build-ios.ps1 -Profile production

[CmdletBinding()]
param(
  [ValidateSet('development', 'preview', 'production')]
  [string]$Profile = 'development'
)

$ErrorActionPreference = 'Stop'
Write-Host "Submitting iOS build (profile: $Profile) to EAS..." -ForegroundColor Cyan
npx --yes eas-cli@latest build --platform ios --profile $Profile --non-interactive
