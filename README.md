# dotfiles

Personal config for my two environments: a local macOS machine and a Coder
workspace (Debian). Both read the same files through symlinks, so a change
committed here reaches the other side with one command.

## Layout

| Repo file              | Symlinked to              | What it configures                  |
| ---------------------- | ------------------------- | ----------------------------------- |
| `gitconfig`            | `~/.gitconfig`            | identity, aliases, delta as pager   |
| `nanorc`               | `~/.nanorc`               | less-style navigation in nano       |
| `tmux.conf`            | `~/.tmux.conf`            | Ctrl+Space prefix                   |
| `zshrc`                | `~/.zshrc`                | zsh config (overlaid as `~/.zshrc.local` on Coder) |
| `claude/settings.json` | `~/.claude/settings.json` | Claude Code user settings           |
| `claude/CLAUDE.md`     | `~/.claude/CLAUDE.md`     | Claude Code user-level instructions |
| `claude/skills/`       | `~/.claude/skills/`       | Claude Code user-level skills       |
| `ripgreprc`            | `~/.ripgreprc`            | rg defaults, `src`/`tst` file types  |
| `batconfig`            | `~/.config/bat/config`    | bat follows the macOS light/dark setting |
| `bin/`                 | `~/.local/bin/`           | helper scripts (see below)           |

Files are stored without the leading dot; `setup.sh` adds it when linking.

## Install

Locally:

```bash
git clone git@github.com:sanagurcia/dotfiles.git ~/dotfiles
~/dotfiles/setup.sh
```

In a Coder workspace:

```bash
coder dotfiles -y git@github.com:sanagurcia/dotfiles.git
```

Coder clones into `~/.config/coderv2/dotfiles` (not `~/dotfiles`) and runs
`setup.sh` for you. `setup.sh` resolves its own location, so either path works.
Re-running the same command pulls the latest commit and re-links — that is also
how you update a workspace after pushing here. It is not run automatically on
workspace start; the symlinks simply persist on the home volume.

`dots` wraps whichever applies: pull and re-link locally, or re-run `coder
dotfiles` in a workspace. `exec zsh` afterwards to reload the shell config.

## Workspace rebuilds

The Coder workspace is a container. Only `/home/coder` is a persistent volume —
`/usr` and `/usr/local` come from the image and reset every rebuild, so anything
`apt install`ed by hand disappears while its config symlink survives and dangles.

So `setup.sh` installs nano, bat and fd under `~/.local/opt` and links them into
`~/.local/bin`, both on the persistent volume:

- **nano** — unpacked from its `.deb`. Safe, because its only dependencies
  (ncurses, libc) are in the image.
- **bat** — static musl build from upstream. The Debian package links `libgit2`,
  which the image lacks, so that dependency would vanish on rebuild and take bat
  with it.
- **fd** — static musl build. The image does ship fd, but a symlink into `/usr`
  is only as durable as the image's package list, so this owns it outright.

git-delta and fzf still come from the image.

Tradeoff: these are pinned and updated by hand, not by `apt upgrade`. Bump
`BAT_VERSION` or `FD_VERSION` in `setup.sh` and re-run — the version is part of
the install path, so a bump reinstalls. For nano, delete `~/.local/opt/nano`
first.

## Search helpers

`bin/` holds small scripts over `rg`, `fd`, `fzf` and `bat`, symlinked into
`~/.local/bin`. Run `scripts` to list them with their descriptions.

| Command | What it does                                                  |
| ------- | ------------------------------------------------------------- |
| `ff`    | find a file by name, pick it, view it                          |
| `fs`    | find a symbol's usages, pick one, view it                      |
| `defs`  | pick a declaration site interactively                          |
| `refs`  | which apps/packages a symbol appears in, plus total files      |
| `scripts` | list these commands                                          |

`_defs`, `_pick` and `_bat-at` are internals these build on, not meant to be
called directly. Symbol searches lean on the `src` and `tst` types defined in
`ripgreprc`, so they skip tests by default.

## Git helpers

| Command               | What it does                                          |
| --------------------- | ----------------------------------------------------- |
| `git review`          | browse this branch's diff as a tree                   |
| `git review -w`       | the same for the uncommitted changes                  |
| `git review -c [SHA]` | one commit of the branch, picked if none given        |
| `git review -v`       | include the tests and locale files, hidden by default |

`git review` is a `git-` prefixed script on `PATH`, which is all git needs to
offer it as a subcommand. `_base`, `_dpick`, `_ddiff`, `_dstat`, `_dtree` and
`_tree` are the internals it builds on. The branch is compared against origin's
default branch, not the local branch of the same name, which drifts behind.

Every mode opens a two-pane reviewer: the changed paths as a tree on the left,
that path's diff through `delta` on the right. Single-child directories fold
into one row, directories sort ahead of files, and the tree re-draws on resize.

