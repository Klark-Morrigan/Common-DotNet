# DotNet-Common

Shared .NET CI building blocks for SynergyOps repositories. Mirrors the
role `Infrastructure-Common` plays for PowerShell modules: a single
source of truth for reusable GitHub Actions workflows (and, later,
MSBuild props, analyzer rulesets, base test SDKs) that every SynergyOps
.NET repo consumes by `uses:` reference pinned to a commit SHA.

## Index
- [Status](#status)
- [Self-test sample](#self-test-sample)
- [Implementation docs](#implementation-docs)

## Status
Bootstrap phase. The reusable `ci-dotnet.yml` workflow is being built up
step-by-step per the plan under `docs/dev/implementation/`. No tagged
release exists yet; consumers should not pin to this repo until the
first release lands.

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
