# Removes build and coverage output that may have been left behind by a
# prior job on the same self-hosted runner. `_work/` persists across
# jobs, so stale `bin/`, `obj/`, `TestResults/`, or `CoverageReport/`
# directories can poison a later build (ghost assemblies, leftover
# coverage). This script wipes them before any compile or measure step.

[CmdletBinding()]
param(
    [Parameter()]
    [string] $WorkspaceRoot = (Get-Location).Path,

    [Parameter()]
    [string[]] $Patterns = @('bin', 'obj', 'TestResults', 'CoverageReport')
)

$ErrorActionPreference = 'Stop'

foreach ($pattern in $Patterns) {
    Get-ChildItem -Path $WorkspaceRoot -Recurse -Force -Directory `
            -Filter $pattern -ErrorAction SilentlyContinue |
        ForEach-Object {
            Write-Host "Removing $($_.FullName)"
            Remove-Item -LiteralPath $_.FullName `
                -Recurse -Force -ErrorAction SilentlyContinue
        }
}
