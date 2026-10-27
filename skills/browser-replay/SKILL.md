---
name: browser-replay
description: Replay a saved browser test before driving the browser by hand, and save hand-driven tests as replayable scripts when the flow will likely be tested again (leaning toward saving, asking when unsure). Covers visual checks, end-to-end and workflow tests, QA passes, and pr-proof-test runs. Replays are agent-browser shell scripts or Playwright specs, grouped by a key the user picks (a ticket, a feature, a flow); for a new replay it recommends a kind and lets the user choose. Use whenever you are about to drive a browser to test or verify a flow, when the user asks to rerun, replay, or save a test or flow, asks "do we have a script for this", or invokes /browser-replay. When a replay breaks, it heals UI drift and reports real bugs.
---

# browser-replay

Driving a browser by hand costs a snapshot and a judgment call per step. Do it
once, write down the steps that worked, and the next run is one command with
no snapshots.

The loop, every time a browser test comes up:

1. **Look** for a saved replay of this flow. Always.
2. **Replay** it if there is one. Pass means done.
3. **Record** a step log while driving by hand if there isn't one. Always.
   It's cheap.
4. **Decide** whether the flow is worth a script. Lean yes; ask when unsure.
5. **Save** the log as a script, if yes.
6. **Prove** the script passes on a clean run before calling it saved.

Looking and logging cost almost nothing. Turning a log into a script costs
real time on the first run, so step 4 exists to skip it for true one-offs.

## The helper and where things live

Every command below goes through the `auto-browser` helper. It is on the Bash
PATH while this plugin is enabled. If it isn't found, call it by full path:
`${CLAUDE_PLUGIN_ROOT}/bin/auto-browser`.

Storage root: `auto-browser home`. It is `$AUTO_BROWSER_HOME` when set, else
`<git repo root>/.auto-browser/`, else `~/.auto-browser/`. Inside it:

```
<home>/<key>/replays/<flow>/       run.sh or flow.spec.ts, replay.json, last-run/
<home>/<key>/scratch/              step logs: replay-<flow>.log
<home>/<key>/pr-proof/<date>/      pr-proof runs (see the pr-proof skill)
```

`<key>` groups related work: a ticket ID, a feature name, a branch name.
The user picks it. If they haven't, suggest the current branch name and ask
once. Keys and flows use letters, digits, `.`, `_` and `-` only.

The app under test is described by `auto-browser.json` at the repo root (base
URL, health, start and login scripts, test users, notes). `auto-browser config`
prints it. If it exits 3, there is no config: offer to copy
`${CLAUDE_PLUGIN_ROOT}/examples/auto-browser.json` into the repo and fill it in
with the user. Don't guess a port or a login.

## Arguments

- `--playwright` / `--agent-browser`: pick the script kind for a new replay
  and skip the question in **Choose the kind** below.
- `--headed` / `--headless`: pick the browser mode. With neither, ask with
  AskUserQuestion before running or recording anything: headed (watch it, but
  the window can steal focus) or headless (out of sight, no focus steal). Ask
  once per task. Headed means `AB_HEADED=1` on replays and `--headed` on
  hand-driven agent-browser; headless means leaving both off.
- `<flow>`: optional kebab-case flow name (`create-listing`,
  `checkout-as-guest`). Otherwise derive it from what's being tested.

## Choose the kind

An existing replay runs as whatever kind it already is. Converting one is a
separate job, done only when the user asks.

For a **new** replay, with no flag given, recommend a kind and let the user
choose before recording. Use AskUserQuestion, with the recommended option first
and labelled "(Recommended)", and a one-line reason drawn from the list below.

**Recommend Playwright when the flow is:**
- form-heavy: radios, pickers, a signature canvas, many fields. Playwright's
  role and label locators handle these without the JavaScript evals
  agent-browser needs.
- sensitive to viewport: a docked footer or a sticky bar that can cover
  fields. Playwright runs at a fixed viewport and fails loudly when something
  covers the target.
- stubbing network calls (`page.route`), or needing a full trace (DOM,
  network and console per step) when it fails.
- expected to run often, or to move into the project's e2e suite later.

**Recommend agent-browser when the flow is:**
- short, or a quick check that might never be run again.
- still changing, and likely to need healing, since agent-browser leaves the
  browser open at the failure so a session can take over.
- mostly visual (screenshots to look at) rather than assertions.

