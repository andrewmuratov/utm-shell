# Getting Started

You do **not** need a GitHub account or any prior SSH knowledge.

## Before you start

Have these ready:

- your **UTORid**
- a real UTM lab computer name, such as `dh2026pc08`
- either U of T campus Wi-Fi or **UTORvpn**

`dh20XYpcNM` is only a template. Do not type it literally.

## Windows 10 / 11

1. Open **PowerShell** or **Windows Terminal → PowerShell**.
2. Paste this one line:

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

3. Enter your UTORid.
4. Enter the lab computer name.
5. Enter your UTORid password if SSH asks for it. This should be a one-time setup step.

Then connect anytime with:

```powershell
ssh utm
```

## macOS / Linux / WSL / ChromeOS Linux

1. Open a terminal.
2. Paste this one line:

```bash
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | bash
```

3. Enter your UTORid.
4. Enter the lab computer name.
5. Enter your UTORid password if SSH asks for it. This should be a one-time setup step.

Then connect anytime with:

```bash
ssh utm
```

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

If the hostname cannot be found, check that:

1. it is a real machine name such as `dh2026pc08`
2. you are on campus Wi-Fi or UTORvpn
3. there is no typo

## Safety

Never send anyone your UTORid password, private SSH key, or authentication tokens. Course staff may reasonably ask for your UTORid and the hostname you tried, but they do not need your password.
