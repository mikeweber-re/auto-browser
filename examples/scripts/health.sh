#!/usr/bin/env bash
# Is the stack ready? Exit 0 yes, non-zero no (reason on stderr).
# Read-only: never start anything here. That is up.sh's job.
set -uo pipefail
FAILED=()
check() { curl -s -o /dev/null --max-time 3 "$2" || FAILED+=("$1 ($2)"); }

check "app" "${BASE_URL:-http://localhost:3000}"
# Add a check per dependency the run needs: database, mail catcher, worker.
# For a container: `docker compose ps -q <service>` returning empty means down.

(( ${#FAILED[@]} == 0 )) && exit 0
printf 'not reachable: %s\n' "${FAILED[*]}" >&2
exit 1
