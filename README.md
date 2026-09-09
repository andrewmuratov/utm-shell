<div align="center">
  <img src=".github/assets/terminal.svg" alt="utm-shell terminal preview" width="820">

# utm-shell

**One setup command. Then just type `utm`.**

[![Validate](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml/badge.svg)](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-2f81f7.svg)](LICENSE)

Windows · macOS · Linux · WSL · ChromeOS Linux

</div>

---

## Install

You need only:

- your **UTORid**
- one real UTM lab computer name, such as `dh2026pc08`
- an internet connection

No GitHub account or clone is required.

### macOS / Linux / WSL / ChromeOS Linux

Paste this once into a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | bash
```

### Windows 10 / 11

Paste this once into **PowerShell** or **Windows Terminal → PowerShell**:

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

Setup asks for your UTORid and lab computer. Your UTORid password may be requested **once** while SSH installs your public key.

If you run setup from home or another off-campus network, that is fine: the installer detects that UTM is unreachable directly, explains why, and offers to open/setup **UTORvpn** before continuing.

After setup, your normal workflow is simply:

```text
utm
```

## The commands you actually need

```text
utm                 connect to the lab
utm status          check host + network/VPN readiness
utm vpn             open/setup UTORvpn
utm host             show the current lab computer
utm host dh2026pc08  switch lab computers
utm files           show copy-file examples
utm doctor          diagnose a problem
utm update          update/repair utm-shell
utm help            show everything
```

Raw OpenSSH still works as `ssh utm` if you specifically want it.

## Home Wi-Fi / off campus

UTM lab computers normally require either the **U of T campus network** or **UTORvpn**. If you type `utm` at home, on public Wi-Fi, or on another off-campus network, utm-shell performs a short reachability check first.

Instead of leaving you staring at an SSH timeout, it explains:

```text
UTM is not reachable from this network.

This is normal if you're at home or off campus.
UTM lab computers normally require either:
  • the U of T campus network, or
  • UTORvpn

This usually is not a password problem.

Press Enter to open/setup UTORvpn.
```

Then it either opens **Cisco Secure Client** if it is already installed, or opens U of T's official VPN setup guide if it is not. Connect the VPN, return to the terminal, press Enter, and utm-shell retries automatically.

At any time:

```text
utm vpn
```

Current U of T general VPN details:

```text
Server: general.vpn.utoronto.ca
Group:  UofT Default
```

Official U of T VPN guide: https://security.utoronto.ca/services/vpn/usage-guide/

See the short [UTORvpn guide](docs/utorvpn.md) for Windows, macOS, Linux, and WSL.

> utm-shell does not redistribute Cisco software or silently request administrator access. If Cisco Secure Client is missing, it opens U of T's current official installation instructions.

## What success looks like

```text
$ utm

UTM yourutorid@dh2026pc08 ~
❯
```

At that point commands run on the UTM lab computer until you type `exit` or `bye`.

## Useful commands inside UTM

```text
ll              detailed listing including hidden files
la              list hidden files
.. / ...        move up directories
c / cls         clear the screen and scrollback
bye             leave the SSH session
reload          reload the remote shell setup
mkcd DIR        create a directory and enter it
ff NAME         find files/directories below the current directory
disk            filesystem disk usage
usage           sizes of everything here, including hidden files
path            print PATH one entry per line
py              python3
gs / gd / gl    friendly Git status / diff / log shortcuts
utm-version     show the installed remote version
utm-help        show the remote command reference
```

Type the beginning of an old command and press **↑/↓** to search matching history.

## Copying lab files

You do not need to remember SCP syntax. On your own computer, run:

```text
utm files
```

The basic forms are:

```bash
# computer → UTM
scp exercise.py utm:~/

# UTM → computer
scp utm:~/exercise.py .

# entire folder → UTM
scp -r lab01 utm:~/
```

## Switching lab computers

You can change the configured machine without editing SSH files:

```text
utm host dh2026pc09
```

Check it with:

```text
utm status
```

## If something breaks

Start with:

```text
utm status
utm doctor
```

Then:

```text
utm update
```

`utm update` reruns the current installer using your saved UTORid, host, and SSH key, so upgrades and repairs normally need no setup questions.

If UTM is reachable but a known-correct password is rejected, the problem can be lab-system UTORid provisioning rather than your computer. See [Login problems](docs/login-problems.md). Never send anyone your password or private SSH key.

## What setup changes

### On your computer

- creates a managed `Host utm` OpenSSH entry
- creates/reuses a dedicated Ed25519 key for UTM
- enables passwordless SSH after the one-time password step
- installs the local `utm` helper command
- adds `~/.local/bin` to your normal shell path where needed
- keeps SSH host verification enabled
- sets short connection timeouts so unreachable lab machines fail quickly

### On the UTM account

- installs a small, marked Bash configuration block
- adds the blue `UTM` prompt and useful commands above
- fixes unsupported modern terminal types when necessary
- improves command history
- hides the long Ubuntu login banner by default

It does **not** install a shell framework, require sudo on UTM, replace unrelated dotfiles, upload your private key, disable host verification, or run a background service.

## Platform support

| Computer | Setup | Daily command | UTORvpn help |
|---|---|---|---|
| Windows 10/11 | PowerShell one-liner | `utm` | launches Cisco or official guide |
| macOS | terminal one-liner | `utm` | launches Cisco or official guide |
| Linux | terminal one-liner | `utm` | launches Cisco or official guide |
| WSL | terminal one-liner | `utm` | use Cisco on the Windows host |
| ChromeOS Linux | terminal one-liner | `utm` | environment-dependent; official guide provided |

More detail: [Getting Started](GETTING_STARTED.md) · [UTORvpn](docs/utorvpn.md) · [Platforms](docs/platforms.md) · [Troubleshooting](docs/troubleshooting.md)

## Security

- only your **public** SSH key is copied to UTM
- private keys remain on your computer
- UTORid passwords are handled directly by OpenSSH / Cisco Secure Client
- SSH host verification remains enabled
- no analytics or telemetry
- no password storage
- no automatic Cisco redistribution

See [SECURITY.md](SECURITY.md).

## Uninstall

macOS / Linux / WSL:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.sh)
```

Windows PowerShell:

```powershell
$u="$env:TEMP\utm-shell-uninstall.ps1"; irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.ps1 -OutFile $u; & $u
```

## Scope

This is an independent convenience project for University of Toronto Mississauga lab access. It is **not affiliated with, endorsed by, or maintained by the University of Toronto**. Official course and U of T IT instructions take precedence.

## License

[MIT](LICENSE) © 2026 Andrew Muratov
