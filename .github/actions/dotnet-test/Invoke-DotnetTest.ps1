# Runs the tests in the given solution without re-running build.
# Assumes Invoke-DotnetBuild.ps1 has already run earlier in the job;
# the `--no-build` flag enforces that separation so a missing build
# step fails loudly instead of being silently re-done here.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SolutionPath
)

$ErrorActionPreference = 'Stop'

& dotnet test $SolutionPath --no-build
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
