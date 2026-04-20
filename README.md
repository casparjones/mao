# 🐱 neko

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Arch Linux](https://img.shields.io/badge/arch-linux-1793D1.svg?logo=arch-linux&logoColor=white)](https://archlinux.org/)

**A friendly wrapper around [paru](https://github.com/Morganamilo/paru) for Arch Linux.**

`neko` replaces paru's cryptic pacman-style flags with readable sub-commands —
while still passing any paru flag straight through. Your muscle memory keeps
working; new users don't need to memorize flags.

🌐 Homepage: <https://casparjones.github.io/neko/>

## Motivation

paru is great. But `-Syu`, `-Qtdq`, `-Rns`? You either know them or you don't.
`neko update` is obvious. `neko orphans` is obvious. And when you need
something specific, `neko -Syu --needed` just works — unknown arguments are
forwarded to paru verbatim, so nothing is ever lost by using neko.

## Install

### One-liner

```sh
curl -sSL https://casparjones.github.io/neko/install.sh | sh
```

The installer will:

- check you're on an Arch-based system
- offer to install `paru` if it's missing
- place `neko` in `~/.local/bin` (or `/usr/local/bin` as root)
- optionally install shell completions for fish / bash / zsh

Prefer reading the script first? [view install.sh](./install.sh).

Environment overrides: `NEKO_BRANCH=main`, `NEKO_INSTALL_DIR=…`, `NEKO_YES=1`.

### Manual

```sh
curl -fsSLo ~/.local/bin/neko https://raw.githubusercontent.com/casparjones/neko/main/neko
chmod +x ~/.local/bin/neko
```

## Commands

| neko | paru | description |
|------|------|-------------|
| `neko update` | `paru -Syu` | update system + AUR |
| `neko update-db` | `paru -Syy` | refresh package database |
| `neko install <pkg>` | `paru -S <pkg>` | install package(s) |
| `neko remove <pkg>` | `paru -Rns <pkg>` | remove pkg + deps + configs |
| `neko search <q>` | `paru -Ss <q>` | search repos and AUR |
| `neko info <pkg>` | `paru -Si <pkg>` | package details |
| `neko list` | `paru -Qe` | explicitly installed packages |
| `neko list-all` | `paru -Q` | all installed packages |
| `neko owns <file>` | `paru -Qo <file>` | which package owns a file |
| `neko files <pkg>` | `paru -Ql <pkg>` | files belonging to a package |
| `neko orphans` | `paru -Qtdq` | list orphaned packages |
| `neko clean` | `paru -Sc` | clean package cache |
| `neko clean-all` | `paru -Scc` | empty package cache |
| `neko autoremove` | `paru -Rns $(paru -Qtdq)` | remove orphans (with preview) |
| `neko outdated` | `paru -Qu` | show available updates |
| `neko help` | — | show help |
| `neko version` | — | show neko & paru version |

### Passthrough

Anything neko doesn't recognize is forwarded to paru 1:1:

```sh
neko -Syu                  # → paru -Syu
neko -Qi firefox           # → paru -Qi firefox
neko --aur firefox         # → paru --aur firefox
```

The **only** flag neko intercepts is `-v` / `--version`, which shows both
neko's and paru's version.

## Examples

```sh
# Friday afternoon routine
neko update

# Install a couple of apps
neko install firefox discord

# Find a PDF viewer
neko search pdf

# Who owns /usr/bin/git?
neko owns /usr/bin/git

# Clean up orphans, with preview first
neko autoremove

# Clean them up without the preview
neko autoremove --no-info
```

## Why "neko"?

**Neko** (猫) is Japanese for cat — a little wink at paru's anime-flavored
heritage. Also: cats are short, friendly, and get the job done. 🐱

## Contributing

Small patches are very welcome. Please:

- keep the main script under ~500 lines of Bash
- run `./test.sh` and make sure it passes
- prefer clarity over cleverness

## License

[MIT](LICENSE) © 2026 Caspar Jones
