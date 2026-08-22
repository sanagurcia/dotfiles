---
name: ship
description: Take one small-to-medium ticket from start to merge-ready PR without check-ins — understand, plan, implement with sub-agents, review with a Fable sub-agent, handle the feedback, open the PR, and wait for the preview link. Use this skill when the user runs /ship with a ticket ID, a ticket URL, or pasted ticket text, and explicitly wants the whole ticket delivered autonomously. Do not use it for exploratory work, for tickets needing a product decision, or when the user wants to review a plan first.
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

## The only two reasons to interrupt

1. **Blocking question** — proceeding would be unsafe, destructive, or would
   produce work that is useless if the assumption is wrong. Send
   `PushNotification`, then `AskUserQuestion` with concrete options and a
   recommendation first.

   The bar is high on purpose: this runs in a detached tmux session, so a
   blocked run stalls until the user reattaches — possibly hours. A PR built on
   a documented assumption is reviewable in their GitHub pass and cheap to
   redirect; a stalled run costs them the morning. When in doubt, pick, write it
   under **Assumptions** in the PR body, and keep going.
2. **Preview link ready** — one `PushNotification` carrying the preview URL.

`PushNotification` takes `{status: "proactive", message: "<200 chars"}`. It is
suppressed when the user is already at the terminal — a "not sent" result is
expected, and it is why the final message must repeat the link rather than rely
on the ping.

Everything else is yours to decide. Ambiguity resolvable by reading code, git
history, or the ticket is **not** blocking — pick the reading a careful colleague
would, record the assumption in the PR description, and continue. A question that
arises mid-work and turns out not to block: answer it yourself, fold it in,
mention it in the PR body.

Never interrupt for: phase transitions, "plan is ready", failing tests you can
fix, review feedback you can handle, CI you can re-run.

## Phase 0 — Preflight

1. `TaskCreate` one task per phase below, then `TaskUpdate` exactly one to
   `in_progress` at a time. The task list is the progress report — do not also
   narrate phases in prose.
2. **Always work in a new git worktree — never in the checkout you were invoked
   from, and never via worktrunk (`wt switch --create`), which provisions the
   full environment (services + tailnet) you do not need.** Get the branch name
   first: `get_issue` returns Linear's canonical one, otherwise
   `<author>/<ticket-slug>`, e.g. `santiago/ser-156-short-slug`. Then, from the
   repo root:

   ```bash
   git fetch origin
   git worktree add ../<ticket-slug> -b <branch> origin/main
   ```

   Everything from here runs in that directory — pass it as `cwd`, or `cd` into it
   in every command, and confirm with `git rev-parse --show-toplevel` before editing
   anything. Every later phase — checks, commits, the push, `gh pr create` — runs
   there too; never drift back to the original checkout.
3. **Provision the worktree, least-first.** A fresh worktree has no
   `node_modules` and no built shared packages, so nothing can run until:

   ```bash
   autarc-prep     # pnpm install + pnpm lib:build
   ```

   That is everything type-checking, linting and unit tests need — the rest of a
   setup pass is about *running* the stack, which the checks never touch. It
   needs no secrets, so it cannot stall on a 1Password session. api-v2's
   integration tests skip themselves without a database, so `make test` stays
   green here.

   **One** escalation exists, for a migration or an integration test that hits
   the database:

   ```bash
   autarc-db       # setup pass + slim supabase start + pnpm db:push
   ```

   It runs the provisioning pass itself (`pnpm energy setup --no-services
   --no-tailscale`), so it replaces `autarc-prep` rather than stacking on it:
   port slot claimed, env files rendered, URLs on localhost. Unattended in
   Coder, where `OP_SERVICE_ACCOUNT_TOKEN` renders the env files with no
   prompt; anywhere else check `op whoami` first and treat a failure as a
   blocking question (`op signin --account autarc`). It prints the
   `SUPABASE_CONNECTION_STRING` to export for the Go tests, and its
   `pnpm db:push` is itself the check that the migration applies.

   **Those two scripts are the whole ladder — stop there.** Never run
   `autarc-up`, `autarc-dev`, `autarc-stop`, a bare `pnpm energy setup`, or
   `pnpm services up`. They bring up the service stack (Electric, NATS, Hydra,
   Temporal), re-seed Hydra, import a 30k-row product catalog and claim the
   tailnet — none of which any check touches. `autarc-dev` and `autarc-stop`
   additionally assume the main checkout and would sweep its ports, killing
   servers outside this worktree.

   Read this worktree's ports from `.worktree/ports.env` (`WT_*_PORT`) — the
   defaults (5173/3000/8080/54322) belong to the main checkout.
4. `git status`. A fresh worktree starts clean, so anything dirty is yours.

## Phase 1 — Understand

1. Fetch the ticket with the Linear MCP: `mcp__claude_ai_Linear__get_issue`
   (`id`, accepts `SER-156`), then `mcp__claude_ai_Linear__list_comments`
   (`issueId`) — the real requirement is often in a comment, not the description.
   The MCP prefix is per-machine; if that name is missing, find it with
   `ToolSearch("linear issue comments")`. If Linear is unreachable or no ID was
   given, use the pasted text and say so in the PR body.
