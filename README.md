<div align="center">
  <img src=".github/assets/terminal.svg" alt="utm-shell connection flow" width="820">

# utm-shell

**Set up UTM lab SSH once. Then type `utm`.**

[![Validate](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml/badge.svg)](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-2f81f7.svg)](LICENSE)

Windows · macOS · Linux · WSL · ChromeOS · FreeBSD · OpenBSD

</div>

## Install

Pick your computer and paste **one command**.

### macOS / Linux / WSL / ChromeOS

```sh
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

### Windows 10 / 11

Open PowerShell:

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

Enter your **UTORid**. That is normally the only setup question.

The default lab machine is `dh2026pc08`. Change it any time with `utm host HOST`.

Re-running the installer is safe: it reuses your existing utm-shell config and SSH key where possible.

## Use

```text
utm
```

That is the normal command.

- **On campus:** it connects directly.
- **Off campus:** it opens/guides UTORvpn when needed, waits for the network, then connects.
- **Interrupted first setup:** just type `utm`; it finishes setup automatically.
- **Passwordless SSH:** setup may ask for your UTORid password once to authorize your public key. The password is never stored.

## First-time UTORvpn

`utm-shell` detects the operating system and only shows the relevant steps.

| Platform | First-time VPN setup |
|---|---|
| Windows | Download the matching Windows Cisco bundle, extract it, run the `.msi` whose name contains `core-vpn` |
| macOS | Download the macOS client, open the `.dmg`, run the `.pkg`, install only the **VPN** module |
| Ubuntu / Debian | Download **Linux (DEB)**, extract it, install `cisco-secure-client-vpn_*_amd64.deb` |
| Fedora / RHEL | Download **Linux (RPM)**, extract it, install the main `cisco-secure-client-vpn` RPM |
| WSL | Install Cisco Secure Client on **Windows**; `utm-shell` launches the Windows client from WSL |
| Other Linux / BSD | SSH setup works normally; if no official Cisco package fits the OS, use campus networking or another U of T-supported VPN environment |

When Cisco is installed, `utm` opens it and tells you only:

```text
1. Connect to general.vpn.utoronto.ca
2. Sign in with your UTORid and password
```

Then it continues automatically.

Official U of T links: [Cisco Secure Client download](https://uoft.me/cisco-vpn-download) · [UTORvpn guide](https://security.utoronto.ca/services/vpn/usage-guide/)

## Commands

```text
utm                 connect
utm status          check connection
utm vpn             open/setup UTORvpn
utm host [HOST]     show/change lab computer
utm files           file-copy examples
utm doctor          diagnose problems
utm update          update/repair
utm help            help
```

Inside the lab machine:

```text
UTM yourutorid@dh2026pc08 ~
❯
```

Run `utm-help` there for the small set of remote shortcuts (`ll`, `c`, `py`, `mkcd`, `ff`, `gs`, `bye`, etc.).

## Platform support

The **local SSH/setup layer** is native PowerShell on Windows and portable POSIX `sh` on Unix-like systems. The Unix scripts are tested with Linux shells plus real FreeBSD and OpenBSD VMs in CI.

| Platform | Install + SSH | UTORvpn helper |
|---|---:|---:|
| Windows 10/11 | ✓ | ✓ official Cisco client |
| macOS | ✓ | ✓ official Cisco client |
| Ubuntu / Debian | ✓ | ✓ official DEB client |
| Fedora / RHEL | ✓ | ✓ official RPM client |
| WSL | ✓ | ✓ through Windows Cisco client |
| ChromeOS Linux | ✓ | network/VPN environment dependent |
| Arch / Alpine / Gentoo / NixOS / other Linux | ✓ | Cisco package compatibility dependent |
| FreeBSD / OpenBSD | ✓ | external/campus U of T network required |

U of T currently publishes Cisco Secure Client downloads for Windows, macOS, and Linux DEB/RPM environments. `utm-shell` does not pretend an official BSD package exists; on unsupported VPN platforms it simply waits until UTM becomes reachable.

## Files

```text
utm files
```

shows the copy commands. The usual forms are:

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

If a known-correct UTORid password is rejected while the lab network is reachable, see [login problems](docs/login-problems.md).

## What it changes

Locally, utm-shell creates a managed `Host utm` SSH entry, a small `utm` command, and an SSH key only if needed. On the UTM machine, it adds a small managed Bash setup for the clean prompt and shortcuts.

It does **not** store your password, upload your private key, disable SSH host verification, replace unrelated dotfiles, or install software on the UTM lab machine.

More: [getting started](GETTING_STARTED.md) · [UTORvpn](docs/utorvpn.md) · [platforms](docs/platforms.md) · [troubleshooting](docs/troubleshooting.md) · [security](SECURITY.md)

This is an independent convenience project and is not affiliated with or maintained by the University of Toronto. Official U of T and course instructions take precedence.

[MIT](LICENSE) © 2026 Andrew Muratov