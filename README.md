<div align="center">
  <img src=".github/assets/terminal.svg" alt="utm-shell terminal preview" width="820">

# utm-shell

**A tiny, reversible SSH + Bash setup for UTM lab machines.**

[![Validate](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml/badge.svg)](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-2f81f7.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/shell-Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)

`ssh utm` → clean remote shell, no repeated UTORid password, no giant login banner, and a few useful shortcuts.

</div>

---

## Quick install

You need to be on the **U of T network** or connected through **UTORvpn** so the lab hostname can be reached.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.sh)
```

The installer asks for only what it needs:

```text
UTORid: yourutorid
UTM lab host (for example dh2026pc08): dh2026pc08
```

It will reuse an existing Ed25519 key if you want, or create a dedicated one. Your UTORid password may be requested **once** while the public key is installed.

After that:

```bash
ssh utm
```

```text
UTM yourutorid@dh2026pc08 ~
❯
```

> Prefer to inspect scripts before running them? Clone the repo and run `./install.sh` locally instead.

## What it sets up

### On your computer

- adds a managed `Host utm` entry to `~/.ssh/config`
- configures your UTORid, lab hostname, and SSH key
- enables SSH key authentication so normal logins do not need your UTORid password
- keeps the connection alive during idle periods
- reuses short-lived SSH connections for faster `ssh`, `scp`, and `rsync`

### On the UTM machine

- adds a clearly marked, removable block to `~/.bashrc`
- fixes Ghostty's `xterm-ghostty` compatibility issue by using `xterm-256color` remotely
- gives the remote machine a visually distinct `UTM` prompt
- improves Bash history and Up/Down prefix search
- adds a small set of practical aliases/functions
- makes login shells load the Bash setup when needed
- hides the Ubuntu MOTD/login wall with `~/.hushlogin` unless you opt out

It **does not** replace your shell, install a framework, require root, install packages, or overwrite your dotfiles.

## Included commands

| Command | What it does |
|---|---|
| `ll` | detailed listing, including hidden files |
| `la` | list hidden files |
| `..`, `...`, `....` | move up directories |
| `c`, `cls` | clear the terminal |
| `reload` | reload `~/.bashrc` |
| `mkcd DIR` | create a directory and enter it |
| `ff NAME` | find files/directories by name below the current directory |
| `disk` | show filesystem usage |
| `usage` | show sizes in the current directory |
| `path` | print `$PATH` one entry per line |
| `py` | `python3` |
| `gs`, `gd`, `gl` | compact Git status/diff/log shortcuts |
| `utm-help` | show the command reference inside the remote shell |

History search is also improved: type the beginning of a previous command, then press **↑/↓** to cycle through matching history entries.

## Example workflow

```bash
# from your own computer
ssh utm

# now on the UTM lab machine
mkcd ~/courses/csc110/lab01
py exercise1.py
gs

# leave the remote machine
exit
```

File transfer stays short too:

```bash
scp exercise1.py utm:~/courses/csc110/lab01/
rsync -avP lab01/ utm:~/courses/csc110/lab01/
```

## Installer options

```text
--user UTORID       UTORid used to log in
--host HOST         Lab hostname, short or fully qualified
--alias NAME        Local SSH alias (default: utm)
--key PATH          SSH private key to use
--skip-key-copy     Do not install the public key on UTM
--no-hushlogin      Keep the Ubuntu login banner
```

Example:

```bash
./install.sh --user jdoe1 --host dh2026pc08 --alias utm
```

Short hostnames automatically become `*.utm.utoronto.ca`.

## Uninstall

The setup is intentionally reversible:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.sh)
```

The uninstaller removes the managed remote Bash block, the managed SSH config block, and (by default) the matching public key from the UTM account. If utm-shell created a dedicated private key, it **does not delete it automatically**; it tells you where it is so you can decide.

Useful options:

```text
--local-only      only remove the local SSH configuration
--keep-auth-key   leave the public key in UTM's authorized_keys
```

## Safety and design

The project is deliberately boring in the best way:

- every change is bounded by `utm-shell` markers
- rerunning the installer is idempotent
- existing dotfile content is preserved
- no `sudo`
- no package installation
- no private key is ever copied to UTM or committed anywhere
- the public key is the only key material sent to the remote account
- no analytics, telemetry, background process, or network service

The installer stores a small local state file at `~/.config/utm-shell/config` and a remote state file at `~/.config/utm-shell/state` so uninstall can clean up only what it owns.

## Troubleshooting

**`Could not resolve hostname ...`**  
Make sure the hostname is real (for example `dh2026pc08`, not a template containing `XY`/`NM`) and that you are on campus Wi‑Fi or UTORvpn.

**`Permission denied` while browsing `/student/...`**  
That is normal. Student home directories are permission-protected.

**`xterm-ghostty: unknown terminal type`**  
Rerun the installer or reconnect after installation. The remote Bash block maps Ghostty to `xterm-256color`.

**I changed lab computers.**  
Rerun `install.sh` with the new host. The managed SSH block is replaced rather than duplicated.

## Scope

This is a personal convenience project for University of Toronto Mississauga lab access. It is **not affiliated with, endorsed by, or maintained by the University of Toronto**. Lab infrastructure and course policies can change; follow official course and IT instructions when they differ from this project.

## License

[MIT](LICENSE) © 2026 Andrew Muratov