2. Extract, in writing: **the user-visible outcome**, **the acceptance criteria**,
   and **what is explicitly out of scope**.
3. Locate the code with 2–4 parallel `Explore` sub-agents, one per angle (UI entry
   point, data layer, existing tests, similar prior art), all launched in a single
   message. Ask each for `file:line` conclusions, not file dumps.
4. Read the narrowest docs entrypoint that applies: root `AGENTS.md`, then
   `apps/<app>/CLAUDE.md`, then the package's. Check `.claude/skills/` for a skill
   that already covers this exact task — if one exists, follow it instead of
   improvising (`table-creator`, `electric-migrator`, `icon-creator`,
   `schema-mapper`, `pdf-markup`, `stripe`, `room-scan`, …).

**Scope check.** Block only for a genuine product decision, or a ticket far
larger than it looked (a schema migration *plus* cross-app changes). Undefined
acceptance criteria are not automatically blocking: if a careful colleague would
pick a reading, pick it, record it under **Assumptions** in the PR body, and
continue. When you do block, notify once with what you found, and stop.

## Phase 2 — Plan

Write the plan to the session scratchpad directory named in your environment,
never into the repo. `.scratch/` is **not** gitignored here, and `plans/` and
`openspec/` are tracked; do not add a working file to either. No approval needed.

The plan contains:

- Files to touch, with the change per file in one line each.
- The test strategy: which tests are written first, at which seam.
- The verification commands, scoped to what you touch.
- Assumptions you made, and what would falsify each.
- Anything deliberately left out of scope.

Then split the plan into **independent work units** — chunks touching disjoint
files. Units sharing a file are one unit.

## Phase 3 — Implement

- **Tests first**, per `AGENTS.md` — including its mandatory integration tests for
  new API endpoints. Touching Go means reading `apps/api/api-v2/CLAUDE.md` first.
- **Fan out on independent units only.** One `Agent` per unit
  (`subagent_type: "general-purpose"`), all launched in a single message. Give
  each: the ticket outcome, its own file list, the conventions it must follow, an
  instruction to return a `file:line` summary, and — verbatim — the prohibition
  below. Sub-agents never read this skill; `AGENTS.md`, which they do read, tells
  them to commit and to run `db:push`, so without the prohibition they will. Wait
  for every completion notification before the fan-in.
- **Prohibition to paste into every sub-agent prompt:** "Do not run any `git`
  command (no staging, no commits, no branch changes). Do not run `pnpm db:push`,
  `pnpm db:gen-types`, `pnpm lib:build`, or `pnpm energy setup`. Edit only the
  files listed above. Report what you changed; the orchestrator runs the checks
  and commits."
- Those commands, and any shared-file edit, are yours to do sequentially in the
  main thread — sub-agents all share your Phase 0 worktree and its single dev
  environment, and concurrent runs corrupt each other. Do not give a sub-agent
  `isolation: "worktree"`: its edits would land in a different tree on a different
  branch, and never reach your PR.
- **After the fan-in, run `AGENTS.md`'s scoped checks yourself** — sub-agent claims
  are not evidence. Two things that section leaves implicit: `autarc-db`
  covers `db:start` + `db:push` in one step, and `pnpm db:gen-types` already
  rebuilds type-library, so no separate `pnpm lib:build`.
- Translations: `id-ID` is excluded because it is Crowdin's in-context
  pseudo-language (`crwdns…` markers), not a real locale — never hand-write keys
  into it, in `apps/web/src/locales/` or the ui-library's shared locales.
- Fix failures yourself. A red test is not a blocking question.
- **Run targeted tests, never the full suite** — `go test ./internal/<pkg>/...`
  or `-run <TestName>`, `pnpm turbo test -F <package>`. The Go suite is 767 test
  files and most of it has nothing to do with your ticket.
- **A failure you did not cause is out of scope.** `autarc-db` makes 78
  `*_integration_test.go` files runnable that skip without a database and never
  run in CI (`check-go.yml` sets no `SUPABASE_CONNECTION_STRING`), so some are
  stale. Baseline any suspicious failure against `origin/main`; if it predates
  your change, note it in the PR body and move on. Repairing the codebase is not
  this skill's job, and a stale assertion is not yours to "fix".
- Commit in logical chunks with Conventional Commit subjects. **Stage by explicit
  path — never `git add -A` or `git add .`.** Unrelated untracked files at the
  repo root would otherwise land in the PR and blow `PR Size Check`.

## Phase 4 — Fable review

Launch one review agent on the Fable model. `run_in_background: false` is not an
accepted `Agent` parameter — passing it fails input validation. The agent may run
in the background; wait for its completion notification before Phase 5. Never use
`subagent_type: "fork"` here: a fork ignores `model` and would inherit yours.

