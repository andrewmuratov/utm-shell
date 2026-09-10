<div align="center">
  <img src=".github/assets/terminal.svg" alt="utm-shell connection flow" width="820">

# utm-shell

**One setup command. Then just type `utm`.**

[![Validate](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml/badge.svg)](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-2f81f7.svg)](LICENSE)

Windows · macOS · Linux · WSL · ChromeOS · FreeBSD · OpenBSD

</div>

## Install

### macOS / Linux / WSL / ChromeOS

```sh
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

### Windows 10 / 11

Open PowerShell and paste:

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

### FreeBSD

```sh
fetch -q -o - https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

### OpenBSD

```sh
ftp -V -o - https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

Enter your **UTORid**. The default lab computer is `dh2026pc08`.

## What setup does

`utm-shell` handles the rest:

1. configures `ssh utm`
2. creates/reuses an SSH key
3. asks for your UTORid password once if the key must be authorized
4. sets up the clean remote shell
5. handles UTORvpn when you are off campus

Your password is never stored.

## Off campus / UTORvpn

Just run:

```text
utm
```

If Cisco Secure Client is already installed, `utm` opens it and waits for you to connect.

If it is not installed, `utm` opens U of T's official Cisco download page and only shows the steps for your OS.

### Ubuntu / Debian

1. Click **Linux (DEB)** on the page that opens.
2. Leave the terminal open.
3. `utm-shell` detects the download, extracts it, selects the **main VPN package** (not `vpn-cli`), and runs the install automatically.
4. Enter your computer's administrator password once when `sudo` asks.

No extracting folders. No package filename hunting. No `apt` command to copy.

### Fedora / RHEL

1. Click **Linux (RPM)**.
2. Leave the terminal open.
3. `utm-shell` extracts the download and installs the main VPN RPM automatically.
4. Approve the administrator-password prompt.

### Windows

1. Click **Windows** (or **Windows ARM64** when appropriate).
2. Leave PowerShell open.
3. `utm-shell` detects the ZIP, extracts it, finds the `core-vpn` MSI, and starts that installer automatically.
4. Approve the Windows administrator prompt.

### macOS

1. Click **macOS**.
2. `utm-shell` detects the downloaded DMG and opens it automatically.
3. Run the package and install only the **VPN** module.

After Cisco is ready, `utm-shell` opens it and shows only:

```text
1. Connect to general.vpn.utoronto.ca
2. Sign in with your UTORid and password
```

It detects the VPN connection and continues automatically.

Official U of T instructions: [UTORvpn usage guide](https://security.utoronto.ca/services/vpn/usage-guide/) · [Cisco Secure Client download](https://uoft.me/cisco-vpn-download)

## Daily use

```text
utm
```

That's it.

- on campus → connects directly
- at home → opens/waits for UTORvpn, then connects
- interrupted first setup → `utm` resumes it
- SSH → passwordless after the one-time key authorization

## Useful commands

```text
utm                 connect
utm status          check connection
utm vpn             open/setup UTORvpn
utm host HOST       switch lab computer
utm files           file-copy examples
utm doctor          diagnose problems
utm update          update/repair
utm help            help
```

Inside UTM:

```text
UTM yourutorid@dh2026pc08 ~
❯
```

Run `utm-help` there for shortcuts such as `ll`, `c`, `py`, `mkcd`, `ff`, `gs`, and `bye`.

## Platform support

The SSH/setup layer uses native PowerShell on Windows and portable POSIX `sh` on Unix-like systems.

| Platform | SSH/setup | UTORvpn helper |
|---|---:|---:|
| Windows 10/11 | ✓ | ✓ official Cisco client + automated bundle install |
| macOS | ✓ | ✓ official Cisco client + DMG detection |
| Ubuntu / Debian | ✓ | ✓ official DEB + automated extraction/install |
| Fedora / RHEL | ✓ | ✓ official RPM + automated extraction/install |
| WSL | ✓ | ✓ through Windows Cisco client |
| ChromeOS Linux | ✓ | depends on Linux/VPN environment |
| Arch / Alpine / Gentoo / NixOS / other Linux | ✓ | Cisco package compatibility dependent |
| FreeBSD / OpenBSD | ✓ | campus or another U of T-supported VPN environment required |

U of T currently documents Cisco Secure Client for Windows, macOS, and Linux DEB/RPM environments. `utm-shell` does not pretend unsupported Cisco packages exist on other systems.

## Files

```text
utm files
```

shows copy examples such as:

```sh
scp FILE utm:~/
scp utm:~/FILE .
scp -r FOLDER utm:~/
```

## If something breaks

```text
utm doctor
utm update
```

If a known-correct UTORid password is rejected while the UTM network is reachable, see [login problems](docs/login-problems.md).

## What it changes

Locally, utm-shell creates a managed `Host utm` SSH entry, the `utm` command, and an SSH key only when needed. On the UTM machine it adds a small managed Bash setup for the prompt and shortcuts.

It does **not** store passwords, upload private keys, disable SSH host verification, replace unrelated dotfiles, or install software on UTM lab machines.

More: [getting started](GETTING_STARTED.md) · [UTORvpn](docs/utorvpn.md) · [platforms](docs/platforms.md) · [troubleshooting](docs/troubleshooting.md) · [security](SECURITY.md)

This is an independent convenience project and is not affiliated with or maintained by the University of Toronto. Official U of T and course instructions take precedence.

[MIT](LICENSE) © 2026 Andrew Muratov