Directories are selectable too, so picking one shows its whole subtree's diff.
Enter pages the current diff full-screen and returns to the tree on quit — Esc
is the way out. `ctrl-o` reads the picked file whole in `bat`: from the working
tree, or as it was in that commit under `-c`. `ctrl-l` toggles delta's line
numbers.

Tests and translations are left out of the tree, the stat and every diff unless
`-v` asks for them: `*.test.*`, `*.spec.*`, `*_test.go`, anything under a
`locales/` directory and any `*translation*.json`. `ctrl-h` brings them back and
hides them again without leaving the tree.

The default mode also puts the PR's description in a row above the tree, fetched
with `gh` in the background so a slow, unauthenticated or PR-less branch never
holds the tree up — the row then says there is nothing to show. The body is cut
at its release notes heading and word-wrapped to the pane.

## Autarc dev stack

Five tiers over the monorepo's `pnpm energy` CLI, in escalating order.
`autarc-prep` and `autarc-db` are worktree-aware and run unattended in Coder,
where `OP_SERVICE_ACCOUNT_TOKEN` renders the env files without a prompt; the
rest assume the main checkout and are for local testing.

| Command       | What it does                                                    |
| ------------- | --------------------------------------------------------------- |
| `autarc-prep` | deps + shared packages: enough to type-check, lint, unit-test    |
| `autarc-db`   | provisioning + Postgres + migrations: integration tests          |
| `autarc-up`   | env files + the containers dev needs (1Password sign-in)         |
| `autarc-dev`  | the dev servers as tmux panes, no agent pane                     |
| `autarc-stop` | kill the tmux session, free the dev ports                        |

`_free-ports` is an internal. `tmux kill-session` only signals each pane's
foreground process, so air's compiled binary and node's children survive
holding their ports — `autarc-dev` sweeps them before starting and
`autarc-stop` after.

## Terminal colours

`ls`, git, delta and fzf do not carry colours of their own — they emit ANSI
palette indices, and the terminal decides what those look like. iTerm2's stock
palette is pastel, which on a white background leaves directories and diffs too
light to read.

`iterm2-white.itermcolors` is a palette for that background: the six hues at
full saturation, each dark enough for 6:1 contrast, and the bright variants at
4:5:1 rather than lighter still. Import it under iTerm2 → Settings → Profiles →
Colors → Color Presets → Import, then select it. It is not symlinked; iTerm2
copies a preset into its own preferences.

Two slots break convention on purpose: 7 and 15 are normally near-white, which
is invisible here, so they are dark greys instead. A program that draws white
text on a coloured background will look wrong — nothing I use does.

## Prerequisites

`gitconfig` sets `core.pager = delta` and `core.editor = nano`, so install both
before linking or git will fail to page and `git commit` will open the wrong
editor.

In a Coder workspace, `setup.sh` installs nano, bat and fd for you — see
[Workspace rebuilds](#workspace-rebuilds). The rest are manual, on both systems.

### git-delta

Syntax-highlighted diffs. The binary is `delta`; the package is `git-delta`.

```bash
# macOS
brew install git-delta

# Debian / Ubuntu
sudo apt install git-delta
```

### nano

On Debian, `setup.sh` handles it. Otherwise `sudo apt install nano`.

macOS has no real nano: its `/usr/bin/nano` is UW PICO 5.09 wearing the name,
and it ignores `~/.nanorc` bindings, so install the genuine article:

```bash
brew install nano
```

Make sure `/opt/homebrew/bin` precedes `/usr/bin` in `PATH` (the default with
`brew shellenv`), otherwise `nano` still resolves to pico.

Note when extending `nanorc`: syntax-highlighting `include` paths differ between
the two systems (`/opt/homebrew/share/nano` vs `/usr/share/nano`) and nanorc has
no conditionals, so a hardcoded path errors on the other machine. Append such
lines from `setup.sh` instead.

Navigation bindings mimic `less`.

### bat

`cat` with syntax highlighting and paging. The search helpers in `bin/` shell
out to it, alongside `fd`, `rg` and `fzf`.

```bash
brew install bat        # macOS
```

On Debian, `setup.sh` handles it. Installing via `apt` instead names the binary
**`batcat`** — plain `bat` belongs to `bacula-console-qt` — so bridge the name,
with `~/.local/bin` ahead of `/usr/bin` on `PATH`:

```bash
mkdir -p ~/.local/bin && ln -sf /usr/bin/batcat ~/.local/bin/bat
```

### fzf

Fuzzy finder.

```bash
brew install fzf        # macOS
sudo apt install fzf    # Debian / Ubuntu
```

### fd

Fast `find`.

```bash
brew install fd        # macOS
```

On Debian, `setup.sh` handles it. Installing via `apt install fd-find` instead
names the binary `fdfind`, so bridge the name like bat:

```bash
ln -sf "$(command -v fdfind)" ~/.local/bin/fd
```
