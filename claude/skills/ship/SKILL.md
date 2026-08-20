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

Argument: a ticket ID (`COR-4919`, `HEAT-1834`, `UK-568`), a ticket URL, or pasted
ticket text.

## The only two reasons to interrupt

1. **Blocking question** — proceeding under any assumption would produce work that
   is unsafe or useless if the assumption is wrong. Send `PushNotification`, then
   `AskUserQuestion` with concrete options and a recommendation first.
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
2. `git status` first. If the tree is dirty, leave every pre-existing change
   alone and note it in the PR body — this checkout routinely has large untracked
   files at the root.
3. Confirm you are not on `main`. If you are, `git fetch origin` and branch from
   `origin/main`. Name the branch the way this repo does — `<author>/<ticket-slug>`,
   e.g. `isak/cor-4919-short-slug`; `get_issue` returns Linear's canonical branch
   name, so prefer that.
4. If `.worktree/ports.env` is missing, run `pnpm energy setup` before anything
   that touches the dev environment or the database.

## Phase 1 — Understand

1. Fetch the ticket with the Linear MCP: `mcp__claude_ai_Linear__get_issue`
   (`id`, accepts `COR-4919`), then `mcp__claude_ai_Linear__list_comments`
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

**Scope check.** If the ticket needs a schema migration plus cross-app changes, or
the acceptance criteria are genuinely undefined, or it requires a product
decision, that is a blocking question. Notify once with what you found, and stop.

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
  main thread — sub-agents share one working tree and one dev environment, and
  concurrent runs corrupt each other. Do not use `isolation: "worktree"`: a fresh
  worktree has no provisioned dev environment, so its checks cannot run.
- **After the fan-in, run `AGENTS.md`'s scoped checks yourself** — sub-agent claims
  are not evidence. Two things that section leaves implicit: `pnpm db:push` needs
  `pnpm db:start` first, and `pnpm db:gen-types` already rebuilds type-library, so
  no separate `pnpm lib:build`.
- Translations: `id-ID` is excluded because it is Crowdin's in-context
  pseudo-language (`crwdns…` markers), not a real locale — never hand-write keys
  into it, in `apps/web/src/locales/` or the ui-library's shared locales.
- Fix failures yourself. A red test is not a blocking question.
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

In parallel, run the `code-review` skill if it is available in this session, and
`security-review` when the diff touches auth, payments, or data access. Both are
machine-level, not checked into this repo — if a `Skill` call for them fails, note
it and continue rather than stalling.

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
   Conventional Commits title, exactly one core preview label. Add
   `Resolves <TICKET-ID>` and your Phase 2 assumptions to the body.
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

When the link resolves, send exactly one notification:

```
PushNotification({
  status: "proactive",
  message: "COR-4919 ready to test: https://pr-1234-autarc-pro-staging.autarc.workers.dev — PR #1234, CI green"
})
```

Then, in the final message, in this order:

1. The preview link.
2. What now works, in concrete terms the user can click through.
3. Assumptions you made and anything left out of scope.
4. One concrete next action.

## Guardrails

- Never merge. "Merge-ready" means open, green, reviewed, labelled.
- Never force-push a shared branch. Never commit to `main`.
- Never `git add -A`/`git add .`, and never stage a file you did not change.
- Never `git add` the plan file or anything else from the scratchpad.
- Report faithfully: if a check was skipped or a test still fails, say so with the
  output. Never claim green CI you did not observe.
