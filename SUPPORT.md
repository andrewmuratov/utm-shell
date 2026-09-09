# Support policy

## Supported

- Windows 10/11 with Microsoft OpenSSH Client and PowerShell 5.1 or PowerShell 7+
- macOS with the system OpenSSH client
- mainstream Linux distributions with Bash and OpenSSH
- WSL
- ChromeOS Linux development environment
- BSD/other Unix-like systems where Bash and OpenSSH are available
- Git Bash/MSYS2/Cygwin as a secondary Windows path

## Tested automatically

Every push is syntax/smoke-tested on GitHub Actions using:

- `ubuntu-latest`
- `macos-latest`
- `windows-latest`

The CI checks the Bash installers/diagnostics and parses/smoke-tests the PowerShell installers/diagnostics.

## External dependencies

A working UTM connection also depends on University infrastructure outside this repository: the selected lab hostname must exist and the client must be connected to the U of T network or UTORvpn.

X11/GUI forwarding additionally depends on a local graphical stack (for example XQuartz on macOS or an X server on Windows) and is therefore documented as an optional feature rather than part of the core SSH health check.

## Not targeted by the automated installers

Mobile/locked-down operating systems without a standard OpenSSH + shell environment are not automated. They can still use an SSH client manually if it supports the required connection settings.
