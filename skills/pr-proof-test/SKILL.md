---
name: pr-proof-test
description: Browser-test a PR against local dev and record a pass/fail result per acceptance criterion into a run manifest. Takes the criteria from a spec file the user points at, ticket text they paste, or the PR diff, confirms them with the user, then drives agent-browser through the flow. Use when the user asks to test a PR in the browser, verify acceptance criteria, check whether a feature actually works, or invokes /pr-proof-test. Records results only; the writeup and publishing are pr-proof and pr-proof-publish.
---

# pr-proof-test

Runs the feature and records what actually happened. This is the stage that
decides `PASS` or `FAIL`; nothing downstream re-judges it.

**Read `${CLAUDE_PLUGIN_ROOT}/skills/pr-proof/contract.md` first**: locations,
the manifest schema, the hard rules, and the shared preamble.

## What this stage owns

Deriving the criteria, driving the browser, and writing `result` and `observed`
for each one. It captures the screenshot that proves each criterion, because
the proof has to be taken at the moment the state is on screen. A later stage
cannot go back and get it.

`pr-proof-shots` exists for extra or replacement screenshots, not for the
per-criterion proof shots.

## 1. Derive the criteria

Sources, in priority order:

1. **A spec file the user points at**: acceptance criteria in a design doc,
   a spec in the repo, a checklist file.
2. **Ticket text the user pastes**: the acceptance criteria from their
   tracker. If they mention a ticket but paste nothing, ask for the text.
   If a tracker connector or CLI is available, you may offer to fetch it,
   read-only.
3. **The PR diff**, the fallback when both are thin:
   ```bash
   git diff --stat <base>...HEAD
   ```
   The base is the repo's default branch unless the user names another.
   Changed routes, pages, and components name the surfaces to visit. A diff
   says what moved, not what correct looks like. Say so, and write
   conservative criteria.

Record the source in the manifest's `criteria_source`.

Each criterion needs an id, a slug, ordered steps, and the expected
observation. Vague source material ("settings page works") means asking what
specifically should be visible, not inventing a definition of done.

**Print the criteria and get a yes before opening a browser.** A wrong flow
tested thoroughly is worse than no proof.

Create the run (`auto-browser proof-dir <key> --new`) and write the manifest
with every `result: "PENDING"` before the first browser command, so an
interrupted run leaves a record of intent.

## 2. Bring up the stack

```bash
auto-browser health
```

Exit `0`: the app is ready, move on. Non-zero: the reason is on stderr.

- **The config has `scripts.up`**: offer to run `auto-browser up`, then
  re-check health. Starting containers and servers is not something to do
  silently, so ask first.
- **No `scripts.up`**: stop and report what's down. Check the config's
  `notes` for how this project comes up. Don't invent a start command.

Never skip the health check. A run against a dead port produces screenshots of
an error page, which is worse than no run.

## 3. Log in

```bash
agent-browser skills get core     # load first; don't run commands from memory
```

Use a dedicated session (`--session proof-<key>`) with a throwaway profile.
Never the user's personal browser profile.

**The config has `scripts.login`:**

```bash
auto-browser login [email]
```

It prints a JSON array of `{name, value}` session cookies. Set each with
`agent-browser --session proof-<key> cookies set <name> <value> --url <baseUrl>`,
then open the app.

The user comes from `login.defaultUser`, or from `login.roles` when a
criterion says "as an admin". Ask if the criteria imply a role that isn't
listed.

**No `scripts.login`:** either the app has no login, or its login only works
through the UI. The config's `notes` say which and how to drive the form.
A saved `agent-browser auth` profile or `--state` file works too, if the user
has one. Never type a real password you weren't given for this purpose.

Record the user actually used in the manifest's `user`.

## 4. Work the criteria

agent-browser drives everything. If chrome-devtools-mcp is set up, use it for
performance, network and console checks, never to drive the page.

**Check for a saved replay first** (`browser-replay` skill). If one covers the
flow, run it to drive the steps, then take this stage's own proof shots and
write the manifest as normal. If none does, record the flow per that skill
while you work the criteria.

Per criterion: do the steps, observe, screenshot the state that proves it into
the run's `shots/<id>-<slug>.png`, then write `result`, `observed` (one line on
what was actually on screen), and `shots`. Screenshot the region that tells
the story when that reads better than the full page.

Record regardless of how the UI looked:

- console errors and warnings (`agent-browser errors`)
- failed network requests
- anything visibly broken that isn't in the criteria

Those go to `findings`. Off-criteria breakage is a finding, not a silent
omission.

**On the first `FAIL`:** keep going through criteria that are independent of it
(a reviewer wants the whole picture), and mark the dependent ones `BLOCKED`
with a reason. Do not stop the run at the first red.

## 5. Close the run

Set `verdict`: `PASS` only if every criterion is `PASS`, otherwise `FAIL`.
Close the browser session.

Report to the user: the verdict, one line per criterion, the findings, and the
manifest path. Then stop.

This skill does not write the doc and does not post anything. If the user
wants the full proof, that's `pr-proof`.
