# Problem Statement - Shared .NET CI and Coverage Analysis

## Index
- [Current State](#current-state)
- [Problem to Solve](#problem-to-solve)
- [Why This Repo](#why-this-repo)
- [Scope](#scope)
- [Out of Scope](#out-of-scope)
- [Constraints](#constraints)
- [Risks](#risks)
- [Done Criteria](#done-criteria)

## Current State
- SynergyOps.TaskManager and SynergyOps.Suite are the only .NET repos so far
  and neither has a `.github/` folder; .NET CI is greenfield across the org.
- Infrastructure repositories share CI via reusable workflows published by
  `PowerShell-Common` (`ci-powershell.yml`, `ci-powershell-docker-host.yml`,
  `ci-powershell-docker-target.yml`, `tag.yml`, `publish.yml`) and consumed
  with `uses:`. The pattern is proven; it just does not cover .NET.
- CI executes on self-hosted runners provisioned via
  `Infrastructure-GitHubRunners`.

## Problem to Solve
- Provide a single source of truth for .NET CI used by all SynergyOps .NET
  repos, covering: restore, build, test, coverage collection, coverage report
  generation, and coverage threshold enforcement.
- Make adoption a one-line `uses:` reference in each consumer repo with a
  small set of inputs (target framework, solution path, coverage threshold,
  runner label).
- Pin by commit SHA to avoid supply-chain risk on self-hosted runners that
  have access to internal networks.

## Why This Repo
- `PowerShell-Common`'s de facto scope is PowerShell module CI; its
  workflows are named `ci-powershell-*` and every consumer is a PS module.
  Adding .NET workflows there would stretch its purpose and weaken cohesion.
- `Common-DotNet` mirrors the `PowerShell-Common` naming so each shared
  repo owns one stack's conventions.
- It also leaves room to grow beyond workflows: shared MSBuild
  `Directory.Build.props`, analyzer rulesets, a base test SDK, and similar
  artifacts that do not fit a workflow-only repo.

## Scope
- Bootstrap this repository with the standard layout (`README.md`,
  `.gitignore`, `docs/dev/implementation/`, `.github/workflows/`).
- Author an initial reusable workflow `ci-dotnet.yml` (`on: workflow_call`)
  that performs: clean workspace, restore, build, test, coverage collection
  via Coverlet (collector form), report generation via ReportGenerator,
  coverage threshold gate, and artifact upload.
- Expose inputs: solution path, target framework, coverage threshold,
  runner label.
- Document inputs, secrets, runner requirements, and the SHA-pinning
  expectation for consumers in this repo's `README.md`.
- A reference commit SHA on `master` is identified as the pin target
  consumers should adopt. Tagged releases are deferred until this repo
  ships production .NET code that needs versioned artifacts; for
  workflow- and composite-action-only content, SHA pinning is the
  recommended supply-chain posture (tags are mutable, SHAs are not).

## Out of Scope
- Consumer wiring in SynergyOps.TaskManager and SynergyOps.Suite (separate
  follow-ups in each consumer repo, using the same `uses:` pattern).
- Publish / release workflows (`publish.yml`, `tag.yml` analogues) - tracked
  as a later phase once CI is stable.
- Shared MSBuild props, analyzers, or base test SDK - future work in this
  same repo.
- Coverage publishing to external services (Codecov, SonarQube); artifact
  upload only at this stage.

## Constraints
- Must run on self-hosted runners; no implicit dependency on GitHub-hosted
  images.
- Must be invokable via `uses:` with `secrets: inherit`.
- Must be pinned by SHA in consumers, not by branch.
- Coverage threshold must be an input with a sensible default; default
  follows the `>= 90%` bar already in use by SynergyOps.TaskManager v1.
- Tooling baseline (.NET SDK, ReportGenerator) is baked into the runner
  image via `Infrastructure-GitHubRunners`; the workflow asserts presence
  and fails fast with a clear message if missing.
- ASCII-only file contents; no long dashes.

## Risks
- A compromised `master` of this repo would execute on every self-hosted
  runner that consumes it. Mitigation: SHA pinning in consumers and branch
  protection on this repo.
- Self-hosted runners persist `_work/`; stale coverage artifacts from prior
  runs can poison a green build. Mitigation: explicit cleanup step at job
  start.
- Tooling drift between runner image and workflow expectations (for example,
  SDK major version) will silently break consumers. Mitigation: workflow
  asserts versions up front and fails fast with a clear message.
- Coverage threshold set too high too early blocks legitimate work; too low
  defeats the point. Mitigation: input with per-repo override.

## Done Criteria
- Repository exists with the standard layout and a `README.md` that
  documents purpose, inputs, secrets, runner requirements, and SHA-pinning
  expectations.
- `ci-dotnet.yml` is callable via `workflow_call` and produces: build,
  test, coverage report artifact, and a pass/fail coverage gate.
- A reference commit SHA on `master` is identified for consumers to
  pin to.
- A dry-run consumer (a minimal sample workflow in this repo or a
  documented invocation snippet) demonstrates a green end-to-end run on a
  self-hosted runner.
