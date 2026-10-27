---
name: pr-proof
description: Produce end-to-end proof that a PR works. Browser-tests the feature against local dev, screenshots each acceptance criterion, writes a dated proof document locally and prints it, and optionally posts it to the user's tracker or PR once they approve. Composes pr-proof-test, pr-proof-shots, and pr-proof-publish. Use when the user asks to prove a PR works, gather PR testing evidence, produce testing proof for review, screenshot a feature for a ticket, or invokes /pr-proof. Not code review and not opening a PR.
---

# pr-proof

Turns "I think this works" into evidence a reviewer can check.

**Read `${CLAUDE_PLUGIN_ROOT}/skills/pr-proof/contract.md` first**: locations,
the manifest schema, the hard rules, and the shared preamble. Every skill in
this family shares them.

## What this skill is

The composer. It owns the sequence and the writeup; the stages own the work.

| Stage | Skill | Owns |
| --- | --- | --- |
| 1 | `pr-proof-test` | criteria, browser run, `PASS`/`FAIL` per criterion |
| 2 | `pr-proof-shots` | extra and replacement screenshots |
| 3 | *this skill* | the writeup, `proof.md` |
| 4 | `pr-proof-publish` | print it, and post it only on approval |

Each stage is separately invocable and reads the manifest rather than arguments
from here. Run one directly when that's all that's wanted. A user asking for
screenshots of a page wants `pr-proof-shots`, not this.

## Sequence

### 1. Test

Invoke `pr-proof-test`. It confirms the criteria with the user before opening a
browser, so don't pre-confirm them here.

It comes back with a manifest and a verdict. Do not re-judge its results. If a
criterion looks wrong, re-run that stage rather than editing `result` here.

### 2. Fill gaps

Invoke `pr-proof-shots` only when there's a gap worth filling: a criterion
whose shot is unclear, or context a reviewer will want (the empty state, the
before, an adjacent screen the change touches). Skip it when stage 1 already
captured everything. Don't re-shoot passing criteria for the sake of it.

### 3. Write it up

Write `proof.md` in the run directory. Compose it from the manifest, never
from memory of the run:

- **Verdict**: `PASS` only if every criterion passed; otherwise `FAIL` with
  the count.
- **Environment**: commit SHA, branch, base, URL, viewport, login user.
- **Criteria**: a table of id, description, result, screenshot as a relative
  link (`shots/<file>`), and where the criteria came from.
- **Findings**: failures and off-criteria breakage, each with its screenshot.
- **Not covered**: what the flow couldn't reach, and why. Say it out loud;
  silence reads as coverage.

### 4. Publish, gated

**Verdict `FAIL`:** stop here. Do not invoke the publish stage and do not
offer to post. Report the failures, point at `proof.md`, and let the user
decide what to fix. Half passes stay local.

**Verdict `PASS`:** invoke `pr-proof-publish`. By default it prints the proof
and stops. It posts anywhere only after its own explicit yes. Do not
pre-approve on the user's behalf, and do not treat their having asked for
`pr-proof` as approval to post. Producing the proof and publishing it are two
decisions.

## Output

Short. The verdict, one line per criterion, the `proof.md` path, and whatever
the publish stage is waiting on. The doc holds the detail; don't restate it in
chat.
