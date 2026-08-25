# Worktree — create, provision, work in, tear down

For skills that deliver without the user's dev environment in the loop. A skill
whose whole point is the user testing by hand runs in the main checkout instead
and does not cite this file.

## Create

**Never work in the checkout you were invoked from, and never via worktrunk
(`wt switch --create`)**, which provisions the full environment (services +
tailnet) you do not need.

Get the branch name first: `get_issue` returns Linear's canonical one, otherwise
`<author>/<ticket-slug>`, e.g. `santiago/ser-156-short-slug`. Then, from the
repo root:

```bash
git fetch origin
git worktree add ../<ticket-slug> -b <branch> origin/main
```

Everything from here runs in that directory — pass it as `cwd`, or `cd` into it
in every command, and confirm with `git rev-parse --show-toplevel` before
editing anything. Every later step — checks, commits, the push, `gh pr create` —
runs there too; **never drift back to the original checkout**, which may be a
live tree the user is sitting in.

`git status` after creating it: a fresh worktree starts clean, so anything dirty
is yours.

## Provision, least-first

A fresh worktree has no `node_modules` and no built shared packages, so nothing
can run until:

```bash
autarc-prep     # pnpm install + pnpm lib:build
```

That is everything type-checking, linting and unit tests need — the rest of a
setup pass is about *running* the stack, which the checks never touch. It needs
no secrets, so it cannot stall on a 1Password session. api-v2's integration
tests skip themselves without a database, so `make test` stays green here.

**One** escalation exists, for a migration or an integration test that hits the
database:

```bash
autarc-db       # setup pass + slim supabase start + pnpm db:push
```

It runs the provisioning pass itself (`pnpm energy setup --no-services
--no-tailscale`), so it replaces `autarc-prep` rather than stacking on it: port
slot claimed, env files rendered, URLs on localhost. Unattended in Coder, where
`OP_SERVICE_ACCOUNT_TOKEN` renders the env files with no prompt; anywhere else
check `op whoami` first and treat a failure as a blocking question
(`op signin --account autarc`). It prints the `SUPABASE_CONNECTION_STRING` to
export for the Go tests, and its `pnpm db:push` is itself the check that the
migration applies.

**Those two scripts are the whole ladder — stop there.** Never run `autarc-up`,
`autarc-dev`, `autarc-stop`, a bare `pnpm energy setup`, or `pnpm services up`.
They bring up the service stack (Electric, NATS, Hydra, Temporal), re-seed
Hydra, import a 30k-row product catalog and claim the tailnet — none of which
any check touches. `autarc-dev` and `autarc-stop` additionally assume the main
checkout and would sweep its ports, killing servers outside this worktree.

Read this worktree's ports from `.worktree/ports.env` (`WT_*_PORT`) — the
defaults (5173/3000/8080/54322) belong to the main checkout.

Note that `pnpm db:gen-types` already rebuilds type-library, so no separate
`pnpm lib:build` after it.

## Sub-agents share this worktree

Fan out on **independent work units only** — chunks touching disjoint files;
units sharing a file are one unit. One `Agent` per unit
(`subagent_type: "general-purpose"`), all launched in a single message. Give
each: the ticket outcome, its own file list, the conventions it must follow, an
instruction to return a `file:line` summary, and — verbatim — the prohibition
below. Sub-agents never read a skill file; `AGENTS.md`, which they do read, tells
them to commit and to run `db:push`, so without the prohibition they will. Wait
for every completion notification before the fan-in.

**Prohibition to paste into every sub-agent prompt:**

> Do not run any `git` command (no staging, no commits, no branch changes). Do
> not run `pnpm db:push`, `pnpm db:gen-types`, `pnpm lib:build`, or `pnpm energy
> setup`. Edit only the files listed above. Report what you changed; the
> orchestrator runs the checks and commits.

Those commands, and any shared-file edit, are yours to do sequentially in the
main thread — sub-agents all share this one worktree and its single dev
environment, and concurrent runs corrupt each other. Do not give a sub-agent
`isolation: "worktree"`: its edits would land in a different tree on a different
branch, and never reach the PR.

**After the fan-in, run the checks yourself** — sub-agent claims are not
evidence.

## Tear down — only when the citing skill says to

A skill that expects the user to read the diff locally keeps the worktree and
names its path in the final message. Tear down only where the skill says so, and
do it *before* the final report so the report is the last thing that happens.

1. **Only if you ran `autarc-db`**, drop that slot's containers and data — from
   inside the worktree, so it targets this slot's project
   (`autarc-supabase-s<N>`) and not the main checkout:

   ```bash
   pnpm services down --volumes
   ```

   `--volumes` belongs here and nowhere else: the slot is disposable, and
   without it the volumes outlive the worktree. **Never run it in the main
   checkout** — there it deletes the real local database.

2. Remove the worktree, database or not. Run this from the main checkout: git
   refuses to remove the worktree you are standing in.

   ```bash
   cd <main-checkout> && git worktree remove <worktree-path> --force
   git worktree prune
   ```

   Leave the branch alone — it is pushed, and the PR points at it.
