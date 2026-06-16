# Runs the tests in the given solution without re-running build, and
# collects code coverage via Coverlet's data collector. Assumes
# Invoke-DotnetBuild.ps1 has already run earlier in the job; the
# `--no-build` flag enforces that separation so a missing build step
# fails loudly instead of being silently re-done here.
#
# Coverage contract:
# - `--collect:"XPlat Code Coverage"` activates the `coverlet.collector`
#   data collector that consumer test projects reference as a
#   PackageReference. No per-project .runsettings is required for the
#   default Cobertura output.
# - `--results-directory ./TestResults` pins the output location to a
#   workspace-relative path so downstream steps (ReportGenerator, the
#   threshold gate) can find `TestResults/<guid>/coverage.cobertura.xml`
#   without scanning the filesystem.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SolutionPath
)

$ErrorActionPreference = 'Stop'

& dotnet test $SolutionPath `
    --no-build `
    --collect:"XPlat Code Coverage" `
    --results-directory ./TestResults
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