Tradeoffs to mention when they matter:
- A Playwright spec is about twice the lines of the same `run.sh`.
- Playwright closes the browser on failure, so there's no live takeover.
- Both use the same login script, so two runs at once can race if login
  depends on something shared, like the newest email in an inbox.

Record the choice as `kind` in `replay.json`.

## 1. Look

```bash
auto-browser list            # every key
auto-browser list <key>      # one key
```

Match on flow name and description. Replays from other keys are fair game to
**run**: flows outlive tickets. **Read the script before running it.** It's
code, and someone else may have written it.

To change a replay from another key, copy its directory into this key's
`replays/` first and add a `history` entry that says where it came from.

## 2. Replay

```bash
auto-browser run <replay-dir>               # either kind
AB_HEADED=1 auto-browser run <replay-dir>   # headed
```

Run from inside the project's repo, so the config resolves. The runner does
its own health check, login and base URL lookup.

- **Exit 0**: pass. Report it with the path to `last-run/`. If the test is a
  visual check, look at the screenshots it took. Don't drive the browser again.
- **Exit 2**: a dependency is missing (agent-browser, `@playwright/test`, or
  a browser). Show the message and **ask before installing** anything.
- **Exit 3**: no project config. See above.
- **Anything else**: go to **When a replay fails** below.

A replay that passes but no longer covers what's being tested (the feature
grew a new step) is out of date. Extend it by recording just the new steps
(section 3), then re-prove it.

## 3. Record

