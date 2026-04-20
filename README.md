# 🐱 mao

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Arch Linux](https://img.shields.io/badge/arch-linux-1793D1.svg?logo=arch-linux&logoColor=white)](https://archlinux.org/)

**A friendly wrapper around [paru](https://github.com/Morganamilo/paru) for Arch Linux.**

`mao` replaces paru's cryptic pacman-style flags with readable sub-commands —
while still passing any paru flag straight through. Your muscle memory keeps
working; new users don't need to memorize flags.

🌐 Homepage: <https://casparjones.github.io/mao/>

## Motivation

paru is great. But `-Syu`, `-Qtdq`, `-Rns`? You either know them or you don't.
`mao update` is obvious. `mao orphans` is obvious. And when you need
something specific, `mao -Syu --needed` just works — unknown arguments are
forwarded to paru verbatim, so nothing is ever lost by using mao.

## Install

### One-liner

```sh
curl -sSL https://casparjones.github.io/mao/install.sh | sh
```

The installer will:

- check you're on an Arch-based system
- offer to install `paru` if it's missing
- place `mao` in `~/.local/bin` (or `/usr/local/bin` as root)
- optionally install shell completions for fish / bash / zsh

Prefer reading the script first? [view install.sh](./install.sh).

Environment overrides: `MAO_BRANCH=main`, `MAO_INSTALL_DIR=…`, `MAO_YES=1`.

### Manual

```sh
curl -fsSLo ~/.local/bin/mao https://raw.githubusercontent.com/casparjones/mao/main/mao
chmod +x ~/.local/bin/mao
```

## Commands

| mao | paru | description |
|-----|------|-------------|
| `mao update` | `paru -Syu` | update system + AUR |
| `mao update-db` | `paru -Syy` | refresh package database |
| `mao install <pkg>` | `paru -S <pkg>` | install package(s) |
| `mao remove <pkg>` | `paru -Rns <pkg>` | remove pkg + deps + configs |
| `mao search <q>` | `paru -Ss <q>` | search repos and AUR |
| `mao info <pkg>` | `paru -Si <pkg>` | package details |
| `mao list` | `paru -Qe` | explicitly installed packages |
| `mao list-all` | `paru -Q` | all installed packages |
| `mao owns <file>` | `paru -Qo <file>` | which package owns a file |
| `mao files <pkg>` | `paru -Ql <pkg>` | files belonging to a package |
| `mao orphans` | `paru -Qtdq` | list orphaned packages |
| `mao clean` | `paru -Sc` | clean package cache |
| `mao clean-all` | `paru -Scc` | empty package cache |
| `mao autoremove` | `paru -Rns $(paru -Qtdq)` | remove orphans (with preview) |
| `mao outdated` | `paru -Qu` | show available updates |
| `mao help` | — | show help |
| `mao version` | — | show mao & paru version |

### Passthrough

Anything mao doesn't recognize is forwarded to paru 1:1:

```sh
mao -Syu                  # → paru -Syu
mao -Qi firefox           # → paru -Qi firefox
mao --aur firefox         # → paru --aur firefox
```

The **only** flag mao intercepts is `-v` / `--version`, which shows both
mao's and paru's version.

## Examples

```sh
# Friday afternoon routine
mao update

# Install a couple of apps
mao install firefox discord

# Find a PDF viewer
mao search pdf

# Who owns /usr/bin/git?
mao owns /usr/bin/git

# Clean up orphans, with preview first
mao autoremove

# Clean them up without the preview
mao autoremove --no-info
```

## Why "mao"?

**Mao** (猫) is the sound a cat makes in Chinese — a nod to Maomao from
*Kusuriya no Hitorigoto* (The Apothecary Diaries). Like her: small, precise,
and gets the job done quietly. 🐱

## Contributing

Small patches are very welcome. Please:

- keep the main script under ~500 lines of Bash
- run `./test.sh` and make sure it passes
- prefer clarity over cleverness

## License

[MIT](LICENSE) © 2026 Caspar Jones
