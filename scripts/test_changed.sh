#!/bin/bash

# ============================================================================
# Run the tests when files changed vs HEAD (staged, unstaged, untracked) touch
# game code. GUT cannot select tests by changed file and the whole suite takes
# the whole suite headless, so any code change runs all of it via scripts/test.sh.
# Quiet: failures (full output) or a one-line summary.
# ============================================================================

set -euo pipefail

cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
CHANGED=()
while IFS= read -r f; do
    [[ -n "$f" && -e "$f" ]] && CHANGED+=("$f")
done < <({ git diff --name-only HEAD 2>/dev/null || true; git ls-files --others --exclude-standard; } | sort -u)

if [[ ${#CHANGED[@]} -eq 0 ]]; then echo "no changes vs HEAD: nothing to test"; exit 0; fi
if ! printf '%s\n' "${CHANGED[@]}" | grep -qE '\.(gd|tscn|tres|cfg|godot|json|cpp|h|gdextension)$|^(src|tests|scenes|gdextension)/|project\.godot|^scripts/test'; then
    echo "no game-code changes: nothing to test"; exit 0
fi

# Output is held in memory, not a temp file: no scratch files under /tmp.
if log="$(scripts/test.sh 2>&1)"; then
    grep -E '^(Tests|Passing Tests) ' <<<"$log" | tr -s ' ' | paste -sd' '
else
    tail -40 <<<"$log"
    exit 1
fi
