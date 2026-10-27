#!/usr/bin/env bash
# Run the Playwright smoke replay headless against a local file page.
# Proves the kit's runner, config and @playwright/test install work.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
KIT=$(cd "$HERE/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export AUTO_BROWSER_HOME=$TMP
export BASE_URL="file://$HERE/"
export SMOKE_PAGE="$HERE/index.html"
export SKIP_HEALTH=1

dir=$("$KIT/bin/auto-browser" new smoke smoke --playwright)
cp "$HERE/flow.spec.ts" "$dir/flow.spec.ts"
"$KIT/bin/auto-browser" run "$dir"
jq -e '.result == "PASS"' "$dir/last-run/result.json" >/dev/null
[[ -s "$dir/last-run/greeted.png" ]]
echo "smoke: PASS"
