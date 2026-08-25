---
name: focus
description: Work one ticket interactively — plan it together, land it commit by commit with a review pause after each, and run every check only at the end so focus time is never spent waiting. Use this skill when the user runs /focus with a ticket ID, a ticket URL, or pasted ticket text, and wants to shape the work as it happens. Do not use it for autonomous delivery — that is /ship, or /plan-ship if they want to shape the plan first.
argument-hint: "<ticket-id | ticket-url | pasted ticket text + any extra context>"
disable-model-invocation: true
---

# Focus

One ticket, worked **with** the user rather than for them. They are at the
keyboard for the whole session: they shape the plan, review every commit, and
test by hand before anything is pushed.

This skill's one hard rule — the reason it exists — is that **nothing slow runs
while the user is in flow**. Test suites, lint and Go builds all wait until
Phase 5. A three-minute wait is nothing on its own and ruinous eight times an
hour.

Its siblings: `ship` delivers a ticket end to end with no check-ins at all;
`plan-ship` plans with the user and then runs off. If the user does not want to
review every commit, they want one of those.

## Working context

**The main checkout. No worktree, ever.** Everything runs in the checkout you
were invoked from, against the user's real local dev environment and their real
local database. `shared/worktree.md` therefore does not apply to this skill: no
`autarc-prep`, no `autarc-db`, no `.worktree/ports.env`. The environment is
already provisioned and the user is already running it — assume their dev server
and Storybook are up rather than starting your own.

**The local database is disposable — offer to reset it.** `pnpm db:reset`
rebuilds it from the migrations and the seed, and the user is happy to run it
whenever asked. Proposing it is encouraged rather than tolerated: local drift is
the expensive failure here, because a database carrying migrations from an
abandoned branch makes every later result untrustworthy.

## Phase 0 — Ticket and state of play

Follow `~/.claude/skills/shared/ticket-and-plan.md`, **Intake** and **State of
play**. For a ticket in a subsystem you can name, read the files directly rather
than fanning out `Explore` agents — it is faster and you will need the detail in
Phase 1.

## Phase 1 — Plan, together

Follow the same file's **Planning together** and **The plan** sections. Then,
and only then, create the branch — here, in the main checkout:

```bash
git status                      # must be clean; if not, ask before touching it
git fetch origin && git checkout -b <branch> origin/main
```

Branch name: Linear's canonical one from `get_issue`, else
`<author>/<ticket-slug>`.

## Phase 2 — Commit by commit

For each commit in the plan:

1. Build it. Tests first where `AGENTS.md` requires them — writing a test is not
   running a suite, and it is what makes Phase 5 cheap.
2. **Type-check, and nothing else.** Scoped to what you touched:
   `pnpm turbo check-types -F @autarc/web -F @autarc/ui-library`, or `make build`
   for Go. It takes seconds and it is the one failure that is expensive to defer —
   a commit that does not compile has to be amended after review rather than
   fixed at the end.

   **No linting and no tests, at any point in this phase.** Not scoped, not "just
   this one file". That is Phase 5's job and the whole reason this skill exists.
3. Report what landed in a few lines — what changed, and any judgement call you
   made inside it — then **stop and wait**.
4. Iterate on their feedback until they move you on. Fixes to an
   already-reviewed commit are **amended into it** while the branch is unpushed;
   nothing is shared yet, so a tidy series costs nothing.
5. Commit per `~/.claude/skills/shared/pr-handoff.md`'s **Commit hygiene**.

**Do not run ahead.** Finishing commit 2 while they are still reading commit 1
throws away the review.

If the work turns out to need a commit the plan does not have, say so and get
agreement before writing it.

## Phase 3 — Their manual pass

When the series is done, hand over for hands-on testing. This is not "please
test" — give them the shortest path to seeing it:

- **Seed the state.** If the feature needs a record in a particular condition,
  put it there. Write toggle scripts to the session scratchpad and give the exact
  command to run each. Show the resulting state so they can trust it.
- **A short list of what to look at**, in the order it will appear on screen,
  including the cases that are easy to miss.
- **Name what you changed by hand versus through the app**, so they know which
  paths are actually exercised. A row written with `psql` fires no events.

Then wait. Fix what they find, same review loop as Phase 2.

## Phase 4 — Blast radius

Follow `~/.claude/skills/shared/pr-handoff.md`'s **Blast radius** section. Report
the verdict in chat with a `CROSS DOMAIN:` prefix as well as in the PR body — the
user is here, and it may change what they want built.

## Phase 5 — Now run everything

Only here. Follow `~/.claude/skills/shared/checks.md` end to end, in its order,
one at a time. Fix everything that fails.

## Phase 6 — PR

**Only on the user's explicit go.** They have been reviewing all session; do not
assume the last "looks good" was about the PR.

Follow `~/.claude/skills/shared/pr-handoff.md`. The user has already tested by
hand, so **How to test** is a short confirmation path rather than a full script —
but it still goes in the body, because the session that produced it will not
survive the week.

## Guardrails

- Never run a full test suite, at any phase — `--changed` or an explicit path.
- Never run lint or tests before Phase 5. Type-check is the only exception.
- Never push or open a PR without explicit approval.
- Never run ahead of the user's review.
- Report faithfully. A skipped check is a skipped check.
