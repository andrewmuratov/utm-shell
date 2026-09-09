<div align="center">
  <img src=".github/assets/terminal.svg" alt="utm-shell terminal preview" width="820">

# utm-shell

**A clean, reversible SSH + Bash setup for UTM lab machines — from Windows, macOS, Linux, WSL, and other Unix-like systems.**

[![Validate](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml/badge.svg)](https://github.com/andrewmuratov/utm-shell/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-2f81f7.svg)](LICENSE)
[![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4?logo=windows11&logoColor=white)](docs/platforms.md#windows-10--11)
[![macOS](https://img.shields.io/badge/macOS-supported-000000?logo=apple&logoColor=white)](docs/platforms.md#macos)
[![Linux](https://img.shields.io/badge/Linux-supported-FCC624?logo=linux&logoColor=black)](docs/platforms.md#linux)

`ssh utm` → passwordless login, a clean remote prompt, compatible terminal behavior, and useful lab shortcuts.

</div>

---

## Platform support

| Your computer | Native setup | SSH | SCP | Key login | X11 GUI forwarding |
|---|---|---:|---:|---:|---:|
| **Windows 10/11** | PowerShell `install.ps1` | ✓ | ✓ | ✓ | ✓ with an X server |
| **macOS** | Bash `install.sh` | ✓ | ✓ | ✓ | ✓ with XQuartz |
| **Linux** | Bash `install.sh` | ✓ | ✓ | ✓ | ✓ |
| **WSL** | Bash `install.sh` | ✓ | ✓ | ✓ | ✓ with WSLg/X |
| **ChromeOS Linux** | Bash `install.sh` | ✓ | ✓ | ✓ | environment-dependent |
| **BSD / other Unix** | Bash `install.sh` | ✓* | ✓* | ✓* | platform-dependent |

`*` Requires Bash and a modern OpenSSH client.

See **[Platform support & X11 guide](docs/platforms.md)** for detailed Windows, macOS, Linux, WSL, GUI-forwarding, and host-key instructions.

> UTM lab hosts are reachable only while you are on the **U of T network** or connected through **UTORvpn**.

## Install

### Windows 10 / 11 — PowerShell

No WSL, Git Bash, or Cygwin required.

```powershell
$installer = "$env:TEMP\utm-shell-install.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.ps1 -OutFile $installer
& $installer
```

The installer uses the Windows OpenSSH client that ships as an optional Windows feature. If it is not installed, the script tells you exactly how to enable it.

### macOS / Linux / WSL

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.sh)
```

### Prefer to inspect first?

```bash
git clone https://github.com/andrewmuratov/utm-shell.git
cd utm-shell
```

Then run either:

```bash
./install.sh
```

or, on Windows:

```powershell
.\install.ps1
```

The installer asks for only what it needs:

```text
UTORid: yourutorid
UTM lab host (for example dh2026pc08): dh2026pc08
```

It can reuse an existing Ed25519 key or create a dedicated UTM key. Your UTORid password may be requested **once** while the public key is installed.

After setup, every supported platform uses the same command:

```text
ssh utm
```

```text
UTM yourutorid@dh2026pc08 ~
❯
```

## What it sets up

### On your computer

- creates a managed `Host utm` entry in your OpenSSH config
- remembers your UTORid and selected lab hostname
- configures secure public-key authentication
- keeps idle SSH sessions alive
- uses a dedicated or existing Ed25519 key without ever uploading the private key
- works with `ssh` and `scp` natively on Windows, macOS, and Linux
- keeps Unix SSH connection multiplexing enabled for faster repeated connections
- avoids Unix-only SSH multiplexing options in the native Windows configuration

### On the UTM machine

The remote side is the same no matter what OS you use locally:

- adds a clearly marked, removable block to `~/.bashrc`
- gives the remote shell a visually distinct blue `UTM` prompt
- fixes incompatible modern terminal `TERM` values when necessary
- improves Bash history and Up/Down prefix search
- adds a compact set of useful aliases/functions
- makes SSH login shells load the setup consistently
- hides the giant Ubuntu login/MOTD wall unless you opt out

It does **not** replace the university shell, install a framework, require root on the UTM machine, disable SSH host verification, or overwrite unrelated dotfile content.

## Included remote commands

| Command | What it does |
|---|---|
| `ll` | detailed listing including hidden files |
| `la` | list hidden files |
| `..`, `...`, `....` | move up directories |
| `c`, `cls` | clear the terminal |
| `reload` | reload `~/.bashrc` |
| `mkcd DIR` | create a directory and enter it |
| `ff NAME` | find files/directories by name below `.` |
| `disk` | show filesystem disk usage |
| `usage` | show sizes in the current directory |
| `path` | print `$PATH` one entry per line |
| `py` | run `python3` |
| `gs`, `gd`, `gl` | compact Git status/diff/log shortcuts |
| `utm-help` | show the command reference inside UTM |

History search is improved too: type the beginning of an old command, then press **↑/↓** to cycle through matching history entries.

## File transfer — every platform

OpenSSH includes `scp`, so the same commands work in Bash, macOS Terminal, Linux terminals, Windows Terminal, and PowerShell:

```bash
# local → UTM
scp exercise.py utm:~/exercise.py

# UTM → local
scp utm:~/result.txt ./result.txt

# whole directory
scp -r lab01 utm:~/labs/
```

`rsync` is also convenient on macOS/Linux/WSL when installed, but it is intentionally not required because native Windows does not ship it.

## Graphical apps / X11

UTM also supports X11 forwarding for graphical Linux applications.

```bash
ssh -Y utm
```

Local requirements differ:

- **Linux:** normally works with X11/XWayland already present
- **macOS:** install and launch **XQuartz**
- **Windows:** run an X server such as **MobaXterm**, **VcXsrv**, or **Xming**; native OpenSSH can then forward X11
- **WSL:** WSLg can provide the graphical side on supported systems

See **[docs/platforms.md](docs/platforms.md)** for exact setup. `-Y` is trusted X11 forwarding, so use it only with machines you trust.

## Diagnostics

If anything feels wrong, run the platform-native doctor.

macOS / Linux / WSL:

```bash
./doctor.sh
```

Windows PowerShell:

```powershell
.\doctor.ps1
```

The doctor checks OpenSSH, the managed config, alias resolution, passwordless key authentication, and remote reachability without changing your setup.

## Installer options

### Bash / macOS / Linux / WSL

```text
--user UTORID       UTORid used to log in
--host HOST         lab hostname, short or fully qualified
--alias NAME        local SSH alias (default: utm)
--key PATH          SSH private key to use
--skip-key-copy     do not install the public key on UTM
--no-hushlogin      keep the Ubuntu login banner
```

### Windows PowerShell

```text
-User UTORID
-HostName HOST
-Alias NAME
-KeyPath PATH
-SkipKeyCopy
-NoHushLogin
```

Short hostnames such as `dh2026pc08` automatically become `dh2026pc08.utm.utoronto.ca`.

## Uninstall

The setup is reversible.

macOS / Linux / WSL:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.sh)
```

Windows PowerShell:

```powershell
$uninstaller = "$env:TEMP\utm-shell-uninstall.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.ps1 -OutFile $uninstaller
& $uninstaller
```

The uninstaller removes only the marked `utm-shell` configuration, can remove the matching public key from UTM, and intentionally leaves a dedicated private key on your computer so deleting key material is always an explicit choice.

## Security and design

- SSH host verification stays enabled
- only your **public** key is copied to UTM
- private keys never leave your computer
- UTORid passwords are handled directly by OpenSSH and are never read or stored by utm-shell
- existing dotfile content is preserved outside managed marker blocks
- rerunning setup replaces its own block instead of duplicating it
- no analytics, telemetry, daemon, background service, or credential storage
- no administrator/root access is needed for the remote UTM setup

Windows may require administrator privileges **only if you need to install Microsoft's optional OpenSSH Client feature**. utm-shell itself does not silently elevate or install it.

See [SECURITY.md](SECURITY.md).

## Troubleshooting

**`Could not resolve hostname ...`**  
Use a real lab machine such as `dh2026pc08`, not the template `dh20XYpcNM`, and connect to campus Wi-Fi or UTORvpn.

**`Permission denied` while browsing `/student/...`**  
Normal. Student home directories are permission-protected.

**`xterm-ghostty: unknown terminal type` or another unknown terminal type**  
The managed remote setup falls back to `xterm-256color` when the UTM terminfo database does not recognize your local terminal.

**`REMOTE HOST IDENTIFICATION HAS CHANGED`**  
Do not disable host verification globally. Verify the hostname first, then remove only the stale host entry with `ssh-keygen -R <hostname>` if appropriate. See the platform guide.

**I changed lab computers.**  
Rerun the installer with the new hostname. Its managed SSH block is replaced rather than duplicated.

## Scope

This is a personal convenience project for University of Toronto Mississauga lab access. It is **not affiliated with, endorsed by, or maintained by the University of Toronto**. Official course and U of T IT instructions take precedence if infrastructure or policy changes.

The supported installer matrix covers modern desktop systems with OpenSSH: Windows 10/11, macOS, Linux, WSL, ChromeOS Linux, and Unix-like systems with Bash + OpenSSH. Mobile/locked-down systems without a standard OpenSSH environment can still connect manually but are not targets for the automated installer.

## License

[MIT](LICENSE) © 2026 Andrew Muratov
