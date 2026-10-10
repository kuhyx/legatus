#!/bin/bash

# ============================================================================
# Thin delegate to the shared gate in ~/utils.
#
# Copying the logic here is what lets one repo's idea of the rule drift from
# every other repo's, so this script only locates the shared checker and
# forwards its arguments.
# ============================================================================

set -euo pipefail

readonly SHARED_GATE="${UTILS_ROOT:-$HOME/src/utils}/scripts/check_no_binaries.sh"

main() {
	if [[ ! -x "$SHARED_GATE" ]]; then
		echo "Error: shared gate not found at $SHARED_GATE" >&2
		echo "       Clone github.com/kuhyx/utils to ~/src/utils, or set" >&2
		echo "       UTILS_ROOT to where it lives." >&2
		exit 1
	fi

	exec bash "$SHARED_GATE" "$@"
}

main "$@"
