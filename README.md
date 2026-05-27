# DotNet-Common

Shared .NET CI building blocks for SynergyOps repositories. Mirrors the
role `Infrastructure-Common` plays for PowerShell modules: a single
source of truth for reusable GitHub Actions workflows (and, later,
MSBuild props, analyzer rulesets, base test SDKs) that every SynergyOps
.NET repo consumes by `uses:` reference pinned to a commit SHA.

## Index
- [Status](#status)
- [Workflows](#workflows)
  - [ci-dotnet.yml](#ci-dotnetyml)
  - [self-test.yml](#self-testyml)
- [Artifacts](#artifacts)
- [Composite actions](#composite-actions)
- [Self-test sample](#self-test-sample)
- [Branch protection](#branch-protection)
- [Implementation docs](#implementation-docs)

## Status
Bootstrap phase. The reusable `ci-dotnet.yml` workflow is being built up
step-by-step per the plan under `docs/dev/implementation/`. No tagged
release exists yet; consumers should not pin to this repo until the
first release lands.

## Workflows

### ci-dotnet.yml
Reusable workflow (`on: workflow_call`) that performs the .NET CI
preflight, restore, build, test, code coverage collection,
human-readable coverage reporting (with the report uploaded as a
build artifact), and a coverage threshold gate that fails the job
when line coverage drops below a consumer-configurable bar.

**Inputs:**
- `solution-path` (string, required) - path to the `.sln`/`.slnx` to
  restore and build, relative to the consumer repo root.
- `runs-on-label` (string, optional, default `self-hosted`) - extra
  runner label combined with `self-hosted` to target a specific
  self-hosted runner pool.
- `coverage-threshold` (number, optional, default `90`) - minimum
  acceptable line coverage as a percentage (0-100). The threshold
  gate step fails the job when the merged Cobertura report's
  `line-rate` falls below this value. Values above 100 are silently
  capped at 100; negative values are rejected.

**Orchestration model:** the workflow YAML is an orchestrator. Each
step delegates to a dedicated composite action under
`.github/actions/`, so per-step logic stays testable in isolation and
the workflow stays readable. Composite actions colocate their
PowerShell script next to `action.yml` and invoke it via
`${{ github.action_path }}`, which means action body and script ship
together at the same SHA. The workflow runs a second
`actions/checkout` of DotNet-Common into `.dotnet-common/` and
references each composite action as `./.dotnet-common/.github/actions/<name>`,
so action resolution is always against a known local path rather
than a remote ref - see [Why two checkouts](#why-two-checkouts).

**Job steps (in order):**
1. `actions/checkout@v5` - check out the consumer repo (the code
   being restored, built, tested, and measured).
2. `actions/checkout@v5` - second checkout of `DotNet-Common` itself
   into `.dotnet-common/`, used only as the source of the composite
   actions every later step references. The `ref:` is
   `github.workflow_sha` - the commit SHA of the called workflow
   file - so a consumer that pinned `uses: ...ci-dotnet.yml@<sha>`
   gets the composite actions from exactly that SHA; no master leak
   across the SHA-pinned boundary. See
   [Why two checkouts](#why-two-checkouts) below.
3. [`clear-workspace-artifacts`](.github/actions/clear-workspace-artifacts/) -
   removes `bin/`, `obj/`, `TestResults/`, `CoverageReport/` anywhere
   under the workspace. Required because self-hosted runners persist
   `_work/` across jobs and stale output from a prior run can poison
   the build.
4. [`assert-dotnet-sdk`](.github/actions/assert-dotnet-sdk/) - runs
   `dotnet --version` and fails fast with a message pointing at
   `Infrastructure-GitHubRunners` if the SDK is missing, instead of
   letting `dotnet restore` produce a confusing error mid-job.
5. [`assert-reportgenerator`](.github/actions/assert-reportgenerator/) -
   verifies the ReportGenerator global tool is on PATH and fails fast
   with the same `Infrastructure-GitHubRunners` guidance if missing.
   Grouped with the SDK assertion so every required tool is checked
   before any long-running step.
6. [`dotnet-restore`](.github/actions/dotnet-restore/) - `dotnet
   restore <solution-path>`.
7. [`dotnet-build`](.github/actions/dotnet-build/) - `dotnet build
   <solution-path> --no-restore`.
8. [`dotnet-test`](.github/actions/dotnet-test/) - `dotnet test
   <solution-path> --no-build --collect:"XPlat Code Coverage"
   --results-directory ./TestResults`. Separated from build so the
   workflow exposes two distinct failure surfaces (compile errors vs
   test failures), and so a future "build-only" mode can be added by
   gating this step on an input without disturbing the build pipeline.
   Coverage output lands at `TestResults/<guid>/coverage.cobertura.xml`
   for the report and threshold steps that follow.
9. [`dotnet-coverage-report`](.github/actions/dotnet-coverage-report/) -
   runs ReportGenerator over the Cobertura output from the test step
   and writes `CoverageReport/{index.html, Summary.txt, Cobertura.xml}`.
   The merged `Cobertura.xml` is the canonical input the threshold
   gate reads, so the gate does not need to glob `TestResults/`.
10. [`assert-coverage-threshold`](.github/actions/assert-coverage-threshold/) -
    reads `line-rate` from `CoverageReport/Cobertura.xml` and fails
    the job with a diagnostic naming both the observed value and the
    configured threshold when coverage drops below `coverage-threshold`.
    Placed before the artifact upload so the gate is the final word on
    the build; the upload step's `if: always()` guarantees reviewers
    still get the report when the gate fails - that is exactly when
    they need it most.
11. `actions/upload-artifact@v4` - uploads the entire `CoverageReport/`
    directory as a single artifact named `coverage-report`. Runs with
    `if: always()` so reviewers can still inspect partial coverage if
    the test step or the threshold gate failed.

Cleanup runs **before** the SDK assertion so that a prior run's
artifacts do not survive into a job that aborts at the assertion;
the assertion in turn runs **before** restore so SDK absence is
diagnosed at the right step.

**Why two checkouts:** the alternative (if-guarded pairs of `./` and
`<repo>@master` step references) forces GitHub Actions to resolve
the `@master` ref at job start even when the if-guard would skip the
step, so a stale `master` (or a PR-branch action that does not yet
exist on `master`) breaks the job before any step runs. A separate
checkout of DotNet-Common into `.dotnet-common/`, with every step
referencing `./.dotnet-common/.github/actions/<name>`, side-steps
the eager-resolution footgun entirely. A small side-benefit: PR-time
self-test runs now actually exercise PR changes to composite
actions, because `github.workflow_sha` resolves to the PR head when
the workflow runs on this repo.

**Runner requirements:** the .NET SDK *and* the ReportGenerator
global tool (`dotnet tool install -g dotnet-reportgenerator-globaltool`)
are provisioned by `Infrastructure-GitHubRunners` and baked into the
runner image. Workflow consumers do not install either ad hoc.

**Coverage contract:** the test step activates Coverlet's
`XPlat Code Coverage` data collector, which requires each consumer
test project to reference the `coverlet.collector` NuGet package
(currently `6.0.4` in the self-test sample). Without that
PackageReference, `dotnet test` still passes but no
`coverage.cobertura.xml` is produced and the downstream report and
threshold steps fail. Output path is
`TestResults/<guid>/coverage.cobertura.xml`, relative to the working
directory the test step runs in.

### self-test.yml
Thin wrapper that calls [`ci-dotnet.yml`](#ci-dotnetyml) against the
in-repo [self-test sample](#self-test-sample) on every `push` and
`pull_request` to `master`. Without it, regressions in the reusable
workflow (or in any of its composite actions) would land unnoticed
and surface only when a downstream consumer's CI breaks.

The wrapper invokes the reusable workflow with a repo-relative
`uses: ./.github/workflows/ci-dotnet.yml` (no `@ref`), which pins the
called workflow to the same commit as the caller - the only correct
behavior for a self-test, since the whole point is validating the
version of `ci-dotnet.yml` that ships with this commit.

See [Branch protection](#branch-protection) for the required check
configuration.

## Artifacts
The workflow uploads one artifact per job run:

- `coverage-report` - the entire `CoverageReport/` directory, which
  contains:
  - `index.html` - browsable HTML report.
  - `Summary.txt` - plain-text summary; includes the `Line coverage:`
    line the threshold gate (Step 6) parses.
  - `Cobertura.xml` - merged Cobertura across all input report files;
    the canonical input for the threshold gate.
  - Supporting CSS/JS/SVG/per-class HTML pages for the HTML report.

The upload step runs with `if: always()`, so the artifact is produced
even when the test step fails - reviewers can still inspect partial
coverage for the assemblies whose tests did run.

## Composite actions
The reusable workflow above is the recommended entry point, but each
composite action is also directly consumable for repos that want
finer control or atomic per-action SHA pinning:

- [`clear-workspace-artifacts`](.github/actions/clear-workspace-artifacts/)
- [`assert-dotnet-sdk`](.github/actions/assert-dotnet-sdk/)
- [`assert-reportgenerator`](.github/actions/assert-reportgenerator/)
- [`dotnet-restore`](.github/actions/dotnet-restore/) - input:
  `solution-path`
- [`dotnet-build`](.github/actions/dotnet-build/) - input:
  `solution-path`
- [`dotnet-test`](.github/actions/dotnet-test/) - input:
  `solution-path`; collects Coverlet coverage to
  `TestResults/<guid>/coverage.cobertura.xml`
- [`dotnet-coverage-report`](.github/actions/dotnet-coverage-report/) -
  optional inputs: `reports-glob` (default
  `TestResults/**/coverage.cobertura.xml`), `target-dir` (default
  `CoverageReport`)
- [`assert-coverage-threshold`](.github/actions/assert-coverage-threshold/) -
  optional inputs: `coverage-threshold` (default `90`),
  `cobertura-path` (default `CoverageReport/Cobertura.xml`); fails
  the step when observed line coverage is below the threshold

## Self-test sample
`tests/sample/` is a minimal .NET solution (one class library plus one
xUnit test project, targeting `net10.0`) whose only job is to give the
in-progress reusable workflow something to build, test, and measure
coverage against. It is scaffolding: once this repo gains real shared
.NET code (MSBuild props, analyzers, a base test SDK, or similar),
that code becomes the natural self-test target and the sample is
retired in favour of it.

Local validation:
```
dotnet build tests/sample/Sample.sln
dotnet test  tests/sample/Sample.sln
```

## Branch protection
The [`self-test.yml`](#self-testyml) workflow must be a required
status check on `master`. GitHub does not let workflow files declare
their own branch-protection rules, so this is configured manually
once in the repository settings:

1. Repository **Settings** -> **Branches** -> **Branch protection
   rules** -> add or edit the rule for `master`.
2. Enable **Require status checks to pass before merging**.
3. Under the status-check search box, add the job-level check
   **`Self-test (ci-dotnet) / Restore and build`**. The left half
   comes from `name:` in `self-test.yml`; the right half comes from
   the `name:` of the `build` job in `ci-dotnet.yml`. If either name
   changes, the protection rule must be re-pointed - GitHub does not
   auto-update it.
4. Enable **Require branches to be up to date before merging** so
   stale PRs cannot bypass the gate by merging against an older
   `master`.

Without this manual step the workflow still runs on every PR but a
red result is advisory only - merges are not blocked.

## Implementation docs
- [Shared .NET CI - problem](docs/dev/implementation/2%20-%20shared%20dotnet%20ci/problem.md)
- [Shared .NET CI - plan](docs/dev/implementation/2%20-%20shared%20dotnet%20ci/plan.md)
