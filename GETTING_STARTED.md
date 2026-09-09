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

The default lab computer is `dh2026pc08`. Change it later with:

```text
utm host HOST
```

## 2. If you're off campus

You do not need to figure out the network error yourself.

If UTM is unreachable, setup automatically does one of these:

- **Cisco Secure Client installed:** opens it and waits for UTORvpn to connect
- **not installed:** opens U of T's official Cisco Secure Client download page

UTORvpn server:

```text
general.vpn.utoronto.ca
```

After installing the VPN module, paste the same setup command again. It resumes from the saved setup.

U of T VPN instructions: https://security.utoronto.ca/services/vpn/usage-guide/

## 3. One-time SSH login

SSH may ask for your UTORid password once so it can install your public key.

Your password is handled by SSH and is not stored by utm-shell.

## 4. Done

From then on:

```text
utm
```

On campus it connects directly. Off campus it opens/waits for UTORvpn automatically.

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
