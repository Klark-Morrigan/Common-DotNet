# Installs the ReportGenerator global tool on a GitHub-hosted runner,
# where it is not baked into the image. On the self-hosted pool the tool
# comes from Infrastructure-GitHubRunners, so the reusable workflow does
# not run this action there - this script never touches that path.
#
# Idempotent: a warm tool cache or a job re-run must not fail on "tool
# already installed", so we probe with Get-Command first (the same
# canonical availability check the assert-reportgenerator preflight
# uses) and skip the install when the tool is already present.
#
# PATH note: `dotnet tool install --global` drops the binary in
# ~/.dotnet/tools, which is NOT on PATH on hosted images. The later
# assert-reportgenerator and dotnet-coverage-report steps run in their
# own shells, so we publish that directory through $GITHUB_PATH, which
# prepends it for every subsequent step in the job (it does not affect
# the current step, but no later command in this step needs the tool).

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$tool = Get-Command -Name 'reportgenerator' -ErrorAction SilentlyContinue
if ($null -ne $tool) {
    Write-Host "ReportGenerator already present at: $($tool.Source)"
    return
}

dotnet tool install --global dotnet-reportgenerator-globaltool

# Surface the global-tools directory to later steps. Join-Path keeps the
# separator correct on both the ubuntu and windows hosted images.
$toolsDir = Join-Path -Path $HOME -ChildPath '.dotnet/tools'
Add-Content -Path $env:GITHUB_PATH -Value $toolsDir

Write-Host "ReportGenerator installed; added '$toolsDir' to PATH."
