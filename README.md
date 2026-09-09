<div align="center">
  <img src=".github/assets/terminal.svg" alt="utm-shell terminal preview" width="820">

# utm-shell

**Set up UTM lab SSH once. After that, just type `ssh utm`.**

[![Validate](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml/badge.svg)](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-2f81f7.svg)](LICENSE)

Windows · macOS · Linux · WSL · ChromeOS Linux

</div>

---

## Setup

You need only:

1. your **UTORid**
2. a real lab computer name, such as `dh2026pc08`
3. **campus Wi-Fi or UTORvpn**

### macOS / Linux / WSL / ChromeOS Linux

Paste this into a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | bash
```

### Windows 10 / 11

Paste this into **PowerShell**:

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

That's it.

The setup asks only for:

```text
UTORid: yourutorid
Lab computer (example: dh2026pc08): dh2026pc08
```

Then SSH may ask for your UTORid password **once** so it can install your public key.

After setup:

```text
ssh utm
```

and you should land at:

```text
UTM yourutorid@dh2026pc08 ~
❯
```

## What setup does

- creates the short command `ssh utm`
- creates a dedicated UTM SSH key automatically
- enables passwordless login
- keeps SSH host verification enabled
- installs a clean remote Bash prompt
- fixes incompatible modern terminal types automatically
- hides the giant Ubuntu login banner
- adds a few useful lab commands
- can be rerun safely to **repair or update** an existing setup

It does **not** require sudo on UTM, install a shell framework, upload your private key, or replace unrelated dotfiles.

## Useful commands inside UTM

| Command | What it does |
|---|---|
| `ll` | detailed listing including hidden files |
| `la` | hidden files |
| `..`, `...`, `....` | move up directories |
| `c`, `cls` | fully clear the screen and scrollback |
| `bye` | leave the SSH session |
| `reload` | reload the shell setup |
| `mkcd DIR` | create a directory and enter it |
| `ff NAME` | find files/directories below `.` |
| `disk` | filesystem disk usage |
| `usage` | sizes of everything here, including hidden files |
| `path` | print `$PATH` one entry per line |
| `py` | run `python3` |
| `gs`, `gd`, `gl` | friendly Git status/diff/log shortcuts |
| `utm-version` | show installed utm-shell version |
| `utm-help` | show the command reference |

Type the beginning of an old command and press **↑/↓** to search matching history.

## Copy files

```bash
# your computer → UTM
scp exercise.py utm:~/exercise.py

# UTM → your computer
scp utm:~/result.txt ./result.txt

# whole directory
scp -r lab01 utm:~/labs/
```

These work in macOS/Linux terminals and native Windows OpenSSH/PowerShell.

## If setup fails with `Permission denied`

First verify that you are on **campus Wi-Fi or UTORvpn** and that the hostname is real.

If the password is definitely correct but UTM still rejects it, your **UTORid may not yet be provisioned on the lab system**. That is a server/account-side issue, not something this project can fix. Contact course staff or the lab/system administrator with your UTORid and the hostname you tried. **Never send anyone your password or private key.**

See [login problems](docs/login-problems.md) for the short decision tree.

## Repair / update

Just run the same setup command again. It replaces only its own managed configuration.

This also repairs older `utm-shell` setups that had shell alias conflicts or broken `~/.bashrc` blocks.

## Prefer to inspect first?

```bash
git clone https://github.com/andrewmuratov/utm-shell.git
cd utm-shell
./setup.sh
```

Windows PowerShell:

```powershell
git clone https://github.com/andrewmuratov/utm-shell.git
cd utm-shell
.\setup.ps1
```

`install.sh` and `install.ps1` remain as compatibility entrypoints and forward to the new setup scripts.

## More

- [Getting started](GETTING_STARTED.md)
- [Platform support](docs/platforms.md)
- [Login problems](docs/login-problems.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Security](SECURITY.md)
- [Uninstall](#uninstall)

## Uninstall

macOS / Linux / WSL:

```bash
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.sh | bash
```

Windows PowerShell:

```powershell
$u="$env:TEMP\utm-shell-uninstall.ps1"; irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.ps1 -OutFile $u; & $u
```

## Scope

This is a personal convenience project for University of Toronto Mississauga lab access. It is **not affiliated with, endorsed by, or maintained by the University of Toronto**. Official U of T and course instructions take precedence.

## License

[MIT](LICENSE) © 2026 Andrew Muratov
