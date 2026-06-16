# Restores NuGet packages for the given solution. Split into a script
# so the workflow YAML stays an orchestrator and the command surface is
# testable locally without driving the workflow.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SolutionPath
)

$ErrorActionPreference = 'Stop'

& dotnet restore $SolutionPath
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
