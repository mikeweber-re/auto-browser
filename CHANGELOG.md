# Changelog

## Unreleased

- browser-replay: opt-in capture. `AB_SHOTS=1` saves a screenshot after every
  step (Playwright: screenshots and a trace for every run). `AB_RECORD=1`
  saves a video of the run, `AB_RECORD=mp4` an mp4 for PR attachments (needs
  agent-browser 0.41 or later). Both are off by default.
- browser-replay and browser-semi-auto: every stop that needs the user (a
  step prompt, a manual step, bug or drift, save or skip) is an
  AskUserQuestion form, so the session shows as waiting for input instead of
  idle.

## 0.1.0

First release.

- Skills: `browser-replay`, `browser-semi-auto`, `pr-proof`, `pr-proof-test`,
  `pr-proof-shots`, `pr-proof-publish`.
- `auto-browser` helper CLI: storage root, project config, health, login,
  replay scaffold and runner, pr-proof run directories.
- Replays in two kinds: agent-browser shell scripts and Playwright specs.
- Project config in `auto-browser.json`; storage root set by
  `AUTO_BROWSER_HOME`.
- pr-proof prints the proof by default; posting to a tracker is optional and
  needs explicit approval per run.
- Optional chrome-devtools-mcp setup documented, not bundled.
- Browser profiles live in the user's cache, never in the replay store;
  `last-run/` output is git-ignored at the store root.
- MIT license. `npm run pack` builds a shareable zip.
