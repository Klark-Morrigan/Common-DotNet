# Resolves which solution the CI pipeline builds and publishes it to
# $GITHUB_ENV as SOLUTION_PATH, so every downstream step reads one
# canonical value instead of re-deriving it.
#
# An explicit `solution-path` always wins. When omitted, the repo is
# scanned for a single .sln/.slnx so simple consumers (and this repo's
# own self-test) need no input at all - matching the input-free
# ergonomics of the Common-Automation reusable workflows. Ambiguity is an
# error, not a silent pick: zero or multiple matches fail with an
# actionable message rather than guessing wrong and building the wrong
# solution.

[CmdletBinding()]
param(
    # Empty/whitespace means "auto-discover"; a value is used verbatim.
    [string] $SolutionPath
)

$ErrorActionPreference = 'Stop'

if (-not [string]::IsNullOrWhiteSpace($SolutionPath)) {
    if (-not (Test-Path -LiteralPath $SolutionPath)) {
        Write-Error "Provided solution-path '$SolutionPath' does not exist."
        exit 1
    }
    $resolved = $SolutionPath
}
else {
    # Discover a single solution. Exclude the .common-dotnet sparse
    # checkout (it carries composite actions, not consumer code) and the
    # build output dirs so a stale copy under bin/obj never matches.
    $candidates = Get-ChildItem -Path . -Recurse -File -Include '*.sln', '*.slnx' |
        Where-Object {
            $_.FullName -notmatch '[\\/]\.common-dotnet[\\/]' -and
            $_.FullName -notmatch '[\\/](bin|obj)[\\/]'
        }

    if ($candidates.Count -eq 0) {
        Write-Error (
            'No .sln or .slnx found in the repository, and no ' +
            'solution-path input was supplied. Pass solution-path ' +
            'explicitly or add a solution file.'
        )
        exit 1
    }
    if ($candidates.Count -gt 1) {
        $list = ($candidates | ForEach-Object { $_.FullName }) -join "`n  "
        Write-Error (
            "Multiple solution files found; solution-path is ambiguous. " +
            "Pass solution-path explicitly to pick one:`n  $list"
        )
        exit 1
    }

    # Emit a repo-relative path so logs and downstream dotnet commands
    # stay independent of the runner's absolute workspace location.
    $resolved = Resolve-Path -LiteralPath $candidates[0].FullName -Relative
}

Write-Host "Resolved solution-path: $resolved"

# GITHUB_ENV publishes the value to every subsequent step in the job.
# pwsh writes UTF-8 without a BOM, which the runner's env-file parser
# requires (a BOM would corrupt the first key).
Add-Content -Path $env:GITHUB_ENV -Value "SOLUTION_PATH=$resolved"
