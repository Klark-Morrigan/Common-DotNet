#!/usr/bin/env bash
# Local mirror of ci-dotnet.yml: builds the target repo's solution, runs
# the tests with coverage, generates the coverage report, and enforces
# the coverage threshold gate - the same four stages, in the same order,
# the reusable workflow runs. Lets a developer reproduce the full .NET CI
# gate before pushing instead of round-tripping through Actions.
#
# This is the user-facing entry - the .NET counterpart to
# Common-Automation's run-ci-yaml-and-bash.sh. It is target-aware: with
# no COMMON_DOTNET_TARGET_REPO it runs against Common-DotNet's own sample
# solution (this repo's menu and an Explorer double-click via
# run-ci-dotnet.bat invoke it that way); consumer repos ship a same-named
# run-ci-dotnet.sh shim that sets the target and execs this. .NET is a
# single linear pipeline, so unlike the bash root there are no separate
# underscored sub-runners to orchestrate - this script is both the entry
# and the pipeline.
#
# Single source of truth: the report and gate stages call the very same
# PowerShell scripts the composite actions invoke
# (.github/actions/dotnet-coverage-report/Invoke-CoverageReport.ps1 and
# .github/actions/assert-coverage-threshold/Assert-CoverageThreshold.ps1),
# so a local pass and a CI pass are computed by identical logic and
# cannot drift.
#
# Stage order mirrors CI's distinct failure surfaces: `dotnet build`
# first (compiler warnings/errors on their own), then `dotnet test
# --no-build` (a red result is a test failure, not a build failure),
# then report, then gate. `set -e` stops at the first failing stage, so
# a build or test break surfaces before the gate runs against partial
# coverage.
#
# Inputs (all optional, via environment):
#   COMMON_DOTNET_TARGET_REPO        - repo whose solution to test;
#                                      default is Common-DotNet itself.
#   COMMON_DOTNET_SOLUTION           - explicit .sln/.slnx path; default
#                                      is auto-discovery of a single one.
#   COMMON_DOTNET_RUNSETTINGS        - .runsettings via --settings;
#                                      default <repo>/coverlet.runsettings
#                                      when present, else none.
#   COMMON_DOTNET_TEST_FILTER        - expression via --filter; default
#                                      none (every discovered test runs).
#   COMMON_DOTNET_COVERAGE_THRESHOLD - minimum line coverage %; default
#                                      is the gate script's own house
#                                      default (90) when unset.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
common_dotnet_root="$(cd "${script_dir}/.." && pwd)"
repo_root="${COMMON_DOTNET_TARGET_REPO:-${common_dotnet_root}}"

# Reuse Common-Automation's hold-window pause so an Explorer double-click
# does not flash the window shut before the result is read. The imports/
# adapter owns the cross-repo resolution, the EXIT trap, and the soft-
# dependency guard (a missing Common-Automation degrades to "no pause").
# shellcheck source=scripts/imports/_hold-window.sh
source "${script_dir}/imports/_hold-window.sh"

# Preflight the two external tools the report/gate stages need, before
# the long build, so a missing tool fails fast with an actionable
# message rather than a confusing error several stages in. pwsh runs the
# shared composite scripts; reportgenerator produces the merged report.
if ! command -v pwsh >/dev/null 2>&1; then
    echo "PowerShell (pwsh) is required to run the coverage report and gate." >&2
    echo "Install PowerShell 7+: https://aka.ms/powershell" >&2
    exit 1
fi
if ! command -v reportgenerator >/dev/null 2>&1; then
    echo "ReportGenerator is required to merge coverage and feed the gate." >&2
    echo "Install it: dotnet tool install -g dotnet-reportgenerator-globaltool" >&2
    exit 1
fi

# Resolve the solution to build/test. An explicit override always wins;
# otherwise discover a single .sln/.slnx, excluding build output so a
# stale copy under bin/obj never matches. Zero or many is an error, not
# a silent pick - matching resolve-solution-path's CI behaviour.
solution="${COMMON_DOTNET_SOLUTION:-}"
if [[ -z "${solution}" ]]; then
    # SC2312: the find|sort exit status is intentionally not checked -
    # an empty result is handled below as "zero candidates", which is
    # the same outcome a find failure would produce, so masking it is
    # the desired behaviour here.
    # shellcheck disable=SC2312
    mapfile -t candidates < <(
        find "${repo_root}" \
            \( -name '*.sln' -o -name '*.slnx' \) \
            -not -path '*/bin/*' \
            -not -path '*/obj/*' \
            -type f | sort
    )
    if [[ "${#candidates[@]}" -eq 0 ]]; then
        echo "No .sln or .slnx found under ${repo_root}." >&2
        echo "Set COMMON_DOTNET_SOLUTION to name one explicitly." >&2
        exit 1
    fi
    if [[ "${#candidates[@]}" -gt 1 ]]; then
        echo "Multiple solutions found; COMMON_DOTNET_SOLUTION is required:" >&2
        printf '  %s\n' "${candidates[@]}" >&2
        exit 1
    fi
    solution="${candidates[0]}"
fi

# Default the runsettings to the conventional repo-root file when the
# caller did not name one, so a consumer with coverage exclusions gets
# them applied locally exactly as CI does, with no extra wiring.
runsettings="${COMMON_DOTNET_RUNSETTINGS:-}"
if [[ -z "${runsettings}" && -f "${repo_root}/coverlet.runsettings" ]]; then
    runsettings="${repo_root}/coverlet.runsettings"
fi

test_filter="${COMMON_DOTNET_TEST_FILTER:-}"
threshold="${COMMON_DOTNET_COVERAGE_THRESHOLD:-}"
results_dir="${repo_root}/TestResults"

# Shared composite scripts reused verbatim so local == CI.
report_script="${common_dotnet_root}/.github/actions/dotnet-coverage-report/Invoke-CoverageReport.ps1"
gate_script="${common_dotnet_root}/.github/actions/assert-coverage-threshold/Assert-CoverageThreshold.ps1"

echo "=== dotnet build ==="
dotnet build "${solution}"

# Assemble the test args incrementally so an unsupplied optional flag is
# absent rather than passed empty (which dotnet test would reject).
test_args=(
    test "${solution}"
    --no-build
    --collect "XPlat Code Coverage"
    --results-directory "${results_dir}"
)
if [[ -n "${runsettings}" ]]; then
    if [[ ! -f "${runsettings}" ]]; then
        echo "Runsettings '${runsettings}' does not exist." >&2
        exit 1
    fi
    test_args+=(--settings "${runsettings}")
    echo "Using runsettings: ${runsettings}"
fi
if [[ -n "${test_filter}" ]]; then
    test_args+=(--filter "${test_filter}")
    echo "Using test filter: ${test_filter}"
fi

echo "=== dotnet test ==="
dotnet "${test_args[@]}"

# Report and gate run from the repo root so the shared scripts resolve
# their default relative paths (TestResults/, CoverageReport/) against
# the target repo, exactly as the composite actions do under
# GITHUB_WORKSPACE.
cd "${repo_root}"

echo "=== coverage report ==="
pwsh -NoProfile -File "${report_script}"

echo "=== coverage gate ==="
# The gate script defaults the threshold to 90 when handed an empty
# string, so passing the unset value through preserves the house
# default while still honouring an explicit override.
pwsh -NoProfile -File "${gate_script}" \
    -CoberturaPath 'CoverageReport/Cobertura.xml' \
    -ThresholdInput "${threshold}"

echo
echo "Coverage report written under ${repo_root}/CoverageReport/ (index.html)."
echo ".NET CI passed (build, test, coverage, gate)."
