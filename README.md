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
| `zshrc`                | `~/.zshrc.local`          | zsh overlay, where a `~/.zshrc` exists |
| `claude/settings.json` | `~/.claude/settings.json` | Claude Code user settings           |
| `claude/CLAUDE.md`     | `~/.claude/CLAUDE.md`     | Claude Code user-level instructions |

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

`cat` with syntax highlighting and paging. The `fv` function in `zshrc` shells
out to it, alongside `fd` and `fzf`.

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