```
Agent({
  subagent_type: "general-purpose",
  model: "fable",
  description: "Review ticket implementation",
  prompt: "<ticket outcome + acceptance criteria> ... Review `git diff <base>...HEAD`
           on two axes: (1) does it actually satisfy the acceptance criteria,
           (2) does it follow this repo's documented standards (read AGENTS.md and
           the relevant apps/<app>/CLAUDE.md). Report findings ranked most-severe
           first, each with file:line and a concrete failure scenario. Say plainly
           if you find nothing. Do not edit files."
})
```

Sub-agents see a smaller tool surface than you do — a reviewer reporting that a
tool "does not exist" is describing its own sandbox, not the repo. Verify that
claim yourself before acting on it.

## Phase 5 — Handle feedback

For each finding: fix it, or write one line saying why it does not apply. Never
silently drop one.

Re-run the scoped checks after fixing. If the fixes were substantial (new files or
changed logic — not typo/copy edits), run the Fable review once more. **Cap at two
rounds** — if round two still surfaces a severe finding you cannot resolve, that is
a blocking question.

## Phase 6 — Open the PR

1. `git push -u origin <branch>` **first**. `gh pr create` on a branch with no
   upstream prompts or fails, and a prompt stalls the whole autonomous run.
2. Follow `AGENTS.md`'s PR standards: whole template from disk verbatim,
   Conventional Commits title, exactly one core preview label.

   **The label is not a guess.** `preview:web` deploys the frontend against the
   *shared staging backends*, so a schema or API change previewed under it is
   tested against a backend that does not have it. If you ran `autarc-db`, or
   the diff touches `apps/api/**`, `apps/supabase/**` or the Ory/Hydra config,
   the label is `preview:staging-full`.

   **The PR body is the handoff.** The user reviews in the GitHub UI: they read
   the description, check CI, then click the preview and test by hand. The
   template has no "how to test" section and you cannot record a screencast, so
   the free-form fields have to carry it. Keep the template's own sections
   verbatim and fill them like this:

   ```markdown
   ## Description

   <2-4 lines: what changed and why, against the ticket's acceptance criteria>

   ### How to test in the preview

   1. <navigate to X>
   2. <do Y>
   3. <expect Z>

   ### Assumptions — need your review

   - <assumption>: chose <reading> because <reason>. Wrong if <condition>.
   - <none, if you made none — say so explicitly>

   ## Release notes summary

   <one non-technical line, or omit the section entirely>

   Resolves SER-156
   ```

   Drop the `Screencast/Screenshots` section rather than leaving its empty
   comment behind. Tick only the checklist items that actually apply.
3. Open the PR ready for review, not as a draft — `check-pr.yml` skips drafts, so
   a draft PR produces no CI to watch.
4. Watch CI in the background — `--watch` blocks longer than a foreground `Bash`
   call allows:

   ```bash
   gh pr checks <pr> --watch --fail-fast   # Bash with run_in_background: true
   ```

   **Cap the fix loop at three pushes.** Fix red checks yourself, and re-run a
   clearly unrelated infrastructure flake once. After the third attempt, stop and
   go to Phase 7 with the failing check named in the final message — grinding on
   an unfixable check strands a user who is not watching. `PR Size Check` failing
   means the ticket was too big for this skill — say so instead of splitting the
   PR unasked.

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

### Clean up before notifying

The PR is pushed, so the worktree is disposable. Tear it down *before* the
notification — on both paths, whether the preview link resolved or the wait
timed out — so the report is the last thing that happens.

1. **Only if you ran `autarc-db`**, drop that slot's containers and data — from
   inside the worktree, so it targets this slot's project (`autarc-supabase-s<N>`)
   and not the main checkout:

   ```bash
   pnpm services down --volumes
   ```

   `--volumes` belongs here and nowhere else: the slot is disposable, and
   without it the volumes outlive the worktree. **Never run it in the main
   checkout** — there it deletes the real local database.

2. **Always** remove the worktree, database or not. Run this from the main
   checkout: git refuses to remove the worktree you are standing in.

   ```bash
   cd <main-checkout> && git worktree remove <worktree-path> --force
   git worktree prune
   ```

   Leave the branch alone — it is pushed, and the PR points at it.

When the link resolves, send exactly one notification:

```
PushNotification({
  status: "proactive",
  message: "SER-156 ready to test: https://pr-1234-autarc-pro-staging.autarc.workers.dev — PR #1234, CI green"
})
```

Then, in the final message, in this order:

1. The preview link.
2. What now works, in concrete terms the user can click through.
3. Assumptions you made and anything left out of scope.
4. One concrete next action.

## Guardrails

- Never merge. "Merge-ready" means open, green, reviewed, labelled.
- Provisioning stops at `autarc-db`. Never run `autarc-up`, `autarc-dev`,
  `autarc-stop`, `pnpm services up`, or a bare `pnpm energy setup`.
- Never force-push a shared branch. Never commit to `main`.
- Never `git add -A`/`git add .`, and never stage a file you did not change.
- Never `git add` the plan file or anything else from the scratchpad.
- Report faithfully: if a check was skipped or a test still fails, say so with the
  output. Never claim green CI you did not observe.
