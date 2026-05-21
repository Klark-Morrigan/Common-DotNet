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
- [Composite actions](#composite-actions)
- [Self-test sample](#self-test-sample)
- [Implementation docs](#implementation-docs)

## Status
Bootstrap phase. The reusable `ci-dotnet.yml` workflow is being built up
step-by-step per the plan under `docs/dev/implementation/`. No tagged
release exists yet; consumers should not pin to this repo until the
first release lands.

## Workflows

### ci-dotnet.yml
Reusable workflow (`on: workflow_call`) that performs the .NET CI
preflight, restore, and build. Test execution, coverage, and the
threshold gate are added in subsequent plan steps.

**Inputs:**
- `solution-path` (string, required) - path to the `.sln`/`.slnx` to
  restore and build, relative to the consumer repo root.
- `runs-on-label` (string, optional, default `self-hosted`) - extra
  runner label combined with `self-hosted` to target a specific
  self-hosted runner pool.

**Orchestration model:** the workflow YAML is an orchestrator. Each
step delegates to a dedicated composite action under
`.github/actions/`, so per-step logic stays testable in isolation and
the workflow stays readable. Composite actions colocate their
PowerShell script next to `action.yml` and invoke it via
`${{ github.action_path }}`, which means action body and script ship
together at the same SHA - no manual checkout of this repo into the
consumer's workspace is required.

**Job steps (in order):**
1. `actions/checkout@v5` - check out the consumer repo.
2. [`clear-workspace-artifacts`](.github/actions/clear-workspace-artifacts/) -
   removes `bin/`, `obj/`, `TestResults/`, `CoverageReport/` anywhere
   under the workspace. Required because self-hosted runners persist
   `_work/` across jobs and stale output from a prior run can poison
   the build.
3. [`assert-dotnet-sdk`](.github/actions/assert-dotnet-sdk/) - runs
   `dotnet --version` and fails fast with a message pointing at
   `Infrastructure-GitHubRunners` if the SDK is missing, instead of
   letting `dotnet restore` produce a confusing error mid-job.
4. [`dotnet-restore`](.github/actions/dotnet-restore/) - `dotnet
   restore <solution-path>`.
5. [`dotnet-build`](.github/actions/dotnet-build/) - `dotnet build
   <solution-path> --no-restore`.

Cleanup runs **before** the SDK assertion so that a prior run's
artifacts do not survive into a job that aborts at the assertion;
the assertion in turn runs **before** restore so SDK absence is
diagnosed at the right step.

**Why each step is duplicated with `if:` guards:** local action
references (`uses: ./.github/actions/<name>`) only resolve when this
repo is the job's checked-out repo. For consumer invocations via
`workflow_call`, the consumer's checkout is in the workspace, so each
step has a sibling using the remote reference
(`VitaliiAndreev/DotNet-Common/.github/actions/<name>@master`).
Exactly one of each pair runs per job. This mirrors
`Infrastructure-Common`'s reusable workflow pattern.

**Runner requirements:** the .NET SDK is provisioned by
`Infrastructure-GitHubRunners` and baked into the runner image.
Workflow consumers do not install it ad hoc.

## Composite actions
The reusable workflow above is the recommended entry point, but each
composite action is also directly consumable for repos that want
finer control or atomic per-action SHA pinning:

- [`clear-workspace-artifacts`](.github/actions/clear-workspace-artifacts/)
- [`assert-dotnet-sdk`](.github/actions/assert-dotnet-sdk/)
- [`dotnet-restore`](.github/actions/dotnet-restore/) - input:
  `solution-path`
- [`dotnet-build`](.github/actions/dotnet-build/) - input:
  `solution-path`

## Self-test sample
`tests/sample/` is a minimal .NET solution (one class library plus one
xUnit test project, targeting `net10.0`) whose only job is to give the
in-progress reusable workflow something to build, test, and measure
coverage against. It is temporary scaffolding: once this repo gains real
shared .NET code, the self-test workflow is retargeted at that real
code and the sample is removed (see Step 9 in
[plan.md](docs/dev/implementation/2%20-%20shared%20dotnet%20ci/plan.md)).

Local validation:
```
dotnet build tests/sample/Sample.sln
dotnet test  tests/sample/Sample.sln
```

## Implementation docs
- [Shared .NET CI - problem](docs/dev/implementation/2%20-%20shared%20dotnet%20ci/problem.md)
- [Shared .NET CI - plan](docs/dev/implementation/2%20-%20shared%20dotnet%20ci/plan.md)
