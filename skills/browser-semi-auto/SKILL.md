---
name: browser-semi-auto
description: Step-through browser session with the user in the loop, like a debugger. Claude drives a headed browser but takes exactly one step at a time and only when the user says so; Claude does the tedious parts (filling forms, uploads, logins, navigating) while the user watches every page and decides when to advance, jump to a breakpoint, change values, or take over by hand. Use when the user runs /browser-semi-auto, or asks for a "semi manual" or "semi auto" test, to "step through" a flow, "drive it but wait for me", "walk me through it in the browser", or a manual test where Claude fills the forms. With `--setup` (or "auto-run the setup, stop only at what changed"), Claude runs the setup steps itself and stops only at the steps that test the branch's changes. Not for unattended tests (that is browser-replay).
---

# browser-semi-auto

A manual test where Claude has the keyboard and the user has the controls.
Claude proposes the next step, waits, does exactly that step, reports, and
waits again. Nothing moves without the user's go.

## Arguments

All optional:

- `<flow>`: a saved replay to use as the step plan (find it with
  `auto-browser list`; read its `run.sh` or `flow.spec.ts` and
  `replay.json`), or a plain goal ("check out as a guest with a coupon").
- `<url>`: the starting page. Default: the config's `baseUrl`
  (`auto-browser config`).
- `--width 390|1280` (or any number): the viewport. With none, ask.
- `--setup`: auto-run everything except the parts the branch changed.
  Claude drives the setup steps on its own and stops only at the test spots.
  See "Setup mode" below.

`auto-browser` is on the Bash PATH while this plugin is enabled; otherwise
call `${CLAUDE_PLUGIN_ROOT}/bin/auto-browser`.

## Setup

1. **Mode is always headed.** That is the point of the skill, so don't ask
   headed vs headless. Use a dedicated session with its own throwaway
   profile:
   `agent-browser --headed --session semi-<flow> open <url>`, and pass
   `--session semi-<flow>` on every later command so all steps hit the same
   window. Never use the user's personal browser profile.
2. **App up?** Run `auto-browser health`. If it fails, show the reason. If the
   config has `scripts.up`, offer to run `auto-browser up`; otherwise give the
   user the start command from the config's `notes` or the project's README.
   Start anything only if they say so.
3. **Ask once** (one AskUserQuestion form): viewport, starting point (fresh
   start, resume where they left off, a replay's segment), and test data (the
   defaults or their values).
4. **Build the plan**: a numbered list of steps. Take it from the replay when
   there is one, otherwise from the goal. One step is one thing the user
   would want to look at before the next: "fill the shipping form with the
   table below" is one step, and "press Continue" is another. Mark natural
   breakpoints (each new page, each upload, each dialog). Show the plan and
   the test data as tables before step 1. For login, use `auto-browser login`
   (session cookies) when the config has a login script; otherwise follow the
   login steps in the config's `notes`, and say which account you'll use.

## The loop

Before each step, print one line, `Next: <n>. <what>`, and highlight the
target (`agent-browser --session ... highlight <sel>`) so the user sees it in
the window. Then stop and wait.

The user's commands (plain chat, loose wording is fine):

| Command                         | What Claude does                                                    |
| ------------------------------- | ------------------------------------------------------------------- |
| `n`, `go`, `next`               | Do the one proposed step.                                           |
| `n 3`                           | Do the next 3 steps, stopping early on anything unexpected.         |
| `run to <n or label>`           | Run up to that breakpoint and stop before it.                       |
| `skip`                          | Drop the proposed step and propose the one after.                   |
| `back` / `redo`                 | Browser back, or repeat the last step.                              |
| `use <value>` / `fill X with Y` | Change the data for this or later steps, then propose again.        |
| `snap` / `shot`                 | Describe what is on the page now, or save a screenshot and show it. |
| `I'll do it` / `my turn`        | The user acts in the window. Wait for "go on" or a new command.     |
| `stop`                          | End the session (see Ending).                                       |

Rules:

- **Never take a step the user didn't authorize.** No "while I'm here", no
  retrying a failed step, no fixing a validation error by guessing. A count
  (`n 3`, `run to`) or `--setup` mode is the only way several steps run in a
  row.
- **Re-read the page before every step.** The user may have clicked or typed
  in the window. Take a fresh `snapshot` and plan from what is there, not
  from the plan's assumptions. If the page moved off plan, say so and propose
  a new next step.
- **Stop on surprises**, even mid-count: an error, a toast, a validation
  message, a page other than the expected one, a spinner over ~10 s. Report
  the exact text and wait.
- **After each step**, report in two or three lines: what was done, the URL
  if it changed, and any message on screen. When the step filled a form, show
  the values used as a table.
- **Never submit anything with real-world side effects** (a payment, an
  invite or message to a real person, anything that leaves the test
  environment) without asking about that specific step, even inside a count.
- **Keep a step log** as you go (commands that worked, selectors, data) in
  `<home>/<key>/scratch/replay-<flow>.log` (`auto-browser home`), so it can
  become a replay.

## Setup mode (`--setup`)

The same session, but Claude runs the plan on its own and stops only at the
steps that test what the branch changed. Everything else (logins, filler
forms, navigation to the changed page) runs straight through.

1. **Find the test spots** before step 1. Read what the branch changed
   (`git diff <base>...HEAD --stat` and the diff itself; the base is the
   repo's default branch unless the user names another) and any spec or
   acceptance criteria the user points at. Mark each plan step that shows or
   exercises a change as a test spot: a changed page, field, copy,
   validation, branch of logic, or result screen. A step that only gets you
   there is setup.
2. **Show the plan** with a Spot column (`spot 1`, `spot 2`, ... or blank)
   and one line per spot on what changed there and what to check. The user
   may add, drop or move spots. Start only on their go.
3. **Run setup steps without stopping.** Still report each one in a single
   line, and still re-read the page before each step.
4. **At each spot, stop before it.** Print `Spot <k>/<total>: <step> (checks:
   <what changed>)`, highlight the target, and wait. The user says `go`
   (Claude does it), does it themselves (`my turn`), or gives any loop
   command. After the step, report and wait again so they can confirm the
   result (`ok`, or what looked wrong). Log the verdict per spot. Then resume
   the auto-run.
5. **Auto-run still stops** on every surprise from the loop rules (error,
   toast, validation message, off-plan page, long spinner) and before any step
   with real-world side effects. Those stops are not spots; once the user
   clears them, auto-run continues.
6. At the end, report each spot's verdict in a table (spot, step, what
   changed, ok / issue with exact text).

Loop commands work at any stop. `pause` during an auto-run stops before the
next step and drops back to the normal one-step loop until the user says
`resume`.

## Ending

On `stop`, or at the end of the plan:

1. Close the session: `agent-browser --session semi-<flow> close`.
2. Report: steps done, anything that looked wrong (exact text, step number),
   and any screenshot paths.
3. Offer, per browser-replay, to save the step log as a replay (or to update
   the replay it came from with any drift found). Lean toward saving.
4. If you started the app, stop it and give the user the command to start it
   again.
