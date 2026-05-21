# Builds the given solution without re-running restore. Assumes
# Invoke-DotnetRestore.ps1 has already run earlier in the job; the
# `--no-restore` flag enforces that separation so a missing restore
# step fails loudly instead of being silently re-done here.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SolutionPath
)

$ErrorActionPreference = 'Stop'

& dotnet build $SolutionPath --no-restore
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
