---
name: focus
description: Work one ticket interactively — plan it together, land it commit by commit with a review pause after each, and run every check only at the end so focus time is never spent waiting. Use this skill when the user runs /focus with a ticket ID, a ticket URL, or pasted ticket text, and wants to shape the work as it happens. Do not use it for autonomous delivery — that is /ship.
argument-hint: "<ticket-id | ticket-url | pasted ticket text + any extra context>"
disable-model-invocation: true
---

# Focus

One ticket, worked **with** the user rather than for them. They are at the
keyboard for the whole session: they shape the plan, review every commit, and
test by hand before anything is pushed.

This skill's one hard rule — the reason it exists — is that **nothing slow runs
while the user is in flow**. Test suites, lint and Go builds all wait until
Phase 6. A three-minute wait is nothing on its own and ruinous eight times an
hour.

`ship` is the opposite skill. If the user wants the ticket delivered without
check-ins, they want that one.

## Working context

**The main checkout. No worktree, ever.** Everything runs in the checkout you
were invoked from, against the user's real local dev environment and their real
local database.

Worktree-specific tooling therefore does not apply: no `autarc-prep`, no
`autarc-db`, no `.worktree/ports.env`. The environment is already provisioned and
the user is already running it — assume their dev server and Storybook are up
rather than starting your own.

**The local database is disposable — offer to reset it.** `pnpm db:reset`
rebuilds it from the migrations and the seed, and the user is happy to run it
whenever asked. Proposing it is encouraged rather than tolerated: local drift is
the expensive failure here, because a database carrying migrations from an
unmerged branch makes `pnpm db:gen-types` produce output that does not match CI,
and committing that output puts another branch's schema into this PR. At the
first sign of drift — a `db:push` that will not apply, generated types with hunks
you did not cause — say so and offer the reset. Prompt first every time; never
reset unasked.

## Phase 0 — Context

If the user pasted a ticket and context, read it and move on. If they gave only
an ID or a URL, gather first:

1. `mcp__claude_ai_Linear__get_issue`, then
   `mcp__claude_ai_Linear__list_comments` — the real requirement often lives in a
   comment. Find the tool with `ToolSearch("linear issue")` if the prefix differs.
2. Locate the code. `Explore` sub-agents are for breadth; for a ticket in a
   subsystem you can name, read the files directly — it is faster and you will
   need the detail in Phase 2 anyway.
3. Read the narrowest docs entrypoint: root `AGENTS.md`, then
   `apps/<app>/CLAUDE.md`, then the package's. Check `.claude/skills/` for a
   skill covering this exact task.

Then **ask for what only the user has**: the product intent behind a thin
ticket, which of two readings they meant, what they have already tried. Ask in
prose, not `AskUserQuestion` — this is a conversation, and a menu interrupts it.

## Phase 1 — State of play

Before proposing anything, report in a few paragraphs:

- **What exists today**, with `file:line` anchors. Name the components and the
  data path, not just the feature.
- **What the ticket actually requires**, separated from what it merely implies.
- **What you found that the ticket does not mention** — the constraint that will
  shape the design, the thing already half-built, the assumption in the ticket
  that the code contradicts.

That last one is the point of this phase. A ticket saying "remove the box" may
rest on a data model that makes the obvious replacement impossible; say so now,
not in Phase 3.

## Phase 2 — Plan, together

**Short exchanges.** A few paragraphs at a time, ending in a real question.
Never open with a finished plan — the point is to find the design together.

- **Propose two or three approaches, not one — and keep them at bird's-eye
  level.** Each is a shape: what the design *is*, and its one real trade-off.
  Never file lists, function names or line counts; granularity here forces a
  decision about implementation before the shape is settled, and it buries the
  comparison. Say which you would pick and why. The user's rejections are the
  most valuable signal in this phase.
- **Bring costs early.** "This touches a component with 48 callers" changes a
  design decision; discovering it in Phase 4 wastes the work.
- **Push back once, then commit.** If they choose an approach you argued
  against, say your piece in a sentence and build their version properly.
