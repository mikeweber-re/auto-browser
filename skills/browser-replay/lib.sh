# Shared helpers for agent-browser replay scripts. Sourced, never run.
#
#   source "$(auto-browser lib)"
#
# Env overrides: BASE_URL, AB_HEADED=1, AB_SESSION, RUN_ID, SKIP_HEALTH=1,
# WIDTH and HEIGHT (viewport; unset WIDTH keeps the browser default, HEIGHT
# defaults to 900).
# Opt-in capture, off by default:
#   AB_SHOTS=1         screenshot after each step -> last-run/steps/NN-<step>.png
#   AB_RECORD=1        video of the run -> last-run/run.webm
#   AB_RECORD=mp4      video as last-run/run.mp4 instead (for PR attachments)

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

# A throwaway browser profile per run, kept in the user's local cache and never in
# the replay store, so it can't be committed. Deleted on PASS; kept on FAIL so the
# open session can be taken over. Profiles older than a day are swept here.
PROFILES="${XDG_CACHE_HOME:-$HOME/.cache}/auto-browser/profiles"
mkdir -p "$PROFILES"
find "$PROFILES" -mindepth 1 -maxdepth 1 -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
PROFILE="$PROFILES/$SESSION"

ab() { "$AB_BIN" --session "$SESSION" --profile "$PROFILE" ${AB_HEADED:+--headed} "$@"; }

# With AB_SHOTS, each step() first shoots the state the previous step left.
SHOT_N=0
SHOT_PENDING=
slug() { tr '[:upper:]' '[:lower:]' <<<"$1" | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//' | cut -c1-40; }
step_shot() {
  SHOT_N=$((SHOT_N + 1))
  mkdir -p "$OUT/steps"
  ab screenshot "$OUT/steps/$(printf '%02d' "$SHOT_N")-$(slug "$STEP").png" >/dev/null 2>&1 || true
}
step() {
  if [[ -n "$SHOT_PENDING" ]]; then step_shot; fi
  STEP="$*"
  printf '> %s\n' "$STEP"
  if [[ -n "${SHOTS_ON:-}" ]]; then SHOT_PENDING=1; fi
  return 0
}

# With AB_RECORD, stop and save the video. Stopping keeps the page where it is,
# so a failed run stays open at the failing state.
RECORDING=
stop_recording() {
  [[ -n "$RECORDING" ]] || return 0
  RECORDING=
  if ! ab record stop >>"$OUT/record.log" 2>&1; then
    printf 'video not saved, see %s\n' "$OUT/record.log" >&2
  fi
  return 0
}

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
  stop_recording
  write_result FAIL
  printf 'FAIL at step: %s\n  artifacts: %s\n  browser left open: agent-browser --session %s snapshot -i\n' \
    "$STEP" "$OUT" "$SESSION" >&2
  exit "$code"
}
trap on_fail ERR

# Call as the script's last line.
pass() {
  if [[ -n "$SHOT_PENDING" ]]; then step_shot; fi
  stop_recording
  write_result PASS
  ab close >/dev/null 2>&1 || true
  rm -rf "$PROFILE"
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

# Needs agent-browser >= 0.41 (0.36's `record stop` failed most runs on static
# pages) and ffmpeg with libvpx/libx264 (`agent-browser doctor` checks). Starts
# on BASE_URL, before the script's first step.
if [[ -n "${AB_RECORD:-}" ]]; then
  step "start recording"
  ab record start "$OUT/run.$([[ "$AB_RECORD" == mp4 ]] && echo mp4 || echo webm)" "$BASE_URL" >>"$OUT/record.log" 2>&1
  RECORDING=1
fi

SHOTS_ON=${AB_SHOTS:+1}
