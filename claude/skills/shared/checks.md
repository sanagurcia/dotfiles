# Checks — the pre-PR gate

Every skill that opens a PR runs exactly this, in this order, and nothing
earlier. Each step's failures are cheapest to fix before the next one runs.

**Nothing here runs while the user is mid-flow.** In an interactive session
these all wait for the end; type-checking scoped to what you just touched is
the one exception, and it belongs to the implementation loop, not here.

1. **Rebase on main first**, and treat what it brings as suspect:

   ```bash
   git fetch origin && git rebase origin/main
   ```

   New migrations mean `pnpm db:push`; a rebase that moves generated types
   means regenerating them.

2. **Type-check**, scoped to what you touched:

   ```bash
   pnpm turbo check-types -F @autarc/web -F @autarc/ui-library
   ```

   `make build` for Go.

3. **Lint**, scoped the same way. `make lint` for Go.

4. **Tests — `--changed` only. Never a full suite, for any app or package.**

   ```bash
   pnpm --filter @autarc/web test --changed origin/main
   ```

   **The ref is not optional.** By this point the work is committed, and bare
   `--changed` means *uncommitted* changes — it would find nothing and pass
   vacuously, which reads exactly like success.

5. **Go tests**, package-scoped: `go test ./internal/<pkg>/`, or
   `-run <TestName>`. Integration tests skip without
   `SUPABASE_CONNECTION_STRING` — pass the local one, or they pass vacuously
   too. The Go suite is 767 test files and most of it has nothing to do with
   the ticket.

6. **React Doctor**, which comments on the PR and is entirely pre-emptable:

   ```bash
   pnpm doctor --scope changed --base origin/main
   ```

   `--scope changed` is what the bot reports: new issues versus the base, not
   the repo's existing debt.

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

   An error's fix is usually a real improvement — a compiler bailout, a
   component built during render — rather than appeasement.
   `pnpm doctor why <file>:<line>` explains one. If an error is genuinely wrong
   for the case, say why rather than suppressing it silently.

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

## Three rules that make the gate correct

**Run these one at a time.** `knip-diff-main`, and any baseline you take by
checking out another commit, move the working tree — so anything running
alongside them reads files from the wrong commit. A test suite caught mid-run
that way fails on exactly the lines you added, which reads like a real
regression and is not one. Background a check if it is slow, but never overlap
it with something that checks out a different ref.

**A failure you did not cause is out of scope.** Baseline it against
`origin/main`; if it predates the branch, record it and move on — and take that
baseline with the tree otherwise idle, for the same reason. `autarc-db` makes 78
`*_integration_test.go` files runnable that skip without a database and never
run in CI (`check-go.yml` sets no `SUPABASE_CONNECTION_STRING`), so some are
stale. Repairing the codebase is not the job, and a stale assertion is not
yours to "fix".

**Whatever you fix here goes in its own commit**, on top of the series — never
amended into the commit it belongs to. By this point the series may be pushed,
and amending means force-pushing a branch someone may already be reading. A
separate commit is also the honest record: the checks found something and it was
fixed, which is what happened.

**Report faithfully.** A skipped check is a skipped check; a test that still
fails is named, with its output, in the PR body.
