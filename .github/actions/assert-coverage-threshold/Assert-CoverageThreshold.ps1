# Enforces a minimum line-coverage percentage from the merged Cobertura
# file produced by `dotnet-coverage-report`. Without this gate, coverage
# erodes silently across PRs; ReportGenerator happily emits a report at
# any number and no downstream tool would otherwise object.
#
# Why read Cobertura instead of Summary.txt:
# - Cobertura exposes `line-rate` as a stable, machine-readable
#   attribute on the root element. `Summary.txt` is a human-formatted
#   file whose `Line coverage:` line is locale-sensitive (decimal
#   separator differs by culture) and reflows when ReportGenerator
#   versions change.
# - `Cobertura.xml` is named in the report action's contract as the
#   canonical input for this gate, so coupling here is explicit.
#
# Exit codes:
# - 0 when observed coverage >= threshold (or threshold == 0).
# - 1 with a diagnostic naming both observed and threshold when below.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $CoberturaPath,

    [Parameter(Mandatory = $true)]
    [double] $Threshold
)

$ErrorActionPreference = 'Stop'

# Coverage is a percentage of executed lines, so the meaningful range
# is [0, 100]. Anything above 100 is silently capped rather than
# rejected so consumers who pass `100.0` or accidentally overshoot do
# not turn a configuration typo into a hard CI failure; the cap
# preserves the strict-as-possible intent. Negative thresholds remain
# rejected - they are meaningless and almost certainly a typo.
if ($Threshold -lt 0) {
    Write-Error (
        "coverage-threshold must be non-negative; got '$Threshold'."
    )
    exit 1
}
if ($Threshold -gt 100) {
    Write-Host (
        "coverage-threshold $Threshold exceeds the maximum meaningful " +
        'value; capping at 100.'
    )
    $Threshold = 100
}

if (-not (Test-Path -LiteralPath $CoberturaPath)) {
    Write-Error (
        "Merged Cobertura file not found at '$CoberturaPath'. The " +
        '`dotnet-coverage-report` action must run earlier in the job ' +
        'and emit the `Cobertura` report type.'
    )
    exit 1
}

[xml] $xml = Get-Content -LiteralPath $CoberturaPath -Raw
$rateAttr = $xml.coverage.'line-rate'
if ([string]::IsNullOrWhiteSpace($rateAttr)) {
    Write-Error (
        "Cobertura file '$CoberturaPath' is missing the root " +
        '`line-rate` attribute; cannot evaluate the coverage gate.'
    )
    exit 1
}

# Cobertura's `line-rate` is a fraction in [0, 1] using `.` as the
# decimal separator regardless of culture. Force invariant parsing so
# runners with a non-en-US culture do not misread `0.95` as ninety-five.
$rate = [double]::Parse(
    $rateAttr,
    [System.Globalization.CultureInfo]::InvariantCulture
)
$observed = [math]::Round($rate * 100, 2)

if ($observed -lt $Threshold) {
    Write-Error (
        "Coverage gate failed: observed line coverage $observed% is " +
        "below the configured threshold of $Threshold%. Source: " +
        "'$CoberturaPath'."
    )
    exit 1
}

Write-Host (
    "Coverage gate passed: observed line coverage $observed% meets " +
    "threshold of $Threshold%."
)
