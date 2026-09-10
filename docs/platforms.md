# Platform support

`utm-shell` has two separate pieces:

- **local client:** runs on your computer and is portable across Windows and Unix-like systems
- **remote shell:** runs on the UTM lab computer, which already provides Bash

That means your own Unix-like computer does **not** need Bash. The Unix installer/client are POSIX `sh` scripts.

| Platform | One-line install | SSH / SCP | Automatic Cisco launch | Off-campus note |
|---|---:|---:|---:|---|
| Windows 10/11 | ✓ PowerShell | ✓ | ✓ | U of T Cisco client |
| macOS | ✓ `sh` | ✓ | ✓ | U of T Cisco client |
| Ubuntu / Debian | ✓ `sh` | ✓ | ✓ | U of T DEB client |
| Fedora / RHEL | ✓ `sh` | ✓ | ✓ | U of T RPM client |
| WSL | ✓ `sh` | ✓ | ✓ via Windows | install Cisco on Windows |
| ChromeOS Linux | ✓ `sh` | ✓ | when compatible | network/VPN support varies |
| Arch / Alpine / Gentoo / NixOS / other Linux | ✓ `sh` | ✓ | when Cisco is compatible | U of T publishes DEB/RPM packages |
| FreeBSD | ✓ base `fetch` + `sh` | ✓ | — | campus or separate supported VPN path |
| OpenBSD | ✓ base `ftp` + `sh` | ✓ | — | campus or separate supported VPN path |
| NetBSD / DragonFlyBSD / other Unix | ✓ with a downloader + `sh` | ✓ | platform-dependent | network/VPN support varies |

## Install commands

### Windows

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

### macOS / Linux / WSL / ChromeOS Linux

```sh
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

If `curl` is absent, the installer itself also understands `wget`, FreeBSD `fetch`, and OpenBSD `ftp`.

### FreeBSD

```sh
fetch -q -o - https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

### OpenBSD

```sh
ftp -V -o - https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

## Local shell compatibility

The installer adds `~/.local/bin` to the appropriate startup file for common shells:

- Bash → `~/.bashrc`
- Zsh → `~/.zshrc`
- Fish → `~/.config/fish/conf.d/utm-shell.fish`
- Csh/Tcsh → `~/.cshrc` or `~/.tcshrc`
- Ksh and other POSIX shells → `~/.profile`

Open a new terminal once after first install if your current shell has not picked up the PATH change yet.

## Requirements

The local Unix path needs:

- a POSIX `sh`
- OpenSSH client (`ssh`, `ssh-keygen`; `scp` for file copying)
- `awk`, `mktemp`, and normal base-system utilities
- one downloader: `curl`, `wget`, FreeBSD `fetch`, or OpenBSD `ftp`

No local Bash, Python, Node, package manager, or Git checkout is required.

## VPN support vs. shell support

Do not confuse **utm-shell support** with **Cisco's platform support**. `utm-shell` can configure and use SSH on BSD and non-DEB/RPM Linux systems, but U of T's current Cisco Secure Client instructions are for Windows, macOS, and Linux, with Linux packages documented for Debian- and Fedora-based systems.

If your platform has no U of T-supported Cisco package, `utm` still behaves cleanly: it explains the limitation and waits for UTM to become reachable instead of failing with a misleading SSH/password error.

## Validation

CI validates:

- Ubuntu + Bash/Dash
- macOS
- Windows PowerShell
- Alpine/BusyBox `sh` as a non-DEB/RPM Linux environment
- real FreeBSD VM
- real OpenBSD VM

The tests cover script parsing and CLI smoke tests without requiring a live UTM account. A real UTM login still depends on U of T networking, account provisioning, and the lab service itself.