# Working unattended

For the stretch of a session where nobody is watching: no approval between
phases, no progress prose, no "want me to continue?".

## The bar for interrupting

**Blocking question only** — proceeding would be unsafe, destructive, or would
produce work that is useless if the assumption is wrong. Send
`PushNotification`, then `AskUserQuestion` with concrete options and a
recommendation first.

The bar is high on purpose. An unattended run may be detached from any terminal,
so a blocked one stalls until the user comes back — possibly hours. A PR built on
a documented assumption is reviewable in their pass and cheap to redirect; a
stalled run costs them the morning. When in doubt, pick, write it under
**Assumptions** in the PR body, and keep going.

Ambiguity resolvable by reading code, git history, or the ticket is **not**
blocking. A question that arises mid-work and turns out not to block: answer it
yourself, fold it in, mention it in the PR body.

Never interrupt for: phase transitions, "plan is ready", failing tests you can
fix, review feedback you can handle, CI you can re-run.

`PushNotification` takes `{status: "proactive", message: "<200 chars"}`. It is
suppressed when the user is already at the terminal — a "not sent" result is
expected, and it is why the final message must repeat anything the ping carried.

## Progress reporting

`TaskCreate` one task per phase, then `TaskUpdate` exactly one to `in_progress`
at a time. The task list *is* the progress report — do not also narrate phases in
prose.

## Fable review

Nobody reviewed the code as it landed, so review it before the PR. Launch one
review agent on the Fable model. `run_in_background: false` is not an accepted
`Agent` parameter — passing it fails input validation. The agent may run in the
background; wait for its completion notification. Never use
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

Where the user approved a plan, paste its decisions in and add a third axis:
**does the diff match the plan that was approved?** A drift the reviewer catches
is cheaper than one the user finds in the diff tomorrow.

Sub-agents see a smaller tool surface than you do — a reviewer reporting that a
tool "does not exist" is describing its own sandbox, not the repo. Verify that
claim yourself before acting on it.

## Handling its feedback

For each finding: fix it, or write one line saying why it does not apply. Never
silently drop one.

Re-run the scoped type-check and targeted tests after fixing. If the fixes were
substantial (new files or changed logic — not typo/copy edits), run the review
once more. **Cap at two rounds** — if round two still surfaces a severe finding
you cannot resolve, that is a blocking question.
