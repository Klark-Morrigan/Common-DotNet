# Generates a human-readable coverage report from one or more Cobertura
# files produced by the upstream `dotnet-test` step. Without this, the
# only coverage artifact is a raw `coverage.cobertura.xml` which is not
# directly useful to reviewers on a PR.
#
# Outputs (under $TargetDir, default `CoverageReport/`):
# - `index.html` - browsable HTML report.
# - `Summary.txt` - plain-text summary including a `Line coverage:`
#   line that the downstream threshold gate (Step 6) parses.
# - `Cobertura.xml` - merged Cobertura across all input report files.
#   Pinned as a report type here so the threshold gate has a single
#   canonical file to read instead of globbing `TestResults/`.

[CmdletBinding()]
param(
    [Parameter()]
    [string] $ReportsGlob = 'TestResults/**/coverage.cobertura.xml',

    [Parameter()]
    [string] $TargetDir = 'CoverageReport'
)

$ErrorActionPreference = 'Stop'

# Fail loudly if no Cobertura inputs exist. ReportGenerator silently
# succeeds with zero inputs and produces a near-empty report, which
# would make the threshold gate downstream pass against nothing.
$matched = Get-ChildItem -Path $ReportsGlob -ErrorAction SilentlyContinue
if (-not $matched) {
    Write-Error (
        "No Cobertura coverage files matched '$ReportsGlob'. The " +
        'dotnet-test step must run with --collect:"XPlat Code ' +
        'Coverage" and consumer test projects must reference the ' +
        '`coverlet.collector` NuGet package.'
    )
    exit 1
}

& reportgenerator `
    "-reports:$ReportsGlob" `
    "-targetdir:$TargetDir" `
    "-reporttypes:Html;TextSummary;Cobertura"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
