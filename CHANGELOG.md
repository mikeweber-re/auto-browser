# Changelog

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
