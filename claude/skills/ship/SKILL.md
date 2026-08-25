---
name: ship
description: Take one small-to-medium ticket from start to merge-ready PR without check-ins — understand, plan, implement with sub-agents, review with a Fable sub-agent, run the full pre-PR check gate, open the PR, and wait for the preview link. Use this skill when the user runs /ship with a ticket ID, a ticket URL, or pasted ticket text, and explicitly wants the whole ticket delivered autonomously. Do not use it for exploratory work, for tickets needing a product decision, or when the user wants to review a plan first — that is /plan-ship.
argument-hint: "<ticket-id | ticket-url | pasted ticket text>"
disable-model-invocation: true
---

# Ship

Autonomous end-to-end delivery of one ticket. The user has opted out of
check-ins: **do not** ask for approval between phases, **do not** report progress
in prose, **do not** ask "want me to continue?". Work until the PR is open and the
preview link resolves, then notify once.

Argument: a ticket ID (`SER-156`, `HEAT-1834`, `UK-568`), a ticket URL, or pasted
ticket text.

Its siblings: `plan-ship` is this skill with the plan shaped by the user first;
`focus` is interactive throughout. If the user wants a say in the design, they
want one of those.

## Unattended from the first word

Follow `~/.claude/skills/shared/unattended.md` for the whole run: the bar for
interrupting, the task list as the only progress report, the pre-PR review and
how to handle its findings.

One addition to its interrupt rule — this skill has a **second** legitimate
interrupt at the very end: one `PushNotification` carrying the preview URL.

## Phase 0 — Preflight

1. `TaskCreate` one task per phase below, per `unattended.md`'s **Progress
   reporting**.
2. Create and provision the worktree per
   `~/.claude/skills/shared/worktree.md`, **Create** and **Provision,
   least-first**. Escalate to `autarc-db` only for a migration or a
   database-touching integration test.

## Phase 1 — Understand

Follow `~/.claude/skills/shared/ticket-and-plan.md`, **Intake**. Locate the code
with parallel `Explore` sub-agents in a single message — you have no user to ask,
so breadth is worth more here than in the interactive skills.

Its **Scope check** applies: block only for a genuine product decision or a
ticket far larger than it looked. When you do block, notify once with what you
found, and stop.

## Phase 2 — Plan

Write the plan as described in that file's **The plan** section, to the session
scratchpad. **No approval needed and no exchanges** — the planning-together
section does not apply to this skill; do the same thinking on your own and go.

Then split the plan into **independent work units** — chunks touching disjoint
files. Units sharing a file are one unit.

## Phase 3 — Implement

- **Tests first**, per `AGENTS.md` — including its mandatory integration tests for
  new API endpoints. Touching Go means reading `apps/api/api-v2/CLAUDE.md` first.
- Fan out on independent units per `~/.claude/skills/shared/worktree.md`,
  **Sub-agents share this worktree** — including the verbatim prohibition, which
  is not optional.
- After the fan-in, run the type-check and the targeted tests for what you
  touched, scoped as in `~/.claude/skills/shared/checks.md` steps 2, 4 and 5.
  This is the fast pass that keeps the series honest; the full gate runs in
  Phase 5.
- Translations: `id-ID` is excluded because it is Crowdin's in-context
  pseudo-language (`crwdns…` markers), not a real locale — never hand-write keys
  into it, in `apps/web/src/locales/` or the ui-library's shared locales.
- Fix failures yourself. A red test is not a blocking question.
- Commit in logical chunks per `~/.claude/skills/shared/pr-handoff.md`'s
  **Commit hygiene**.

## Phase 4 — Review, then feedback

`~/.claude/skills/shared/unattended.md`, **Fable review** and **Handling its
feedback**. No plan was approved here, so the review's axes are the acceptance
criteria and the repo's standards.

## Phase 5 — Blast radius, then the check gate

`~/.claude/skills/shared/pr-handoff.md`'s **Blast radius**, then
`~/.claude/skills/shared/checks.md` end to end, one at a time. Fix everything
that fails.

Doctor and knip are here for the same reason as the rest: both gate every PR, and
learning about them from a CI comment costs a push and a wait that this run has
no user to absorb.

## Phase 6 — Open the PR

Follow `~/.claude/skills/shared/pr-handoff.md`. Nobody has touched this feature
by hand, so **How to test** is written against the preview and covers every
acceptance criterion.

Then watch CI in the background — `--watch` blocks longer than a foreground
`Bash` call allows:

```bash
gh pr checks <pr> --watch --fail-fast   # Bash with run_in_background: true
```

**Cap the fix loop at three pushes.** Fix red checks yourself, and re-run a
clearly unrelated infrastructure flake once. After the third attempt, stop and go
to Phase 7 with the failing check named in both the PR body and the final
message — grinding on an unfixable check strands a user who is not watching.
`PR Size Check` failing means the ticket was too big for this skill — say so
instead of splitting the PR unasked.

## Phase 7 — Wait for the preview, then notify

The preview URL arrives as a `github-actions` comment whose body contains
`Preview is ready!`. Pro web is always
`https://pr-<PR>-autarc-pro-staging.autarc.workers.dev`; for
`staging-full`/`full` the same comment adds the per-PR backend at
`https://pr-autarc-<PR>.fly.dev`.

Check once before waiting — the preview jobs run as part of the same workflow, so
green in Phase 6 usually means the comment already landed. The bot **edits one
comment in place**, so a stale `Preview is ready!` can predate your push; trust it
only once checks are green.

If you do have to wait, use `Monitor` — one poll loop that emits a single line and
exits. Not a foreground `Bash` call (capped at 10 minutes), and not
`ScheduleWakeup` (that tool only works inside `/loop` dynamic mode):

```
Monitor({
  description: "preview deploy for PR <pr>",
  timeout_ms: 1800000,
  persistent: false,
  command: `for _ in $(seq 60); do
  url=$(gh pr view <pr> --json comments --jq '.comments[].body' 2>/dev/null \
    | grep -oE 'https://pr-[0-9]+-autarc-pro-staging\\.autarc\\.workers\\.dev' | head -1)
  [ -n "$url" ] && echo "preview ready: $url" && exit 0
  sleep 30
done
echo "preview NOT ready after 30m"`,
})
```

If it times out, notify with the PR URL and the failing preview job instead of a
link — never report a link you did not see resolve.

**Then tear down the worktree** per `~/.claude/skills/shared/worktree.md`,
**Tear down** — on both paths, whether the link resolved or the wait timed out,
and before the notification, so the report is the last thing that happens. The
PR body is the handoff; nothing the user needs is left in that directory.

When the link resolves, send exactly one notification:

```
PushNotification({
  status: "proactive",
  message: "SER-156 ready to test: https://pr-1234-autarc-pro-staging.autarc.workers.dev — PR #1234, CI green"
})
```

Then, in the final message, in this order:

1. The preview link.
2. The PR link, and one line saying the description carries the test path,
   assumptions and anything left out.
3. One concrete next action.

## Guardrails

- Never merge. "Merge-ready" means open, green, reviewed, labelled.
- Provisioning stops at `autarc-db`. Never run `autarc-up`, `autarc-dev`,
  `autarc-stop`, `pnpm services up`, or a bare `pnpm energy setup`.
- Never `pnpm services down --volumes` in the main checkout.
- Never force-push a shared branch. Never commit to `main`.
- Never `git add -A`/`git add .`, and never stage a file you did not change.
- Never run a full test suite.
- Report faithfully: if a check was skipped or a test still fails, say so with the
  output, in the PR body as well as in chat. Never claim green CI you did not
  observe.
