<div align="center">

# UTM Shell

**Simple UTM lab access. Set it up once, then type `utm`.**

[![Validate](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml/badge.svg)](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-2f81f7.svg)](LICENSE)
[![Windows](https://img.shields.io/badge/Windows-supported-0078D4?logo=windows11&logoColor=white)](docs/platforms.md)
[![macOS](https://img.shields.io/badge/macOS-supported-000000?logo=apple&logoColor=white)](docs/platforms.md)
[![Linux](https://img.shields.io/badge/Linux-supported-FCC624?logo=linux&logoColor=111111)](docs/platforms.md)
[![WSL](https://img.shields.io/badge/WSL-supported-0078D4?logo=windows-terminal&logoColor=white)](docs/platforms.md)
[![ChromeOS](https://img.shields.io/badge/ChromeOS-supported-4285F4?logo=googlechrome&logoColor=white)](docs/platforms.md)
[![FreeBSD](https://img.shields.io/badge/FreeBSD-supported-AB2B28?logo=freebsd&logoColor=white)](docs/platforms.md)
[![OpenBSD](https://img.shields.io/badge/OpenBSD-supported-F2CA30)](docs/platforms.md)

</div>

## Install

Choose your computer and paste **one command**.

### macOS / Linux / WSL / ChromeOS Linux

```sh
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

### Windows 10 / 11

Open PowerShell:

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

<details>
<summary><strong>FreeBSD / OpenBSD</strong></summary>

**FreeBSD**

```sh
fetch -q -o - https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

**OpenBSD**

```sh
ftp -V -o - https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

</details>

## Setup

The installer does almost everything for you.

1. Enter your **UTORid**.
2. If SSH needs authorization, enter your **UTORid password once**.
3. When setup finishes, type:

```text
utm
```

Your password is never stored.

The default lab computer is `dh2026pc08`. Change it later with:

```text
utm host HOST
```

## Off campus

UTM lab machines normally require the U of T network or **UTORvpn**.

Just run:

```text
utm
```

If you are off campus, UTM Shell detects that automatically.

- **Cisco already installed:** it opens Cisco Secure Client and waits for the VPN.
- **Cisco not installed:** it opens the official U of T download page and guides the correct setup for your OS.
- **Ubuntu / Debian and Fedora / RHEL:** downloaded Cisco packages are detected, extracted, and installed automatically; you only approve the administrator prompt.
- **Windows:** the downloaded Cisco bundle is detected, extracted, and the VPN installer is opened automatically.
- **macOS:** the downloaded Cisco image is detected and opened automatically; finish the Cisco package and select the VPN module.

Then connect to:

```text
general.vpn.utoronto.ca
```

Sign in with your UTORid. UTM Shell detects the connection and continues.

[Official UTORvpn guide](https://security.utoronto.ca/services/vpn/usage-guide/) · [Cisco Secure Client download](https://uoft.me/cisco-vpn-download)

## Daily use

```text
utm
```

That's the normal command.

- on campus → connects directly
- off campus → handles the UTORvpn step, then connects
- after first setup → SSH is passwordless
- interrupted setup → run `utm` again and it resumes

## Commands

| Command | What it does |
|---|---|
| `utm` | Connect to the lab |
| `utm status` | Check whether UTM is reachable |
| `utm vpn` | Open or set up UTORvpn |
| `utm host HOST` | Change lab computer |
| `utm files` | Show file-copy examples |
| `utm doctor` | Diagnose problems |
| `utm update` | Update or repair UTM Shell |
| `utm help` | Show help |

Inside the lab machine, run `utm-help` for the small set of shell shortcuts.

## Files

```sh
scp FILE utm:~/
scp utm:~/FILE .
scp -r FOLDER utm:~/
```

## Compatibility

The local setup layer uses **PowerShell on Windows** and portable **POSIX `sh` on Unix-like systems**.

Windows, macOS, Linux, WSL, ChromeOS Linux, FreeBSD, and OpenBSD are supported by the SSH/setup layer. UTORvpn availability depends on the Cisco client packages U of T provides for each platform.

See [platform details](docs/platforms.md) for exact VPN support and limitations.

## Troubleshooting

```text
utm doctor
utm update
```

More help: [getting started](GETTING_STARTED.md) · [UTORvpn](docs/utorvpn.md) · [login problems](docs/login-problems.md) · [security](SECURITY.md)

## What UTM Shell changes

UTM Shell creates a managed SSH entry, the local `utm` command, and an SSH key when needed. It also adds a small managed shell setup on the UTM lab machine.

It does **not** store passwords, upload private keys, disable SSH host verification, replace unrelated dotfiles, or install software on UTM lab machines.

---

UTM Shell is an independent convenience project and is not affiliated with or maintained by the University of Toronto. Official U of T and course instructions take precedence.

[MIT](LICENSE) © 2026 Andrew Muratov
