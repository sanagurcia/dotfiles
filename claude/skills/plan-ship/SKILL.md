---
name: plan-ship
description: Shape one ticket's plan with the user, then deliver the whole thing autonomously — plan together, and on their go create a worktree, implement, review, run the full check gate and open a PR whose description is the handoff. Use this skill when the user runs /plan-ship with a ticket ID, a ticket URL, or pasted ticket text and wants a say in the design but no check-ins after it. Do not use it when they want to review every commit (/focus) or to hand over the whole ticket unplanned (/ship).
argument-hint: "<ticket-id | ticket-url | pasted ticket text + any extra context>"
disable-model-invocation: true
---

# Plan-ship

One ticket, two halves, and a hard line between them. Before the gate you are in
a conversation and write no code. After it the user is gone: you implement,
review, check and open the PR without a single check-in.

Its siblings: `focus` stays interactive to the end and expects the user to test
by hand; `ship` skips the planning conversation entirely. This skill exists for
the common case in between — the design needs the user, the execution does not.

**Two things this skill deliberately does not do.** It does not poll CI, and it
does not tear down the worktree. The user reviews the diff locally, in that
worktree; what they need from GitHub is the description.

## Phase 0 — Ticket and state of play

Read-only, in the main checkout you were invoked from. Nothing is provisioned
yet and nothing runs — planning reads code.

Follow `~/.claude/skills/shared/ticket-and-plan.md`, **Intake** and **State of
play**. For a ticket in a subsystem you can name, read the files directly rather
than fanning out `Explore` agents; the user is here to point you at things.

## Phase 1 — Plan, together

Follow the same file's **Planning together** and **The plan** sections. Short
exchanges, two or three approaches at bird's-eye level, costs brought early.

The commit series in the plan is the series you will build, so it is worth
getting right here — after the gate there is nobody to renegotiate it with.

## Phase 2 — The gate

This is the whole reason the skill exists, so be explicit about it.

**Approval of the plan is the go.** Nothing else is: a "looks good" about a
finding, a file, or an approach is not permission to run to the end. If you are
not certain the user approved *the plan*, ask — it is the last question you get.

**Say what their go buys, in one line, before you start:** from here you work to
an open PR with no progress reports, and the next thing they hear from you is
the finished handoff.

From the gate on, `~/.claude/skills/shared/unattended.md` governs the run — and
since this skill never waits for a preview, a genuine blocking question is the
*only* interrupt left. Ambiguity resolvable by reading code is not one; pick the
reading a careful colleague would, record it under **Assumptions** in the PR
body, continue.

Then, in order:

1. `TaskCreate` one task per remaining phase, per that file's **Progress
   reporting**.
2. Create and provision the worktree per
   `~/.claude/skills/shared/worktree.md`, **Create** and **Provision,
   least-first**. Escalate to `autarc-db` only for a migration or a
   database-touching integration test.

   The original checkout is the tree the user is sitting in and may keep working
   in, so the "never drift back" rule in that file is load-bearing here rather
   than hygienic. Confirm `git rev-parse --show-toplevel` before the first edit.
3. Copy the plan into the worktree's session scratchpad path, or keep the
   original path and use it consistently — sub-agents get their file lists from
   it. Never into the repo.

## Phase 3 — Implement

Build the approved series, in its approved order.

- **Tests first**, per `AGENTS.md` — including its mandatory integration tests
  for new API endpoints. Touching Go means reading `apps/api/api-v2/CLAUDE.md`
  first.
- Fan out only across units the plan already showed to be independent, per
  `~/.claude/skills/shared/worktree.md`, **Sub-agents share this worktree** —
  including the verbatim prohibition. Do not re-split or re-order the series.
- After each unit lands, type-check scoped to what you touched
  (`~/.claude/skills/shared/checks.md` step 2). That is the only check in this
  phase; the gate runs once, at the end.
- Translations: `id-ID` is Crowdin's in-context pseudo-language (`crwdns…`
  markers), not a real locale — never hand-write keys into it.
- Fix failures yourself. A red test is not a blocking question.
- If the work needs a commit the plan does not have, write it and say so under
  **Out of scope / still red** in the PR body. That is not worth stalling for.
- Commit per `~/.claude/skills/shared/pr-handoff.md`'s **Commit hygiene**.

## Phase 4 — Review, then feedback

`~/.claude/skills/shared/unattended.md`, **Fable review** and **Handling its
feedback**. Its third axis applies here and nowhere else: paste the approved
plan's decisions into the prompt and ask whether the diff matches them.

## Phase 5 — Blast radius, then the check gate

`~/.claude/skills/shared/pr-handoff.md`'s **Blast radius**, then
`~/.claude/skills/shared/checks.md` end to end, one at a time. Fix everything
that fails.

## Phase 6 — Open the PR, and stop

Follow `~/.claude/skills/shared/pr-handoff.md`. Nobody has tested this by hand,
so **How to test** covers every acceptance criterion, with a click path against
the preview and the local path in the worktree.

Then stop. **Do not watch CI and do not wait for the preview** — the user is
about to read the diff, and CI will have finished by the time they care. If a
check you can see is already red, fix it, push, and say so; do not open a poll
loop.

**Leave the worktree in place.** No `pnpm services down`, no
`git worktree remove` — the user reviews the code there. Its path is part of the
report.

One `PushNotification` (`{status: "proactive", message: "<200 chars"}`; a "not
sent" result just means they are at the terminal), then a final message with, in
this order:

1. The PR link, and one line saying the description carries the test path,
   assumptions, cross-domain notes and anything left out.
2. The worktree path and branch name, so the diff is one `cd` away.
3. Anything that diverged from the approved plan, in a sentence each.
4. One concrete next action.

## Phase 7 — Iteration, if they want it

The notification ends autonomy; whatever comes next is a normal conversation
against a pushed branch. Fixes are new commits, never amends and never a
force-push. Anything durable that comes out of the iteration — a new assumption,
a newly discovered constraint — is edited into the PR body, not left in chat.

## Guardrails

- **No code before the gate.** No branch, no worktree, no edits during planning.
- **No check-ins after it.** Not phase transitions, not "plan is ready", not a
  test you can fix.
- Never watch CI, wait for a preview, or tear down the worktree in this skill.
- Never merge. Provisioning stops at `autarc-db`.
- Never `pnpm services down --volumes` in the main checkout.
- Never `git add -A`/`git add .`, and never stage a file you did not change.
- Never run a full test suite.
- Report faithfully, in the PR body as well as in chat: a skipped check is a
  skipped check.
