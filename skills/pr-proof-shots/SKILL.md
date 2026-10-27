---
name: pr-proof-shots
description: Capture desktop screenshots of a feature in local dev and file them into a pr-proof run's shots directory. Works from an existing run manifest or from a list of pages or states the user names. Use when the user asks for screenshots of a feature or page, more or better shots for a PR, a retake of a screenshot, or invokes /pr-proof-shots. Captures only; it does not judge pass or fail and does not publish anything.
---

# pr-proof-shots

Screenshots, filed where the rest of the family expects them. No verdict, no
publishing.

**Read `${CLAUDE_PLUGIN_ROOT}/skills/pr-proof/contract.md` first**: locations,
the manifest schema, the hard rules, and the shared preamble.

## When this runs on its own

- The user wants shots of a screen without a full test run.
- A criterion passed but its screenshot is unclear, cropped, or shows the wrong
  state, and needs retaking.
- Extra context a reviewer will want that isn't tied to a criterion: the empty
  state, the before, an adjacent screen the change touches.

`pr-proof-test` takes the per-criterion proof shots itself, because those have
to be captured at the moment the state is on screen. Don't re-shoot a passing
criterion here unless asked.

## 1. Decide what to capture

Two ways in, in this order:

1. **A run exists for today** (`auto-browser proof-dir <key>` has a
   `run.json`): read it. Criteria with an empty `shots` array, or ones the
   user named, are the target list. Reuse each criterion's id and slug so
   filenames line up.
2. **No run, or the user named specific screens**: take the list from the
   user. Ask for the states, not just the URLs: "the settings page" and "the
   settings page with no calendar connected" are different shots. Create a
   run directory with `auto-browser proof-dir <key> --new`.

Either way, print the list and confirm before capturing. Assign ids continuing
from any existing shots so nothing collides.

Running without a manifest is fine. File the shots and say in the reply that
no manifest was updated.

## 2. Capture

```bash
agent-browser skills get core     # load first; don't run commands from memory
auto-browser health               # skip nothing, even for one shot
auto-browser login [email]        # JSON [{name,value}], when the config has scripts.login
```

Run the health check first. This skill often runs on its own, when nothing
else has checked the stack. Set each login cookie with
`agent-browser --session proof-<key> cookies set <name> <value> --url <baseUrl>`,
then open the app. With no login script, the config's `notes` say how to
authenticate.

URLs are relative to the config's `baseUrl`, never a hardcoded port.
Viewport: the config's `viewport`, default 1440x900.

Write each shot to `<run dir>/shots/<id>-<slug>.png`.

Wait for the state to settle before capturing: no half-loaded skeletons, no
open dropdown left over from the previous step. A screenshot of a spinner
proves nothing.

Retakes replace the file only when the user asked for a retake of that exact
shot. Otherwise add `-b` rather than overwriting; the original may be cited in
a writeup already.

Close the browser session when done.

## 3. Record

Manifest present: add the filenames to the right criterion's `shots`, or to a
`findings` entry's `shot`. **Never change a `result` or the `verdict`.** This
skill does not judge, and a screenshot is not a pass.

Report the file list and what each shows.
