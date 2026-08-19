# dotfiles

Personal config for my two environments: a local macOS machine and a Coder
workspace (Debian). Both read the same files through symlinks, so a change
committed here reaches the other side with one command.

## Layout

| Repo file             | Symlinked to                | What it configures                      |
| --------------------- | --------------------------- | --------------------------------------- |
| `gitconfig`           | `~/.gitconfig`              | identity, aliases, delta as pager       |
| `nanorc`              | `~/.nanorc`                 | emacs-style word motions in nano        |
| `claude/settings.json`| `~/.claude/settings.json`   | Claude Code user settings               |
| `claude/CLAUDE.md`    | `~/.claude/CLAUDE.md`       | Claude Code user-level instructions      |

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

## Prerequisites

`gitconfig` sets `core.pager = delta` and `core.editor = nano`, so install both
before linking or git will fail to page and `git commit` will open the wrong
editor.

### git-delta

Syntax-highlighted diffs. The binary is `delta`; the package is `git-delta`.

```bash
# macOS
brew install git-delta

# Debian / Ubuntu
sudo apt install git-delta
```

If your Debian release has no `git-delta` package, take the `.deb` from the
[releases page](https://github.com/dandavison/delta/releases):

```bash
curl -LO https://github.com/dandavison/delta/releases/download/0.19.2/git-delta_0.19.2_amd64.deb
sudo dpkg -i git-delta_0.19.2_amd64.deb
```

### nano

Debian ships GNU nano already:

```bash
sudo apt install nano
```

macOS does **not**. Its `/usr/bin/nano` is UW PICO 5.09 wearing the name, and it
ignores `~/.nanorc` bindings, so install the real thing:

```bash
brew install nano
```

Make sure `/opt/homebrew/bin` precedes `/usr/bin` in `PATH` (the default with
`brew shellenv`), otherwise `nano` still resolves to pico.

Note when extending `nanorc`: syntax-highlighting `include` paths differ between
the two systems (`/opt/homebrew/share/nano` vs `/usr/share/nano`) and nanorc has
no conditionals, so a hardcoded path errors on the other machine. Append such
lines from `setup.sh` instead.

## Shortcuts

### nano — emacs-style word motions

| Key     | Action                    |
| ------- | ------------------------- |
| `M-f`   | forward one word          |
| `M-b`   | back one word             |
| `M-d`   | delete word to the right  |

### git aliases

| Alias        | Expands to                          |
| ------------ | ----------------------------------- |
| `git co`     | `checkout`                          |
| `git st`     | `status`                            |
| `git br`     | `branch`                            |
| `git cm`     | `commit -m`                         |
| `git amend`  | `commit -a --amend --no-edit`       |
| `git undo`   | `reset --hard` + `clean -f -d`      |
| `git ignore` | `update-index --assume-unchanged`   |

`git undo` discards uncommitted work and deletes untracked files — there is no
recovering from it.

Also set: `pull.ff = only` (no implicit merge commits) and `init.defaultBranch = main`.

### delta

`navigate = true` and `line-numbers = true`, so in any diff `n` jumps to the next
file and `N` to the previous.
