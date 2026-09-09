# Getting Started

You do **not** need a GitHub account or prior SSH knowledge.

## 1. Have two things ready

- your **UTORid**
- a real UTM lab computer name, for example `dh2026pc08`

`dh20XYpcNM` is only a template from the course guide. Do not type it literally.

You can run setup **on campus or at home**.

## 2. Paste one command

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

The installer asks for your UTORid and lab computer name. It creates the short local command `utm`, sets up SSH, and guides you through the one-time key login.

Your UTORid password may be requested **once** by SSH. Password characters are normally invisible while you type; this is expected. utm-shell does not read or save the password.

## 3. If you are at home, follow the VPN prompt

UTM lab computers normally require the U of T network. At home, on public Wi-Fi, or on another off-campus network, setup may display:

```text
UTM is not reachable from this network.

This is normal if you're at home or off campus.
UTM lab computers normally require either:
  • the U of T campus network, or
  • UTORvpn

Press Enter to open/setup UTORvpn.
```

Press **Enter**.

- If Cisco Secure Client is already installed, utm-shell opens it.
- If it is not installed, utm-shell opens U of T's official installation guide.

The current general VPN connection is:

```text
Server: general.vpn.utoronto.ca
Group:  UofT Default
```

Sign in with your UTORid and password. After Cisco Secure Client says it is connected, return to the terminal and press Enter. Setup retries automatically.

Full VPN details: [UTORvpn guide](docs/utorvpn.md).

## 4. From then on, type one word

```text
utm
```

On campus, it connects directly. Off campus, it checks first and helps with UTORvpn instead of making you wait for an SSH timeout.

## Commands worth remembering

```text
utm                 connect
utm status          check whether everything is ready
utm vpn             open/setup UTORvpn
utm host HOST       switch lab computers
utm files           show file-copy examples
utm doctor          diagnose problems
utm update          update/repair the setup
utm help            show all local commands
```

Raw `ssh utm` still works, but `utm` is the friendlier default.

## What success looks like

```text
UTM yourutorid@dh2026pc08 ~
❯
```

You are now working on the remote UTM lab computer. Leave with:

```text
bye
```

or `exit`.

## Useful commands after you are connected

```text
utm-help   show the remote shortcuts
ll         detailed file listing
c          clear the terminal
py         run python3
mkcd DIR   make a directory and enter it
ff NAME    find a file/directory
```

## Copy a file

Run this on **your own computer**, not inside UTM:

```bash
scp exercise.py utm:~/
```

If you forget the syntax:

```text
utm files
```

## Change lab computer

```text
utm host dh2026pc09
```

Then:

```text
utm status
```

## Something broke?

Use:

```text
utm status
utm doctor
utm update
```

`utm update` uses your saved setup information, so it normally repairs or upgrades the installation without asking the initial questions again.

If UTM is reachable but a known-correct password is rejected, see [Login problems](docs/login-problems.md). The cause can be account provisioning on the lab system rather than your computer.

## Safety

Never send anyone your UTORid password, private SSH key, or authentication tokens. Course staff may reasonably ask for your UTORid and the hostname you tried, but they do not need your password.
