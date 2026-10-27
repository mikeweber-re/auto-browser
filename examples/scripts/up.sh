#!/usr/bin/env bash
# Bring the stack up. Idempotent: safe against a running stack.
# health.sh must pass once this exits 0. Long-running processes started here
# have to outlive this script. Delete this file and set scripts.up to null if
# the project needs no start step.
set -euo pipefail
echo "TODO: start this project's stack" >&2
exit 1
