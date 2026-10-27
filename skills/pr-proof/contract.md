# pr-proof run contract

Shared by `pr-proof`, `pr-proof-test`, `pr-proof-shots`, and
`pr-proof-publish`. Every one of those skills reads this file before it starts.

The point of the contract is that each skill runs on its own. A stage either
picks up what an earlier stage left in the manifest, or takes what it needs from
the user directly. No stage may assume it was called by the `pr-proof` skill.

`auto-browser` is on the Bash PATH while the plugin is enabled. If it isn't
found, call it by full path from the plugin's `bin/` directory.

## Locations

One directory per run:

```
<home>/<key>/pr-proof/<YYYY-MM-DD>/run.json       # the manifest
<home>/<key>/pr-proof/<YYYY-MM-DD>/shots/<id>-<slug>.png
<home>/<key>/pr-proof/<YYYY-MM-DD>/proof.md       # the writeup
```

- `<home>` is `auto-browser home`: `$AUTO_BROWSER_HOME`, else
  `<repo root>/.auto-browser/`, else `~/.auto-browser/`.
- `<key>` groups the work: a ticket ID, a feature or branch name. The user
  picks it; suggest the branch name and ask once if they haven't.
- `auto-browser proof-dir <key>` prints the latest run directory for today.
  `auto-browser proof-dir <key> --new` creates the next free one (`-b`, `-c`
  for a second or third run that day). Never overwrite an earlier run. A
  re-test after fixes is a new run, and the comparison is the whole value.

## Manifest

```json
{
  "key": "feature-calendar-sync",
  "date": "2026-01-15",
  "repo": "/path/to/checkout",
  "branch": "feature/calendar-sync",
  "sha": "a1b2c3d",
  "base": "origin/main",
  "env": "local",
  "url": "http://localhost:3000",
  "viewport": "1440x900",
  "user": "test-user@example.com",
  "criteria_source": "spec: docs/specs/calendar-sync.md",
  "criteria": [
    {
      "id": "01",
      "slug": "synced-email-visible",
      "description": "Settings shows the email synced to the calendar",
      "steps": ["log in", "go to /settings", "find the calendar section"],
      "expected": "the connected account's email is displayed",
      "result": "PENDING",
      "observed": null,
      "shots": []
    }
  ],
  "findings": [],
  "verdict": "PENDING",
  "published": null
}
```

### Fields that carry meaning

- **`criteria_source`**: where the criteria came from (`spec: <path>`,
  `pasted ticket text`, or `pr diff`). A reviewer weighs a diff-derived
  criterion differently from a written one.
- **`result`**: `PENDING` | `PASS` | `FAIL` | `BLOCKED`. `BLOCKED` means the
  step could not be exercised, usually because an earlier one failed. It is
  never a synonym for pass.
- **`shots`**: filenames relative to the run's `shots/` directory. A
  criterion with `result: "PASS"` and an empty `shots` array is invalid; see
  the hard rules below.
- **`findings`**: `{ "kind": "console" | "network" | "visual", "detail": "...",
  "shot": "..." | null }`. Off-criteria breakage goes here rather than being
  dropped.
- **`verdict`**: `PENDING` until every criterion has a non-`PENDING` result.
  Then `PASS` only if all criteria are `PASS`, otherwise `FAIL`.
- **`published`**: `null`, or `{ "at": "<iso8601>", "where": "<tracker>",
  "url": "..." }`. Non-null means this run was already posted somewhere.
  Never post it twice.

## Hard rules

Inherited by every skill in the family. Not defaults to weigh against
convenience.

1. **Nothing leaves the machine without explicit user approval**, every run,
   pass or fail. Showing the writeup is not approval; the user saying "post
   it" is.
2. **Never publish a half pass.** Any non-`PASS` criterion means the run stops
   at the local writeup.
3. **`PASS` requires a screenshot of it passing.** No shot, no pass. Mark it
   `BLOCKED` and say why.
4. **Write only inside the run directory** (and the replay store, through
   browser-replay). Nothing in the project's source tree.

## Scope

- **Environment:** local dev only, at the config's `baseUrl`. Testing a
  preview or staging deploy is the user's call, every time, and needs its own
  login path; don't improvise one.
- **Viewport:** the config's `viewport`, default 1440x900.
- **Repo:** whichever repo the session is running in.

## Shared preamble

Every skill in the family starts here.

### 1. The project config

```bash
auto-browser config
```

- **Exit 0**: use its `baseUrl`, `scripts`, `login` and `notes` for
  everything below. Never hardcode a port, a URL, or a login.
- **Exit 3**: no `auto-browser.json` in this repo. **Stop.** Offer to create
  one from the plugin's `examples/auto-browser.json` with the user. Don't
  guess which port the app is on; a run against the wrong port produces
  screenshots of nothing.

### 2. The key and the run

Settle `<key>` (see Locations). Then look for an existing run before
creating one:

```bash
auto-browser proof-dir <key>
```

If that directory has a `run.json` still `PENDING`, continue it rather than
starting a parallel run. If it's finished, ask whether this is a re-test (new
run, `--new`) or a question about the old one.