- **Re-plan when a decision invalidates the shape.** Cheaper than forcing the
  old plan around the new constraint.

When the user says **"ok plan"** (or equivalent), write the explicit plan.
Explicit means *decided*, not *granular*: what changes and why, in the language
of the design. Still no file lists — the user is approving a shape, and a
paragraph of paths is something only you can check.

- **What changes semantically**, area by area: the data model, the write path,
  what the user ends up seeing. Name a file only where it *is* the decision — a
  shared component with many callers, a migration.
- **A proposed series of commits**, when the work splits cleanly. Each commit
  should be independently reviewable and independently revertable, and land in
  an order where each one leaves the tree coherent. Schema and backend before
  the UI that consumes them.
- Assumptions, and what would falsify each.
- What is deliberately out of scope.

Wait for approval of that too. Then, and only then, create the branch:

```bash
git status                      # must be clean; if not, ask before touching it
git fetch origin && git checkout -b <branch> origin/main
```

Branch name: Linear's canonical one from `get_issue`, else
`<author>/<ticket-slug>`.

## Phase 3 — Commit by commit

For each commit in the plan:

1. Build it. Tests first where `AGENTS.md` requires them — writing a test is not
   running a suite, and it is what makes Phase 6 cheap.
2. **Type-check, and nothing else.** Scoped to what you touched:
   `pnpm turbo check-types -F @autarc/web -F @autarc/ui-library`, or `make build`
   for Go. It takes seconds and it is the one failure that is expensive to defer —
   a commit that does not compile has to be amended after review rather than
   fixed at the end.

   **No linting and no tests, at any point in this phase.** Not scoped, not "just
   this one file". That is Phase 6's job and the whole reason this skill exists.
3. Report what landed in a few lines — what changed, and any judgement call you
   made inside it — then **stop and wait**.
4. Iterate on their feedback until they move you on. Fixes to an
   already-reviewed commit are **amended into it** while the branch is unpushed;
   nothing is shared yet, so a tidy series costs nothing.
5. Commit with a Conventional Commit subject. Stage by explicit path.

**Do not run ahead.** Finishing commit 2 while they are still reading commit 1
throws away the review.

If the work turns out to need a commit the plan does not have, say so and get
agreement before writing it.

## Phase 4 — Their manual pass

When the series is done, hand over for hands-on testing. This is not "please
test" — give them the shortest path to seeing it:

- **Seed the state.** If the feature needs a record in a particular condition,
  put it there. Write toggle scripts to the session scratchpad and give the exact
  command to run each. Show the resulting state so they can trust it.
- **A short list of what to look at**, in the order it will appear on screen,
  including the cases that are easy to miss.
- **Name what you changed by hand versus through the app**, so they know which
  paths are actually exercised. A row written with `psql` fires no events.

Then wait. Fix what they find, same review loop as Phase 3.

## Phase 5 — Blast radius

Before any check runs, audit what this touches **outside the ticket's domain**,
from the diff and not from memory:

```bash
git diff --name-only origin/main...HEAD | grep -vE "<domain pattern>"
```

For every file that comes back, establish whether shared callers actually
change behaviour — a modified shared component whose new branch is gated behind
a prop nobody else passes is inert, and saying so is worth more than listing the
file. Report with a `CROSS DOMAIN:` prefix, per the user's global rules.

## Phase 6 — Now run everything

Only here. In this order, because each one's failures are cheapest to fix before
the next runs:

1. **Rebase on main first**, and treat what it brings as suspect:
   `git fetch origin && git rebase origin/main`. New migrations mean
   `pnpm db:push`; a rebase that moves generated types means regenerating them.
2. **Type-check**, scoped: `pnpm turbo check-types -F @autarc/web -F @autarc/ui-library`.
3. **Lint**, scoped the same way. `make lint` for Go.
4. **Tests — `--changed` only. Never a full suite, for any app or package.**
   Run in the background:

   ```bash
   pnpm --filter @autarc/web test --changed origin/main
   ```

   **The ref is not optional.** By this phase the work is committed, and bare
   `--changed` means *uncommitted* changes — it would find nothing and pass
   vacuously, which reads exactly like success.

