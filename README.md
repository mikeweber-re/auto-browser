# auto-browser

A Claude Code plugin for testing web UIs in a real browser. It gives Claude
six skills:

| Skill | What it does |
| --- | --- |
| `browser-replay` | Before driving a browser by hand, looks for a saved test and replays it. After a hand-driven test, saves the steps as a replay. Heals a replay when the UI drifts, and reports a real bug as a failure. |
| `browser-semi-auto` | A step-through session: Claude drives a visible browser one step at a time and only when you say go. You watch, change values, or take over. |
| `pr-proof` | Proves a PR works: tests each acceptance criterion, screenshots it, writes a dated proof document. |
| `pr-proof-test` | The test stage of `pr-proof`: criteria, browser run, pass or fail per criterion. |
| `pr-proof-shots` | Extra or replacement screenshots for a proof, or just shots of a page. |
| `pr-proof-publish` | Prints the proof. Posts it to your tracker or PR only after you say yes. |

Skills show up as `/auto-browser:<skill>`, and Claude also picks them up on its
own when a task fits ("test this flow", "prove this PR works").

## Requirements

- Claude Code
- Node.js 18 or newer, and npm
- `bash`, `jq`, `curl`, `git` (macOS and Linux both work)
- [agent-browser](https://github.com/vercel-labs/agent-browser), the browser
  CLI the skills drive. See Install.

## Install

1. **agent-browser** (once per machine). Install it globally so it is on your
   PATH, then download its browser:

   ```bash
   npm install -g agent-browser
   agent-browser install            # Linux: agent-browser install --with-deps
   ```

   agent-browser ships its own Claude Code skill with the command reference.
   The skills here load it on demand with `agent-browser skills get core`, so
   it always matches your installed version. You don't need to install that
   skill separately.

2. **The plugin.** Get a copy any way you like: `git clone` this repo (best if
   you want updates or to send PRs), or unzip a shared `auto-browser.zip`, or
   copy the folder. Then install its packages and add it as a local
   marketplace:

   ```bash
   git clone https://github.com/mikeweber-re/auto-browser.git ~/auto-browser     # or unzip / copy to ~/auto-browser
   cd ~/auto-browser
   npm install
   npm run setup:playwright         # optional: Playwright's Chromium, about 150 MB
   claude plugin marketplace add ~/auto-browser
   claude plugin install auto-browser@auto-browser
   ```

   A plugin added from a local path loads in place, so `git pull` plus
   `/reload-plugins` picks up updates.

   With npm 11 or newer, `npm install` may hold back agent-browser's install
   script. That only matters if you use this local copy instead of the global
   one; approve it with `npm install-scripts approve agent-browser`.

3. **Check it.** In a Claude Code session: `/auto-browser:browser-replay`
   should be listed. From a shell, `npm run smoke` runs a headless Playwright
   test against a local page and prints `smoke: PASS`. Add
   `AUTO_BROWSER_PW_CHANNEL=chrome` to use your installed Chrome instead of
   Playwright's Chromium.

## Set up a project

The skills never guess a URL, a port, or a login. They read
`auto-browser.json` at the root of the repo under test:

```bash
cp ~/auto-browser/examples/auto-browser.json <your repo>/
mkdir -p <your repo>/scripts/auto-browser
cp ~/auto-browser/examples/scripts/*.sh <your repo>/scripts/auto-browser/
```

Then fill them in:

```json
{
  "baseUrl": "http://localhost:3000",
  "scripts": {
    "health": "scripts/auto-browser/health.sh",
    "up": null,
    "login": "scripts/auto-browser/login.sh"
  },
  "login": {
    "defaultUser": "test-user@example.com",
    "roles": { "admin": "test-admin@example.com" }
  },
  "viewport": "1440x900",
  "notes": "How the stack comes up, manual login steps, seeded data, feature flags."
}
```

| Field | Meaning |
| --- | --- |
| `baseUrl` | Where local dev runs. `BASE_URL` in the environment overrides it. |
| `scripts.health` | Exit 0 when the app and what it needs are up; reason on stderr otherwise. Read-only. Without it, the kit just checks `baseUrl` answers. |
| `scripts.up` | Optional. Starts the stack. Claude only runs it after asking. |
| `scripts.login` | Optional. `login.sh [email] --cookies` prints a JSON array of `{name, value}` session cookies and nothing else. It must not open a browser. |
| `login.defaultUser`, `login.roles` | Test accounts, so "as an admin" resolves without asking. |
| `viewport` | Screenshot size for proofs. |
| `notes` | Anything else an agent needs: how to log in through the form if there is no login script, test data, flags. |

Script paths are relative to the config file. Each script gets `BASE_URL` in
its environment.

**Login without a script.** If your app's login can only happen through the
UI, leave `scripts.login` null and describe the steps in `notes`. You can also
save a login once with `agent-browser auth save <name>` or a state file
(`--state auth.json`) and name it in `notes`. Never put a password in the
config or in a replay.

## Where things are stored

Replays, step logs and proof runs live under one root:

| Setting | Root |
| --- | --- |
| `AUTO_BROWSER_HOME` set | that directory |
| inside a git repo | `<repo root>/.auto-browser/` |
| anywhere else | `~/.auto-browser/` |

```
<root>/<key>/replays/<flow>/      run.sh or flow.spec.ts, replay.json, last-run/
<root>/<key>/scratch/             step logs
<root>/<key>/pr-proof/<date>/     run.json, shots/, proof.md
```

`<key>` groups related work: a ticket ID, a feature, a branch name. You pick
it; Claude suggests the branch name.

Add `.auto-browser/` to the repo's `.gitignore` if you don't want replays and
proofs committed. Commit them if you want the team to share replays. Each git
worktree gets its own `.auto-browser/`; set `AUTO_BROWSER_HOME` to share one
store across worktrees.

What stays local to each machine, even when the store is committed:

- **Browser profiles** never go in the store. Each replay run gets a throwaway
  profile under `${XDG_CACHE_HOME:-~/.cache}/auto-browser/profiles/`. It is
  deleted when the run passes, kept after a failure so the open browser can
  be taken over, and swept after a day.
- **Run output** (`last-run/`) is ignored by a `.gitignore` the helper writes
  at the store root the first time it uses it.

## The `auto-browser` helper

The skills call a small CLI in `bin/`. Claude Code puts it on the Bash PATH
while the plugin is enabled. To use it from your own terminal, add the
plugin's `bin/` to your PATH.

```
auto-browser home                  storage root
auto-browser config                project config, resolved
auto-browser health                is the app up?
auto-browser up                    start it (the project's up script)
auto-browser login [email]         session cookies as JSON
auto-browser list [key]            saved replays
auto-browser new <key> <flow> [--playwright]
auto-browser run <replay-dir>      run a replay of either kind
auto-browser proof-dir <key> [--new]
```

Exit codes: 0 ok, 1 failure, 2 a dependency is missing, 3 no project config.

## Usage

### browser-replay

Ask Claude to test a flow ("check that guest checkout still works"). It looks
for a replay first and runs it. If there is none, it drives the browser by
hand, keeps a step log, and saves the log as a replay when the flow is worth
rerunning (it leans toward yes and asks when unsure).

```bash
auto-browser run .auto-browser/checkout/replays/guest-checkout          # headless
AB_HEADED=1 auto-browser run .auto-browser/checkout/replays/guest-checkout
```

Flags: `--playwright` or `--agent-browser` picks the kind for a new replay;
`--headed` or `--headless` picks the mode (otherwise Claude asks once).

When a replay fails, Claude reads the failure artifacts and decides: a **bug**
(the app is wrong) is reported as a failure and the script is left alone;
**drift** (the app is right but a button moved or copy changed) gets healed,
rerun to green, and noted in the replay's history.

### browser-semi-auto

```
/auto-browser:browser-semi-auto checkout-as-guest --width 1280
/auto-browser:browser-semi-auto --setup
```

Claude shows a numbered plan, then waits. Say `n` for the next step, `n 3`
for three, `run to 7`, `skip`, `my turn` to act yourself, `stop` to end.
`--setup` reads the branch diff, runs the setup steps by itself, and stops
only at the steps that exercise what changed.

### pr-proof

```
/auto-browser:pr-proof
```

1. Claude collects acceptance criteria from a spec file you point at, ticket
   text you paste, or (as a fallback) the PR diff, and asks you to confirm
   them.
2. It runs each criterion in the browser and screenshots the proof.
3. It writes `proof.md` with the verdict, environment, criteria table,
   findings, and what wasn't covered.
4. It prints the proof. Posting to Linear, Jira, a GitHub PR comment or
   anything else is optional. It goes through whatever connector or CLI you
   have, only after you say yes to the exact post, and never twice for one
   run. A run with any failed criterion is never posted.

Run a stage alone when that's all you need: `/auto-browser:pr-proof-shots`
for screenshots, `/auto-browser:pr-proof-test` for a pass/fail run.

## Playwright or agent-browser?

Replays come in two kinds. Claude recommends one for each new replay and lets
you choose.

| | agent-browser `run.sh` | Playwright `flow.spec.ts` |
| --- | --- | --- |
| Best for | short checks, flows still changing, visual checks | form-heavy flows, regression tests run often |
| Size | about half the lines | about twice the lines |
| On failure | browser stays open at the failing step, so Claude can take over and heal | browser closes; you get a trace, screenshot and report |
| Locators | `find role/label/testid` commands | `getByRole`, `getByLabel`, `getByTestId` |
| Network stubbing | no | yes (`page.route`) |
| Viewport | browser default, or `WIDTH`/`HEIGHT` | fixed 1280x720, or `WIDTH`/`HEIGHT` |
| Moves into your e2e suite | needs a rewrite | mostly as is |

The Playwright runner uses your project's own `@playwright/test` if the repo
has one, else the copy installed with the plugin. It runs Playwright's
Chromium by default. Set `AUTO_BROWSER_PW_CHANNEL=chrome` to use installed
Chrome and skip the download.

## Diagnostics with chrome-devtools-mcp (optional)

[chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)
gives Claude Chrome DevTools: performance traces, network requests, console
errors, and CPU or network throttling. It is not bundled with this plugin.
Add it yourself if you want it:

```bash
claude mcp add chrome-devtools --scope user npx chrome-devtools-mcp@latest
```

The split: **agent-browser drives** (navigate, click, fill, screenshot);
**chrome-devtools only diagnoses**. The skills follow that rule when it is
set up.

### One browser for both

To trace or inspect the exact page agent-browser is driving, start one Chrome
with a debugging port and a throwaway profile, then point both tools at it.
Any free port works; this uses 9333.

```bash
# macOS
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9333 --user-data-dir="$(mktemp -d)" &
# Linux
google-chrome --remote-debugging-port=9333 --user-data-dir="$(mktemp -d)" &

agent-browser --cdp 9333 open http://localhost:3000
claude mcp add --scope user chrome-devtools-shared -- \
  npx chrome-devtools-mcp@latest --browser-url=http://127.0.0.1:9333
```

Always use a separate `--user-data-dir`. Chrome refuses remote debugging on
your everyday profile, and you don't want an agent in it anyway. Chrome for
Testing works the same way.

## Safety rules the skills follow

- Never drive your personal browser profile. Every session gets its own
  throwaway profile; logged-in state comes from your login script, an
  `agent-browser auth` profile, or a state file.
- Replays only drive local dev. Pointing one at staging or production is your
  call, every time.
- Nothing is posted anywhere without your explicit yes to that exact post.
- Headed or headless: Claude asks once per task unless you said.
- Claude closes the browser sessions it opens.

## Sharing and contributing

- `npm run pack` writes `auto-browser.zip` (committed files only, no
  `node_modules`) for sharing as a file.
- Changes go through pull requests on this repo. Keep `npm run smoke` passing
  and run `bash -n` on any script you touch.

## Layout

```
.claude-plugin/plugin.json        plugin manifest
.claude-plugin/marketplace.json   lets this repo act as its own marketplace
bin/auto-browser                  the helper CLI
skills/<name>/SKILL.md            the six skills
skills/browser-replay/lib.sh      helpers for run.sh replays
skills/browser-replay/template/   new-replay templates
skills/browser-replay/playwright.config.cjs
skills/pr-proof/contract.md       shared rules for the pr-proof family
examples/                         project config, script stubs, smoke test
```
