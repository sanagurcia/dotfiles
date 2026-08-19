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

Navigation bindings mimic `less`.

### bat

`cat` with syntax highlighting and paging. The `fv` function in `zshrc` shells
out to it, alongside `fd` and `fzf`.

```bash
# macOS
brew install bat

# Debian / Ubuntu
sudo apt install bat
```

On Debian the binary is installed as **`batcat`** — plain `bat` belongs to
`bacula-console-qt` — so bridge the name, with `~/.local/bin` ahead of
`/usr/bin` on `PATH`:

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

Fast `find`. Debian ships it as `fdfind`, so bridge the name like bat.

```bash
brew install fd             # macOS
sudo apt install fd-find    # Debian / Ubuntu
ln -sf "$(command -v fdfind)" ~/.local/bin/fd
```