Drive the flow as normal (`agent-browser skills get core` first, so you use
the installed version's commands, not ones from memory). While you do, keep a
step log in `<home>/<key>/scratch/replay-<flow>.log` with one line per action
that moved the flow forward. Write the **stable** form of each command, not
the one you ran:

- **No `@eN` refs in a script.** They're only valid for one snapshot. Use the
  ref live, then write down a locator that survives a reload, best first:
  `find testid`, `find role ... --name`, `find label`, `find text`, then CSS.
  To learn a ref's stable handle: `agent-browser get attr @e5 data-testid`,
  or read its role and name off the snapshot.
- **Happy path only.** Drop dead ends, retries, exploratory snapshots, and
  anything you did to find your way.
- **Every page change gets a wait**: `wait --text`, `wait --url`, or
  `wait --load networkidle`. Never a bare `wait 2000`.
- **Every check the test cares about becomes an `expect_*` line.** A script
  with no assertions only proves nothing crashed. What you looked at in a
  snapshot to decide "this works" is what the assertion checks.
- **Visual checks get a `shot <name>`** at the state a human would look at.
- **No secrets in scripts.** Log in through `login` (the project's login
  script) or an `agent-browser auth` profile name. Never inline a password or
  token.
- **Unique test data uses `$RUN_ID`** (`test+$RUN_ID@example.com`) so reruns
  don't collide with the last run's records.

## 4. Decide

Lean toward saving. A script nobody reruns costs a few minutes once; a flow
that should have been saved costs a full hand-driven run every time it
comes back.

**Save without asking** when any of these hold:

- it's a `pr-proof-test` run, or the acceptance-criteria flow for this work
- this flow has been driven by hand before (a `scratch/replay-*.log` exists
  for it, or it came up earlier in this session)
- the user asked to save, replay, or rerun it
- it has more than a few steps, a login, or a form: anything tedious to redo

**Skip without asking** only when it's plainly a one-off: a single page load
to read a value, a quick look at something you're about to change again, or a
throwaway prototype.

**Anything else: ask**, in one line at the end of the test report:
"Save this as a replay (`<flow>`)?" A yes means save now while the step log
is fresh. A no leaves the log in `scratch/` in case it's wanted later.

## 5. Save

```bash
auto-browser new <key> <flow>                # agent-browser run.sh
auto-browser new <key> <flow> --playwright   # Playwright flow.spec.ts
```

It prints the new directory, with the template and a starter `replay.json`.
Fill in the `__PLACEHOLDERS__`, then turn the step log into the body: one
`step "..."` (or `test.step`) per user-visible action. Delete the login step
if the project has no `scripts.login`; follow the config's `notes` instead.

Helpers `lib.sh` gives `run.sh`:

| Helper | Does |
| --- | --- |
| `ab <args>` | `agent-browser` bound to this run's session and throwaway profile |
| `step "<name>"` | labels what follows; failures report this name |
| `login [email]` | sets session cookies from the project's login script, opens the app |
| `expect_text`, `expect_url` | wait for text / a URL glob, fail on timeout |
| `expect_visible`, `expect_hidden` | selector visibility |
| `expect_contains <sel> <substr>` | element text contains a substring |
| `shot <name>` | screenshot to `last-run/<name>.png` |
| `pass` | last line: records PASS and closes the browser |

Fill in `replay.json`:

```json
{
  "flow": "create-listing",
  "key": "feature-listings",
  "kind": "agent-browser",
  "description": "Create a listing and see it on the dashboard",
  "covers": ["listings page loads", "new listing saves", "listing appears on dashboard"],
  "created": "2026-01-15",
  "history": [{ "date": "2026-01-15", "change": "recorded" }]
}
```

`kind` is `agent-browser` or `playwright`. `covers` is the list of assertions
in plain words. It's what a later session reads to decide whether this replay
answers its question. `last-run/` is machine-written. Never edit it by hand.

### Playwright

Same flow, `flow.spec.ts` instead of `run.sh`: `test.step` per step,
`getByRole` / `getByLabel` / `getByTestId` locators, `expect(...)` assertions,
`page.screenshot({ path: ... })` into `last-run/` for visual checks.

The runner uses the project's own `@playwright/test` when the repo has one,
else the copy installed with this plugin. It runs Playwright's bundled
Chromium by default; `AUTO_BROWSER_PW_CHANNEL=chrome` uses the installed
Google Chrome instead. If a browser is missing, show the error and **ask
before downloading** one (`npx playwright install chromium`, about 150 MB).

The spec stays in the storage root. Moving it into the project's own e2e suite
is a repo change, so suggest it and let the user decide.

## 6. Prove

Run the saved script once, start to finish, in a fresh session. It isn't saved
until that passes. If it can't be made to pass, say so and leave it as the
step log in `scratch/`, not as a broken script in `replays/`.

## When a replay fails

An agent-browser replay prints the failing step, then leaves the browser
**open** at that state, with `FAIL.png`, `FAIL.snapshot.txt`, `FAIL.url.txt`,
and `FAIL.errors.txt` in `last-run/`. Playwright leaves a trace and
screenshot in `last-run/` instead (`npx playwright show-trace <zip>` to read
it).

Read those, then decide which one this is:

- **Bug**: the app does the wrong thing. A save that errors, a missing
  record, a console error, a page that crashes. **Report it as a test failure.
  Don't edit the script to make it pass.** A replay that bends to fit a bug is
  worse than no replay.
- **Drift**: the app still does the right thing, but the script can't find
  its way. A renamed test id, a moved button, changed copy, a new
  confirmation dialog. Heal it:
  1. Take over the open session
     (`agent-browser --session <name> snapshot -i`) and finish the flow by
     hand from the failing step. For Playwright, drive the same steps with
     agent-browser.
  2. Patch only the steps that drifted, using the rules in section 3.
  3. Rerun the whole script to green.
  4. Add a `history` entry: the date, which step, what changed, and "drift".
  5. Report it as a pass with the heal noted, so the user knows the UI changed.

**Can't tell which?** Treat it as a bug and ask. Healing a real regression
hides it.

## Rules

- **Replay before recording.** Driving by hand when a passing replay exists
  wastes the whole point.
- **Always keep the step log**, even if the flow probably won't be saved.
  Rebuilding the steps afterward costs more than logging them as you go.
- **One flow per directory.** Two flows that share a login are still two
  replays.
- **Scripts only drive local dev** (the config's `baseUrl`). Pointing one at
  staging or production is the user's call, every time.
- **Never drive the user's personal browser profile.** Replays use a throwaway
  profile per run. Logged-in state comes from the project's login script, an
  `agent-browser auth` profile, or a saved `--state` file, never from the
  user's everyday browser.
- **Diagnostics, not driving.** If chrome-devtools-mcp is set up, use it for
  performance, network and console checks, never to drive the page.
- **Replays don't replace pr-proof evidence.** When `pr-proof-test` runs, it
  can use a replay to drive the flow, but it still records its own
  per-criterion results and screenshots in its own manifest.
- **Close what you open.** Close every agent-browser session you started when
  you're done with it (`agent-browser --session <name> close`), including ones
  left open by a failed replay once you've finished healing or reporting.
