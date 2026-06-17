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
#
# Optional flags (both omitted unless the caller supplies them, so the
# default behaviour is unchanged):
# - RunSettingsPath -> `--settings`: lets a consumer apply coverage
#   exclusions (e.g. framework-generated migrations) so the threshold
#   gate measures only meaningful code. `dotnet test` does NOT
#   auto-discover a .runsettings file, so it must be passed explicitly.
# - TestFilter -> `--filter`: lets a consumer skip tests that cannot run
#   on the CI runner (e.g. Docker-dependent integration tests).

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SolutionPath,

    # Empty/whitespace means "no --settings flag".
    [string] $RunSettingsPath = '',

    # Empty/whitespace means "no --filter flag".
    [string] $TestFilter = ''
)

$ErrorActionPreference = 'Stop'

# Build the argument list incrementally so an unsupplied optional flag
# is absent entirely rather than passed as an empty string (which
# `dotnet test` would reject).
$dotnetArgs = @(
    'test', $SolutionPath,
    '--no-build',
    '--collect:XPlat Code Coverage',
    '--results-directory', './TestResults'
)

if (-not [string]::IsNullOrWhiteSpace($RunSettingsPath)) {
    if (-not (Test-Path -LiteralPath $RunSettingsPath)) {
        Write-Error "Provided runsettings-path '$RunSettingsPath' does not exist."
        exit 1
    }
    $dotnetArgs += @('--settings', $RunSettingsPath)
}

if (-not [string]::IsNullOrWhiteSpace($TestFilter)) {
    $dotnetArgs += @('--filter', $TestFilter)
}

& dotnet @dotnetArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
