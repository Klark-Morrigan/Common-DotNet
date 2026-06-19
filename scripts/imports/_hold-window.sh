#!/usr/bin/env bash
# Cross-repo adapter: imports Common-Automation's hold-window pause
# (scripts/_hold-window.sh) and arms it on EXIT, so an Explorer double-click
# does not flash the window shut before the result is read - the same UX the
# bash/yaml runners give. Soft dependency: when the Common-Automation sibling
# is absent the pause is silently skipped (no source, no trap) rather than
# failing. See _common-automation-root.sh for root resolution.
# shellcheck source=scripts/imports/_common-automation-root.sh
source "${BASH_SOURCE[0]%/*}/_common-automation-root.sh"
hold_window="${common_automation_root}/scripts/_hold-window.sh"
if [[ -f "${hold_window}" ]]; then
    # shellcheck source=/dev/null
    source "${hold_window}"
    trap hold_window_open EXIT
fi