5. **Go tests**, package-scoped: `go test ./internal/<pkg>/`. Integration tests
   skip without `SUPABASE_CONNECTION_STRING` — pass the local one, or they pass
   vacuously too.

6. **React Doctor**, which comments on the PR and is entirely pre-emptable:

   ```bash
   pnpm doctor --scope changed --base origin/main
   ```

   `--scope changed` is what the bot reports: new issues versus the base, not the
   repo's existing debt.

   **Fix the errors. Leave the warnings alone.** `react-doctor.yml` runs the
   action with no overrides, so it gates on `fail-on: error` — warnings are
   advisory, appear in the comment, and block nothing. Do not pass
   `--blocking warning`; it makes the run stricter than CI and turns advisory
   notes into work nobody asked for. Mention a warning in passing if it is
   telling you something true, and move on.

   **Use `pnpm doctor`, never `node_modules/.bin/react-doctor`.** The root
   `package.json` pins `react-doctor` to `^0.7.6` while CI runs latest, and the
   older binary silently finds fewer issues — it missed two of six on the run
   that prompted this. The `doctor` script is `npx react-doctor@latest` and
   forwards flags, so it tracks CI without a repo change.

   An error's fix is usually a real improvement — a compiler bailout, a component
   built during render — rather than appeasement. `pnpm doctor why <file>:<line>`
   explains one. If an error is genuinely wrong for the case, say why rather than
   suppressing it silently.

7. **Knip**, which also gates every PR and is also pre-emptable:

   ```bash
   knip-diff-main
   ```

   A bare `pnpm knip` proves nothing — `check-knip.yml` never gates on knip's
   own exit code. It runs knip twice, on the head and on the **merge base**, and
   fails only on findings the base did not already have. This repo has plenty of
   pre-existing ones and none of them fail the check.

   `knip-diff-main` reproduces that: two 7-second runs from the one checkout
   (no second install — the same `node_modules` serves both while the lockfile
   is unchanged), then the repo's own `.github/scripts/knip-diff.cjs`. It needs
   a clean tree, because the base run checks out another commit.

   **The base is the merge base, never the tip of main.** Diffing against the
   tip reports an export this branch does not use but a commit landed since the
   fork does — a finding about being behind main, not about your change.

**Run these one at a time.** `knip-diff-main`, and any baseline you take by
checking out another commit, move the working tree — so anything running
alongside them reads files from the wrong commit. A test suite caught mid-run
that way fails on exactly the lines you added, which reads like a real
regression and is not one. Background a check if it is slow, but never overlap
it with something that checks out a different ref.

Fix everything that fails. A failure predating your branch is not yours: baseline
it against `origin/main`, say so, move on — and take that baseline with the tree
otherwise idle, for the same reason.

**Whatever you fix here goes in its own commit**, on top of the series — never
amended into the commits it belongs to. Those are pushed by the time anything
here runs, so amending means force-pushing a branch someone may already be
reading. A separate commit is also the honest record: the checks found something
and it was fixed, which is what happened.

## Phase 7 — PR

**Only on the user's explicit go.** They have been reviewing all session; do not
assume the last "looks good" was about the PR.

Follow `AGENTS.md`'s PR standards: template from disk verbatim, Conventional
Commits title, `Resolves <TICKET>`, exactly one core preview label —
`preview:staging-full` if the diff touches `apps/api/**`, `apps/supabase/**` or
the Ory/Hydra config.

Push before `gh pr create`. Leave the Screencast section empty and say nothing
about it — the user records it or does not, and it is not yours to flag.

## Guardrails

- Never run a full test suite, at any phase — `--changed` or an explicit path.
- Never run lint or tests before Phase 6. Type-check is the only exception.
- Never push or open a PR without explicit approval.
- Never `git add -A` when the tree has files you did not touch.
- Never run ahead of the user's review.
- Report faithfully. A skipped check is a skipped check.
