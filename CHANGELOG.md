# Changelog

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
