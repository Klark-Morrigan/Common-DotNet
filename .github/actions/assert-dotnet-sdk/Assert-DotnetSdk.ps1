# Fails fast with an actionable message if the .NET SDK is not on PATH.
# Without this preflight, a missing SDK surfaces as a confusing `dotnet
# restore` error several steps later. The SDK is provisioned by
# Infrastructure-GitHubRunners; the error message points there so the
# fix lands in the right repo (the runner image), not ad hoc on the
# runner host.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$version = (& dotnet --version) 2>$null
if ([string]::IsNullOrWhiteSpace($version)) {
    Write-Error (
        '.NET SDK not found on runner. The SDK is provisioned by ' +
        'Infrastructure-GitHubRunners; update the runner image there ' +
        'rather than installing ad hoc on the runner.'
    )
    exit 1
}

Write-Host ".NET SDK version: $version"
