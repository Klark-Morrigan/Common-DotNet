#!/usr/bin/env bash
# Resolves the Common-Automation repo root - the one place this repo's
# imports/ adapters learn where the sibling repo lives. Guarded so
# re-sourcing resolves once and a caller that already set
# common_automation_root keeps its value; COMMON_AUTOMATION_ROOT overrides the
# sibling-checkout default. Resolves the WORKSPACE root (three levels up:
# scripts/imports -> scripts -> repo root -> c:\a_Code) and appends the
# sibling name WITHOUT cd-ing into it, so a missing Common-Automation never
# aborts the caller under `set -e` - the adapter guards existence (the import
# is a soft dependency). The plain assignment observes the cd's exit status
# rather than masking it (shellcheck SC2312).
if [[ -z "${common_automation_root:-}" ]]; then
    # shellcheck disable=SC2034  # consumed by the adapter shims that source this
    common_automation_root="${COMMON_AUTOMATION_ROOT:-$(cd "${BASH_SOURCE[0]%/*}/../../.." && pwd)/Common-Automation}"
fi
