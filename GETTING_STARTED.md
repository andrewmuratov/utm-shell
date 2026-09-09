# Getting Started

You do **not** need a GitHub account or prior SSH knowledge.

## 1. Paste one command

### Windows 10 / 11

Open PowerShell and paste:

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

### macOS / Linux / WSL / ChromeOS Linux

Open a terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | bash
```

On a new install, enter your **UTORid**. That's normally the only question.

The default lab computer is `dh2026pc08`. Change it later with `utm host HOST`.

## 2. If you're off campus

Setup handles UTORvpn in a short, ordered flow.

If Cisco Secure Client is missing, it opens U of T's official VPN instructions and shows steps for your operating system. For Ubuntu/Debian, for example:

```text
UTORvpn setup
  1. U of T VPN instructions opened in your browser.
  2. Download + extract Cisco Secure Client for Linux.
  3. In the extracted folder, run:
     sudo apt install ./cisco-secure-client-vpn-*_amd64.deb
  4. Leave this terminal open — utm-shell will continue automatically.

Waiting for Cisco Secure Client...
```

After Cisco is installed, utm-shell detects and opens it:

```text
UTORvpn
  1. Cisco Secure Client opened.
  2. Connect to general.vpn.utoronto.ca.
  3. Sign in with your UTORid and password.

Waiting for UTORvpn...
```

Once UTORvpn connects, setup continues automatically. You normally do **not** need to rerun anything.

Official U of T VPN instructions: https://security.utoronto.ca/services/vpn/usage-guide/

## 3. One-time SSH login

SSH may ask for your UTORid password once so it can install your public key.

Your password is handled by SSH and is not stored by utm-shell.

## 4. Done

From then on:

```text
utm
```

On campus it connects directly. Off campus it runs the same UTORvpn flow automatically.

## Useful commands

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

Inside UTM:

```text
UTM yourutorid@dh2026pc08 ~
❯
```

Use `utm-help` for the remote shortcuts and `bye` to disconnect.

If something fails, run `utm doctor`. If a known-correct password is rejected while UTM is reachable, see [Login problems](docs/login-problems.md).