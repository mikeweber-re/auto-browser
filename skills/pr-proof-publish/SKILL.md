---
name: pr-proof-publish
description: Print an approved pr-proof writeup and its screenshot list, and optionally post it to the user's tracker (an issue tracker, a GitHub PR comment, or similar) through whatever connector or CLI they have. Posting needs an explicit go-ahead every time, refuses a run with any failed criterion, and never posts the same run twice. Use when the user approves a proof, asks to share or attach testing evidence or screenshots to a ticket or PR, or invokes /pr-proof-publish.
---

# pr-proof-publish

Puts an approved proof in front of reviewers. By default that means printing
it locally. Posting it anywhere else is an optional second step, and the only
thing in the family that writes outside the run directory, which is why it is
the most constrained.

**Read `${CLAUDE_PLUGIN_ROOT}/skills/pr-proof/contract.md` first**: locations,
the manifest schema, the hard rules, and the shared preamble.

## Refuse when

Check all of these before showing the user anything. Each one is a stop, not a
warning to publish past:

- **Any criterion is not `PASS`.** `FAIL`, `BLOCKED`, or `PENDING` all mean the
  run stays local. Report what's outstanding and stop. A user asking to
  publish anyway is a request to write up the failure honestly first, not to
  omit it.
- **`published` is non-null.** The run was already posted. Show where, and ask
  whether they want a follow-up on a *new* run.
- **A `PASS` criterion has no screenshot.** That contradicts the manifest's
  own claim; send it back to `pr-proof-test`.
- **A referenced screenshot file is missing on disk.** A writeup with dead
  image references is worse than none.
- **No `proof.md`** in the run directory. Run `pr-proof` to compose one; don't
  improvise a body from the manifest.

## Step 1: print it (the default)

Show, in the chat:

- the verdict and the criteria table
- every screenshot by path and what it shows
- the full `proof.md` body, or its path if it's long

Then stop. The proof is done. Offer posting in one line: "Post this to
<the ticket or PR>?" Name where, if you know.

## Step 2: post it (optional, gated)

Only if the user wants it posted. Approval is per run and is never implied:
not by a passing verdict, not by the user having invoked this skill, not by an
earlier approval on an earlier run.

1. **Pick the destination with the user**: which tracker and which item (a
   ticket ID, a PR number). Use the tool they already have for it, in this
   order: a connected MCP connector for that tracker; else its official CLI
   (`gh pr comment`, `jira`, and so on); else stop and hand them the body to
   paste. Never drive the tracker's web UI with a browser when a connector or
   CLI covers it.
2. **Show the exact post**: the destination, the comment body exactly as it
   will appear, and each image that will be attached. Then ask whether to
   post. Wait for an explicit yes. Silence, "looks good", or a question about
   something else is not a yes. "Looks good" is a reaction to the proof, not
   an instruction to post. If the user edits the writeup, re-read it from disk
   and show it again.
3. **Post once.** One comment per run, with the images (uploaded through the
   tool's attachment support where it has one, else listed by filename) and a
   line naming the commit SHA and branch the proof was taken from. **Never
   change the item's status, assignee, labels, or anything else.** The
   comment is the whole mandate.

## Record

After a post, write `published` in the manifest:
`{ "at": "<iso8601>", "where": "<tracker>", "url": "<comment url>" }`.

Report the comment URL and the attachment count. Nothing else.
