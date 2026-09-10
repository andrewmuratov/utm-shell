# CI coverage

`Validate` runs on every push and pull request.

It checks:

- Ubuntu: POSIX `sh`, Dash, Bash remote-shell tests
- macOS: POSIX `sh` + Bash remote-shell tests
- Alpine: BusyBox `sh` on a non-DEB/RPM Linux environment
- FreeBSD: real FreeBSD VM using base `sh`
- OpenBSD: real OpenBSD VM using base `sh`
- Windows: native PowerShell parser + CLI smoke tests

These tests do not log into a real UTM account. Live SSH still depends on U of T networking, the selected lab host, and account provisioning.