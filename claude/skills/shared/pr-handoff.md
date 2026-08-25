# The PR is the handoff

**The chat is not persisted; the PR description is.** Whatever the user needs
later — how to test it, what you assumed, what you touched outside the ticket's
domain, which check is still red — lives in the body or is effectively lost.
The final chat message is a pointer to it, never the place the information
first appears.

## Blast radius — where the CROSS DOMAIN section comes from

Before the checks run, audit what the work touches **outside the ticket's
domain**, from the diff and not from memory:

```bash
git diff --name-only origin/main...HEAD | grep -vE "<domain pattern>"
```

For every file that comes back, establish whether shared callers actually change
behaviour — a modified shared component whose new branch is gated behind a prop
nobody else passes is inert, and saying so is worth more than listing the file.
That verdict is what goes in the body's CROSS DOMAIN section, per the user's
global rules.

## Commit hygiene

- Conventional Commit subjects, in logical chunks.
- **Stage by explicit path — never `git add -A` or `git add .`.** Unrelated
  untracked files at the repo root would otherwise land in the PR and blow
  `PR Size Check`.
- Never stage the plan file or anything else from the scratchpad.
- Amend only while the branch is unpushed. Once pushed, a fix is a new commit —
  never a force-push of a branch someone may be reading.
- Never commit to `main`.

## Opening it

1. **`git push -u origin <branch>` first.** `gh pr create` on a branch with no
   upstream prompts or fails, and a prompt stalls an unattended run.
2. Follow `AGENTS.md`'s PR standards: the whole template from disk verbatim, a
   Conventional Commits title, `Resolves <TICKET>`.
3. **Exactly one core preview label, and it is not a guess.** `preview:web`
   deploys the frontend against the *shared staging backends*, so a schema or
   API change previewed under it is tested against a backend that does not have
   it. If you ran `autarc-db`, or the diff touches `apps/api/**`,
   `apps/supabase/**` or the Ory/Hydra config, the label is
   `preview:staging-full`.
4. **Ready for review, not a draft.** `check-pr.yml` skips drafts, so a draft
   produces no CI at all.

## The body

Keep the template's own sections verbatim and fill them like this:

```markdown
## Description

<2-4 lines: what changed and why, against the ticket's acceptance criteria>

### How to test

1. <navigate to X>
2. <do Y>
3. <expect Z>

### Assumptions — need your review

- <assumption>: chose <reading> because <reason>. Wrong if <condition>.
- <none, if you made none — say so explicitly>

### CROSS DOMAIN

- <file/component outside the ticket's domain>: <whether shared callers actually
  change behaviour>
- <none, if the diff stayed inside its domain>

### Out of scope / still red

- <deliberately left out, and why>
- <any check skipped, or failing and baselined to main, with the output>

## Release notes summary

<one non-technical line, or omit the section entirely>

Resolves SER-156
```

**How to test carries the most weight where no hands-on pass happened** — every
acceptance criterion gets a click path, against the preview if the PR has one
and against local dev if it does not. There is no "how to test" section in the
template and you cannot record a screencast, so the free-form fields have to
carry it.

Leave the `Screencast/Screenshots` section's heading and drop its placeholder
comment. Never flag it to the user — recording one is their call, not yours.

Tick only the checklist items that actually apply.

## Never merge

"Merge-ready" means open, green, reviewed, labelled. Merging is the user's.
