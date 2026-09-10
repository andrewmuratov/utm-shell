<div align="center">
  <img src=".github/assets/terminal.svg" alt="utm-shell terminal preview" width="820">

# utm-shell

**One setup command. Then just type `utm`.**

[![Validate](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml/badge.svg)](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-2f81f7.svg)](LICENSE)

Windows · macOS · Linux · WSL · ChromeOS Linux

</div>

## Install

### macOS / Linux / WSL / ChromeOS Linux

```bash
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | bash
```

### Windows 10 / 11

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

On a new setup, enter your **UTORid**. That's normally the only question.

`utm-shell` uses `dh2026pc08` by default. Switch later with `utm host HOST`.

Your UTORid password may be requested once to enable passwordless SSH.

### If you're off campus

`utm-shell` detects your operating system, opens U of T's **official Cisco Secure Client download page**, and shows only the steps for your platform.

| Platform | What it tells you to do |
|---|---|
| Windows | Download the Windows client (ARM64 only on ARM Windows), extract the ZIP if needed, run the Cisco Secure Client `.msi` |
| macOS | Download the macOS client, open the `.dmg`, run the `.pkg`, and install only the **VPN** module |
| Ubuntu / Debian | Choose **Linux (DEB)**, extract the `.tgz`, then run `sudo apt install ./cisco-secure-client-vpn-*_amd64.deb` |
| Fedora / Red Hat | Choose **Linux (RPM)**, extract the `.tgz`, then run `sudo dnf install ./cisco-secure-client-vpn-*.rpm` |
| WSL | Install the **Windows** Cisco client; `utm-shell` detects and launches it from WSL |

The setup terminal waits while you install Cisco. Once Cisco appears, it opens automatically and shows:

```text
UTORvpn
  1. Cisco Secure Client opened.
  2. Enter general.vpn.utoronto.ca and select Connect.
  3. Sign in with your UTORid and password.

Waiting for UTORvpn...
```

As soon as the VPN connects, setup continues automatically.

Official links: [Cisco Secure Client download](https://uoft.me/cisco-vpn-download) · [U of T UTORvpn guide](https://security.utoronto.ca/services/vpn/usage-guide/)

When setup finishes:

```text
utm
```

## Daily use

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

At home, `utm` handles the same VPN flow automatically. On campus, it connects directly.

UTORvpn server: `general.vpn.utoronto.ca`

## Inside the UTM shell

```text
UTM yourutorid@dh2026pc08 ~
❯
```

Useful commands:

```text
ll / la       file listings
c / cls       clear terminal
.. / ...      move up directories
mkcd DIR      create + enter directory
ff NAME       find files
py            python3
gs / gd / gl  Git status / diff / log
usage         item sizes
bye           disconnect
utm-help      help
```

## Files

Run:

```text
utm files
```

or use normal SCP:

```bash
scp FILE utm:~/
scp utm:~/FILE .
scp -r FOLDER utm:~/
```

## If something breaks

```text
utm status
utm doctor
utm update
```

If a known-correct UTORid password is rejected while the lab is reachable, it may be a UTM account-provisioning issue rather than your computer. See [login problems](docs/login-problems.md).

## What it changes

On your computer, utm-shell adds a managed `Host utm` SSH entry, a local `utm` command, an SSH key if needed, and passwordless login. On UTM, it adds a small managed Bash setup with the clean prompt and shortcuts above.

It does **not** store your password, upload your private key, disable SSH host verification, replace unrelated dotfiles, or install software on the UTM machine.

## More

[Getting started](GETTING_STARTED.md) · [UTORvpn](docs/utorvpn.md) · [Platforms](docs/platforms.md) · [Troubleshooting](docs/troubleshooting.md) · [Security](SECURITY.md)

This is an independent convenience project and is not affiliated with or maintained by the University of Toronto. Official U of T and course instructions take precedence.

[MIT](LICENSE) © 2026 Andrew Muratov