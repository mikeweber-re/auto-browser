# Shared helpers for agent-browser replay scripts. Sourced, never run.
#
#   source "$(auto-browser lib)"
#
# Env overrides: BASE_URL, AB_HEADED=1, AB_SESSION, RUN_ID, SKIP_HEALTH=1,
# WIDTH and HEIGHT (viewport; unset WIDTH keeps the browser default, HEIGHT
# defaults to 900).

set -Eeuo pipefail

AUTO_BROWSER_CLI=${AUTO_BROWSER_CLI:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../bin" && pwd)/auto-browser}
HERE=$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)
BASE_URL=${BASE_URL:-$("$AUTO_BROWSER_CLI" config | jq -r '.baseUrl')}
RUN_ID=${RUN_ID:-$(date +%s)}
SESSION=${AB_SESSION:-replay-$(basename "$HERE")-$RUN_ID}
OUT="$HERE/last-run"
STEP="setup"

# agent-browser from PATH, else the copy installed with the kit.
if command -v agent-browser >/dev/null 2>&1; then
  AB_BIN=agent-browser
else
  AB_BIN="$(dirname "$AUTO_BROWSER_CLI")/../node_modules/.bin/agent-browser"
  [[ -x "$AB_BIN" ]] || { echo "agent-browser not found. Run: npm install -g agent-browser && agent-browser install" >&2; exit 2; }
fi

rm -rf "$OUT"
mkdir -p "$OUT"

# A throwaway profile per run, so a replay never touches anyone's real browser profile.
ab() { "$AB_BIN" --session "$SESSION" --profile "$OUT/chrome-profile" ${AB_HEADED:+--headed} "$@"; }

step() { STEP="$*"; printf '> %s\n' "$STEP"; }

# Fail the current step with a reason. Triggers the ERR trap in the caller.
fail_with() { printf 'expected: %s\n' "$*" >&2; return 1; }

expect_text()    { ab wait --text "$1" >/dev/null || fail_with "text '$1' on page"; }
expect_url()     { ab wait --url "$1" >/dev/null || fail_with "url matching '$1'"; }
expect_visible() { [[ "$(ab is visible "$1" 2>/dev/null)" == true ]] || fail_with "'$1' visible"; }
expect_hidden()  { [[ "$(ab is visible "$1" 2>/dev/null)" != true ]] || fail_with "'$1' not visible"; }
# expect_contains <selector> <substring>
expect_contains() {
  local got
  got=$(ab get text "$1" 2>/dev/null) || fail_with "'$1' exists"
  [[ "$got" == *"$2"* ]] || fail_with "'$1' contains '$2' (got: '$got')"
}

shot() { ab screenshot "$OUT/$1.png" >/dev/null; }

# Log in with the project's login script (see auto-browser.json). Args pass
# through, e.g. an email. Sets session cookies on BASE_URL, then opens the app.
login() {
  local cookies name value
  cookies=$("$AUTO_BROWSER_CLI" login "$@")
  while IFS=$'\t' read -r name value; do
    ab cookies set "$name" "$value" --url "$BASE_URL" --sameSite Lax >/dev/null
  done < <(jq -r '.[] | [.name, .value] | @tsv' <<<"$cookies")
  ab open "$BASE_URL" >/dev/null
}

write_result() {
  jq -n --arg r "$1" --arg s "$STEP" --arg at "$(date -u +%FT%TZ)" --arg sess "$SESSION" \
    '{result: $r, step: $s, at: $at, session: $sess}' > "$OUT/result.json"
}

# On failure, leave the browser open at the failing state so an agent can take over.
on_fail() {
  local code=$?
  trap - ERR
  ab screenshot "$OUT/FAIL.png" >/dev/null 2>&1 || true
  ab snapshot -i > "$OUT/FAIL.snapshot.txt" 2>&1 || true
  ab get url > "$OUT/FAIL.url.txt" 2>&1 || true
  ab errors > "$OUT/FAIL.errors.txt" 2>&1 || true
  write_result FAIL
  printf 'FAIL at step: %s\n  artifacts: %s\n  browser left open: agent-browser --session %s snapshot -i\n' \
    "$STEP" "$OUT" "$SESSION" >&2
  exit "$code"
}
trap on_fail ERR

# Call as the script's last line.
pass() {
  write_result PASS
  ab close >/dev/null 2>&1 || true
  printf 'PASS (%s)\n' "$(basename "$HERE")"
}

if [[ -z "${SKIP_HEALTH:-}" ]]; then
  step "health check"
  "$AUTO_BROWSER_CLI" health
fi

if [[ -n "${WIDTH:-}" ]]; then
  step "viewport ${WIDTH}x${HEIGHT:-900}"
  ab set viewport "$WIDTH" "${HEIGHT:-900}" >/dev/null
fi
