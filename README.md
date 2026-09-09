<div align="center">
  <img src=".github/assets/terminal.svg" alt="utm-shell terminal preview" width="820">

# utm-shell

**Set up UTM lab access once. After that, just type `utm`.**

[![Validate](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml/badge.svg)](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-2f81f7.svg)](LICENSE)

Windows · macOS · Linux · WSL · ChromeOS Linux

</div>

---

## Setup

You need only:

1. your **UTORid**
2. a real UTM lab computer name, such as `dh2026pc08`
3. an internet connection

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

The setup asks for your UTORid and lab computer. If you are off campus, it explains that the UTM lab network is not reachable directly and offers to open **UTORvpn** setup for you.

Your UTORid password may be requested once while your public SSH key is installed. It is handled directly by SSH and is never stored by this project.

After setup, open a new terminal and run:

```text
utm
```

On campus, it connects immediately. Off campus, `utm` checks the connection first and gives you a useful VPN prompt instead of leaving you staring at a hanging SSH command.

## Off campus? `utm` handles it

UTM lab computers are normally reachable only from the U of T network. At home, on public Wi-Fi, or on another off-campus network, connect to **UTORvpn** first.

If `utm` cannot reach the lab network, it shows:

```text
Can't reach the UTM lab computer.

UTM lab machines are normally reachable only from the U of T network.
If you're off campus, connect to UTORvpn first.

  [1] Open Cisco Secure Client / UTORvpn setup
  [2] Open the official U of T VPN guide
  [r] Retry
  [q] Quit
```

You can also open VPN help at any time:

```text
utm vpn
```

If Cisco Secure Client is already installed, `utm vpn` opens it. Otherwise it opens U of T's official UTORvpn setup guide.

The VPN address is:

```text
general.vpn.utoronto.ca
```

Official U of T guide: https://security.utoronto.ca/services/vpn/usage-guide/

> `utm-shell` does not download or replace U of T's VPN client. It launches the installed Cisco client when possible, otherwise it sends you to the official University setup page.

## What success looks like

After connecting:

```text
UTM yourutorid@dh2026pc08 ~
❯
```

You are now running commands on the UTM lab computer.

## What setup does

- creates the SSH shortcut `ssh utm`
- installs the smarter local command `utm`
- detects the common off-campus / no-VPN situation before login
- launches Cisco Secure Client when it is installed
- opens the official UTORvpn guide when the client is missing
- makes raw SSH fail quickly instead of hanging for a long time
- creates a dedicated UTM SSH key automatically
- enables passwordless login
- keeps SSH host verification enabled
- installs a clean remote Bash prompt
- fixes incompatible modern terminal types automatically
- hides the large Ubuntu login banner
- adds a few useful lab commands
- can be rerun safely to repair or update an existing setup

It does **not** require sudo on UTM, install a shell framework, upload your private key, disable host verification, or replace unrelated dotfiles.

## Commands on your computer

| Command | What it does |
|---|---|
| `utm` | check network/VPN and connect to UTM |
| `utm vpn` | open Cisco Secure Client or the official VPN guide |
| `utm raw` | skip the pre-check and run raw SSH |
| `ssh utm` | normal OpenSSH connection using the configured alias |
| `scp FILE utm:~/` | copy a file to your UTM home directory |
| `scp utm:~/FILE .` | copy a file back to your computer |

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

## First-time UTORvpn setup

U of T currently uses **Cisco Secure Client** for UTORvpn. Install the VPN module using the University's official instructions, open Cisco Secure Client, connect to:

```text
general.vpn.utoronto.ca
```

and sign in with your UTORid and password. Once connected, run `utm` again.

See: **https://security.utoronto.ca/services/vpn/usage-guide/**

## If login says `Permission denied`

If the lab computer is reachable but a known-correct password is rejected, the issue can be account provisioning on the lab system rather than your computer. Contact course staff or the lab/system administrator with your **UTORid and hostname**. Never send anyone your password or private SSH key.

See [Login problems](docs/login-problems.md).

## Diagnostics

macOS / Linux / WSL / ChromeOS Linux:

```bash
./doctor.sh
```

Windows PowerShell:

```powershell
.\doctor.ps1
```

## Uninstall

macOS / Linux / WSL:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.sh)
```

Windows PowerShell:

```powershell
$u="$env:TEMP\utm-shell-uninstall.ps1"; irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.ps1 -OutFile $u; & $u
```

## Security

- only your **public** SSH key is copied to UTM
- private keys never leave your computer
- SSH host verification remains enabled
- UTORid passwords are handled directly by OpenSSH / Cisco Secure Client
- no analytics, telemetry, daemon, or background service
- the project links to the official U of T VPN installer instructions instead of redistributing Cisco software

See [SECURITY.md](SECURITY.md).

## More help

- [Getting Started](GETTING_STARTED.md)
- [Login problems](docs/login-problems.md)
- [Platform guide](docs/platforms.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Support](SUPPORT.md)

## Scope

This is a personal convenience project for University of Toronto Mississauga lab access. It is **not affiliated with, endorsed by, or maintained by the University of Toronto**. Official course and U of T IT instructions take precedence.

## License

[MIT](LICENSE) © 2026 Andrew Muratov
