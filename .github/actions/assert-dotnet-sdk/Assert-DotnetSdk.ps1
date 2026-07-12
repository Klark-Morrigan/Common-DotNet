# Fails fast with an actionable message if the .NET SDK is not on PATH.
# Without this preflight, a missing SDK surfaces as a confusing `dotnet
# restore` error several steps later. On self-hosted the SDK is expected
# to be baked into the runner image; the error message points at the
# runner image (the runner operator's concern, external to this workflow)
# so the fix lands there, not ad hoc on the runner host.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$version = (& dotnet --version) 2>$null
if ([string]::IsNullOrWhiteSpace($version)) {
    Write-Error (
        '.NET SDK not found on runner. On self-hosted the SDK is ' +
        'expected to be baked into the runner image; update the runner ' +
        'image rather than installing ad hoc on the runner.'
    )
    exit 1
}

Write-Host ".NET SDK version: $version"
