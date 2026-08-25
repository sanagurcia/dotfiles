# Ticket intake, and planning together

Two halves. **Intake** applies to every skill. **Planning together** applies
only to the skills that plan with the user at the keyboard — an autonomous skill
does the same thinking without the exchanges, and says so where it cites this
file.

## Intake

If the user pasted a ticket and context, read it and move on. If they gave only
an ID or a URL, gather first:

1. `mcp__claude_ai_Linear__get_issue` (`id`, accepts `SER-156`), then
   `mcp__claude_ai_Linear__list_comments` (`issueId`) — the real requirement is
   often in a comment, not the description. The MCP prefix is per-machine; if
   that name is missing, find it with `ToolSearch("linear issue comments")`. If
   Linear is unreachable or no ID was given, use the pasted text and say so in
   the PR body.
2. Extract, in writing: **the user-visible outcome**, **the acceptance
   criteria**, and **what is explicitly out of scope**.
3. Locate the code. `Explore` sub-agents are for breadth — 2–4 in a single
   message, one per angle (UI entry point, data layer, existing tests, similar
   prior art), each asked for `file:line` conclusions rather than file dumps.
   For a ticket in a subsystem you can name, read the files directly instead: it
   is faster, and you will need the detail when you plan.
4. Read the narrowest docs entrypoint that applies: root `AGENTS.md`, then
   `apps/<app>/CLAUDE.md`, then the package's. Check `.claude/skills/` for a
   skill that already covers this exact task — if one exists, follow it instead
   of improvising (`table-creator`, `electric-migrator`, `icon-creator`,
   `schema-mapper`, `pdf-markup`, `stripe`, `room-scan`, …).

**Scope check.** Block only for a genuine product decision, or a ticket far
larger than it looked (a schema migration *plus* cross-app changes). Undefined
acceptance criteria are not automatically blocking: if a careful colleague would
pick a reading, pick it and record it under **Assumptions** in the PR body.

## State of play

Before proposing anything, report in a few paragraphs:

- **What exists today**, with `file:line` anchors. Name the components and the
  data path, not just the feature.
- **What the ticket actually requires**, separated from what it merely implies.
- **What you found that the ticket does not mention** — the constraint that will
  shape the design, the thing already half-built, the assumption in the ticket
  that the code contradicts.

That last one is the point. A ticket saying "remove the box" may rest on a data
model that makes the obvious replacement impossible; say so now, not once the
work is half-built.

Then **ask for what only the user has**: the product intent behind a thin
ticket, which of two readings they meant, what they have already tried. Ask in
prose, not `AskUserQuestion` — this is a conversation, and a menu interrupts it.

## Planning together

**Short exchanges.** A few paragraphs at a time, ending in a real question.
Never open with a finished plan — the point is to find the design together.

- **Propose two or three approaches, not one — and keep them at bird's-eye
  level.** Each is a shape: what the design *is*, and its one real trade-off.
  Never file lists, function names or line counts; granularity here forces a
  decision about implementation before the shape is settled, and it buries the
  comparison. Say which you would pick and why. The user's rejections are the
  most valuable signal in this phase.
- **Bring costs early.** "This touches a component with 48 callers" changes a
  design decision; discovering it after the work is written wastes it.
- **Push back once, then commit.** If they choose an approach you argued
  against, say your piece in a sentence and build their version properly.
- **Re-plan when a decision invalidates the shape.** Cheaper than forcing the
  old plan around the new constraint.

## The plan

When the user says **"ok plan"** (or equivalent), write it. Write it to the
session scratchpad directory named in your environment, **never into the repo**:
`.scratch/` is not gitignored here, and `plans/` and `openspec/` are tracked.

Explicit means *decided*, not *granular*: what changes and why, in the language
of the design. No file lists — the user is approving a shape, and a paragraph of
paths is something only you can check.

- **What changes semantically**, area by area: the data model, the write path,
  what the user ends up seeing. Name a file only where it *is* the decision — a
  shared component with many callers, a migration.
- **A proposed series of commits**, when the work splits cleanly. Each commit
  should be independently reviewable and independently revertable, and land in
  an order where each one leaves the tree coherent. Schema and backend before
  the UI that consumes them.
- **The test strategy**: which tests are written first, at which seam.
- Assumptions you made, and what would falsify each.
- What is deliberately out of scope.

Wait for approval of the plan too. What happens on approval — a branch, a
worktree, a licence to run to the end — belongs to the citing skill.
