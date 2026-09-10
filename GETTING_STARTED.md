# Getting started

You do **not** need a GitHub account or prior SSH knowledge.

## 1. Install

### macOS / Linux / WSL / ChromeOS

```sh
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

### Windows

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

Enter your **UTORid**. New installs use `dh2026pc08` by default.

## 2. If you are off campus

`utm-shell` notices that UTM is not reachable.

If Cisco Secure Client is supported on your platform, it opens U of T's official download page, gives short OS-specific instructions, waits for installation, opens Cisco, and then asks you to:

```text
1. Connect to general.vpn.utoronto.ca
2. Sign in with your UTORid and password
```

When the VPN connects, setup continues automatically.

If your OS does not have an applicable U of T Cisco package, connect through campus networking or another U of T-supported VPN environment. Leave the terminal open and utm-shell continues as soon as UTM is reachable.

## 3. One password, once

If no already-authorized SSH key works, SSH asks for your UTORid password once so utm-shell can add your **public** key.

Your password is not stored.

## 4. Done

From then on:

```text
utm
```

If the first setup was interrupted, the same `utm` command finishes it automatically.

Useful commands:

```text
utm status
utm vpn
utm host HOST
utm files
utm doctor
utm update
utm help
```

Inside UTM, run `utm-help` for the remote shortcuts and `bye` to disconnect.

Official VPN help: [U of T UTORvpn guide](https://security.utoronto.ca/services/vpn/usage-guide/).