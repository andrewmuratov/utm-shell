# Changelog

## 1.5.0 — 2026-09-09

- reduced first-time setup to one normal question: the student's UTORid
- defaulted new installs to `dh2026pc08`; switching hosts remains available through `utm host HOST`
- made setup adopt an existing/manual `Host utm` configuration when possible
- made setup reuse an already-authorized local SSH key automatically when one works
- removed the interactive VPN retry menu and repeated network explanation
- when Cisco Secure Client is installed, `utm` now opens it and waits for UTORvpn automatically
- when Cisco Secure Client is missing, `utm` opens U of T's official Cisco download shortcut directly
- made interrupted off-campus setup resumable by simply pasting the same setup command again
- shortened setup output, `utm help`, status output, file-copy help, and remote help
- removed the hard-coded VPN group; U of T's current public guide only specifies `general.vpn.utoronto.ca`
- refreshed the README and getting-started docs around the shortest normal workflow

## 1.4.0 — 2026-09-09

- made the project fully centered on the single day-to-day command `utm`
- added `utm status` for an immediate host/network/VPN readiness check
- added `utm host HOST` so students can switch lab machines without editing SSH config
- added `utm files` with copy-to/from-UTM examples
- added `utm doctor` and `utm update` so troubleshooting and repairs no longer require cloning the repository
- made `utm update` reuse saved UTORid, host, and key information
- improved the off-campus flow so home/public-Wi-Fi failures are explained as a network/VPN issue before interactive SSH starts
- added automatic launch detection for Cisco Secure Client on Windows, macOS, and Linux
- added a dedicated UTORvpn guide with the general VPN server
- made setup save local state before VPN-dependent steps so interrupted off-campus setup can safely resume
- made Windows setup open Optional Features when OpenSSH Client is missing
- bumped the managed remote shell to 1.4.0 and expanded CI smoke tests

## 1.3.0 — 2026-09-09

- added the smart local `utm` command
- added off-campus/network reachability checks and UTORvpn help
- added automatic Cisco Secure Client launching where available
- added cross-platform local helpers and diagnostics

## 1.2.0 — 2026-09-09

- moved remote customizations into a managed shell file
- fixed upgrade-time Bash alias/function parse errors
- made setup rerunnable and self-repairing
- added `c`, `usage`, `py`, friendly Git shortcuts, `utm-version`, and `bye`
- added one-command setup entrypoints for Bash and PowerShell

## 1.1.0 — 2026-09-09

- added native Windows PowerShell support
- expanded macOS, Linux, WSL, ChromeOS Linux, BSD/Unix, and Windows Bash support
- added diagnostics and cross-platform CI

## 1.0.0 — 2026-09-09

- initial public release
- passwordless UTM SSH setup
- managed `ssh utm` alias
- clean remote Bash prompt and useful shell shortcuts
