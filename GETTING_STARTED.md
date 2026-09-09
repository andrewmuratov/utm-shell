# Getting Started

You do **not** need a GitHub account or any prior SSH knowledge.

## Before you start

Have these ready:

- your **UTORid**
- a real UTM lab computer name, such as `dh2026pc08`
- an internet connection

`dh20XYpcNM` is only a template. Do not type it literally.

## Install utm-shell

### Windows 10 / 11

Open **PowerShell** or **Windows Terminal → PowerShell** and paste:

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

### macOS / Linux / WSL / ChromeOS Linux

Open a terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | bash
```

The installer asks only for your UTORid and lab computer name.

If you are at home or otherwise off campus, the installer may discover that it cannot reach the UTM lab network. That is expected: UTM lab machines normally require the U of T network. The installer will offer to open **UTORvpn** setup and wait while you connect.

Your UTORid password may be requested once while your public SSH key is installed.

## Connect after setup

Open a new terminal and type:

```text
utm
```

Use `utm` rather than raw `ssh utm` for the friendliest experience. It checks network access first.

### On campus

`utm` should connect directly.

### At home or off campus

`utm` explains that UTORvpn is needed and offers:

```text
[1] Open Cisco Secure Client / UTORvpn setup
[2] Open the official U of T VPN guide
[r] Retry
[q] Quit
```

If Cisco Secure Client is installed, option 1 opens it. If it is not installed, the official U of T setup guide opens instead.

You can also open VPN help at any time:

```text
utm vpn
```

The general UTORvpn address is:

```text
general.vpn.utoronto.ca
```

Official U of T instructions:

https://security.utoronto.ca/services/vpn/usage-guide/

After Cisco Secure Client says you are connected, return to your terminal and retry `utm`.

## What success looks like

```text
UTM yourutorid@dh2026pc08 ~
❯
```

You are now working on the remote UTM lab computer. Leave with:

```bash
exit
```

or:

```bash
bye
```

## Useful first commands

```bash
utm-help   # show every added shortcut
ll         # detailed file listing
c          # fully clear the terminal
py         # run python3
```

To copy a file **from your own computer** to UTM:

```bash
scp exercise.py utm:~/exercise.py
```

## Something broke?

Run the **same setup command again**. The installer is designed to repair and update its own configuration safely.

If login says `Permission denied` even though your password is definitely correct, see [Login problems](docs/login-problems.md). Your UTORid may not yet be provisioned on the lab system.

If raw `ssh utm` hangs or times out at home, use `utm` instead. It performs a short network pre-check and explains the UTORvpn requirement.

## Safety

Never send anyone your UTORid password, private SSH key, or authentication tokens. Course staff may reasonably ask for your UTORid and the hostname you tried, but they do not need your password.
