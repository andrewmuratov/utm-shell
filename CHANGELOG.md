# Changelog

## 1.4.0 — 2026-09-09

- made the project fully centered on the single day-to-day command `utm`
- added `utm status` for an immediate host/network/VPN readiness check
- added `utm host HOST` so students can switch lab machines without editing SSH config
- added `utm files` with copy-to/from-UTM examples
- added `utm doctor` and `utm update` so troubleshooting and repairs no longer require cloning the repository
- made `utm update` reuse saved UTORid, host, and key information
- improved the off-campus flow so home/public-Wi-Fi failures are explained as a network/VPN issue before interactive SSH starts
- made Enter the simple default action for opening/setup of UTORvpn
- added automatic launch detection for Cisco Secure Client on Windows, macOS, and Linux
- added a dedicated UTORvpn guide with the current general server and UofT Default group
- made setup save local state before VPN-dependent steps so interrupted off-campus setup can safely resume
- made Windows setup open Optional Features when OpenSSH Client is missing
- refreshed the README and getting-started flow around one copy/paste setup command and a tiny command set
- bumped the managed remote shell to 1.4.0 and expanded CI smoke tests

## 1.3.0 — 2026-09-09

- added a smart local `utm` command as the recommended way to connect
- added a short preflight that detects common off-campus/network-unreachable failures before interactive SSH
- added clear UTORvpn guidance instead of leaving users at a long SSH timeout
- added `utm vpn` to launch Cisco Secure Client when installed or open U of T's official UTORvpn setup guide
- documented `general.vpn.utoronto.ca` as the general UTORvpn address
- made setup pause and offer VPN help when run off campus, then retry after the user connects
- added short SSH connect timeouts so raw `ssh utm` also fails quickly
- added the local `utm` helper on Windows, macOS, Linux, WSL, ChromeOS Linux, and supported Unix shells
- updated uninstallers to remove the smart helper
- expanded CI to parse and smoke-test the new connection helpers

## 1.2.0 — 2026-09-09

- replaced duplicated remote shell blocks with a single shared `remote.sh` installer
- fixed the Bash alias/function parse failure that could produce `syntax error near unexpected token '('`
- made rerunning setup repair older broken managed `~/.bashrc` blocks
- moved managed shell commands into `~/.config/utm-shell/shell.sh` for safer upgrades
- made `c`/`cls` clear the screen and scrollback without depending on remote terminfo
- fixed `usage` so hidden files are included and empty directories are explained
- made `py` a friendly `python3` wrapper
- made Git shortcuts report a friendly message outside repositories
- added `utm-version` and `bye`
- added one-command `setup.sh` and `setup.ps1` entrypoints
- reduced normal setup to two questions plus a one-time UTORid password prompt
- switched the default to a dedicated UTM SSH key to avoid key-selection prompts
- kept `install.sh` and `install.ps1` as compatibility wrappers
- expanded CI to syntax-check and smoke-test the new setup and remote shell files

## 1.1.1 — 2026-09-09

- made `usage` include hidden files and dot-directories instead of appearing empty in a fresh home directory
- made `py` a friendly `python3` wrapper with a clear error when Python is unavailable
- made `gs`, `gd`, and `gl` explain when the current directory is not a Git repository instead of exposing Git's raw fatal message
- added `utm-version` so users can quickly tell whether their remote shell setup is current
- expanded `utm-help` to describe the refined commands

## 1.1.0 — 2026-09-09

- added a native Windows PowerShell installer and uninstaller
- added Windows diagnostics with `doctor.ps1`
- expanded Unix support across macOS, Linux, WSL, ChromeOS Linux, BSD/Unix, and Windows Bash environments
- added cross-platform diagnostics with `doctor.sh`
- added a platform guide covering OpenSSH, SCP, X11 forwarding, and host-key warnings
- made the remote terminal compatibility fallback generic instead of Ghostty-only
- expanded GitHub Actions to validate Ubuntu, macOS, and Windows
- documented platform-specific security behavior

## 1.0.0 — 2026-09-09

- initial public release
- passwordless UTM SSH setup
- managed `ssh utm` alias
- clean remote Bash prompt and useful shell shortcuts
- reversible install/uninstall flow
