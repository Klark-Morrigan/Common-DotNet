# Fails fast with an actionable message if the ReportGenerator global
# tool is not on PATH. Without this preflight, a missing tool surfaces
# as a confusing "command not found" several steps later inside the
# coverage-report step. ReportGenerator is provisioned by
# Infrastructure-GitHubRunners (as a `dotnet tool install -g`); the
# error message points there so the fix lands in the right repo (the
# runner image), not ad hoc on the runner host.
#
# Note: ReportGenerator does not expose a stable `--version` flag - the
# binary treats unknown args as "no inputs given" diagnostics. We probe
# for the command itself via Get-Command, which is the canonical
# PowerShell way to check tool availability and avoids parsing the
# tool's noisy stderr.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$tool = Get-Command -Name 'reportgenerator' -ErrorAction SilentlyContinue
if ($null -eq $tool) {
    Write-Error (
        'ReportGenerator not found on runner. The tool is provisioned ' +
        'by Infrastructure-GitHubRunners (installed as a global dotnet ' +
        'tool); update the runner image there rather than installing ' +
        'ad hoc on the runner.'
    )
    exit 1
}

Write-Host "ReportGenerator found at: $($tool.Source)"
