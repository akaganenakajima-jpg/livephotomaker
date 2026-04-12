# check-marketing-copy.ps1 — PowerShell shim that delegates to the bash script.
# This keeps Windows users on one workflow: `pwsh scripts/checks/check-marketing-copy.ps1`
# runs exactly what CI and git-bash users run.
$ErrorActionPreference = 'Stop'
bash scripts/hooks/check-marketing-copy.sh
