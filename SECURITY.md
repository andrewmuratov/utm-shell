# Security

utm-shell handles SSH configuration, so changes should be treated with care.

## What the project should never do

- collect or transmit UTORid passwords
- copy a private SSH key to the UTM machine
- commit or log private key material
- weaken SSH host verification globally
- require `sudo` or root access
- modify files outside clearly scoped user-owned configuration

The installer may invoke `ssh-copy-id`, which sends only the **public** key and can ask OpenSSH for your UTORid password directly. utm-shell does not read or store that password.

## Reporting a concern

For non-sensitive security bugs, open a GitHub issue with a minimal reproduction. Do **not** paste passwords, private keys, access tokens, personal data, or live credentials into an issue.

If a report itself contains sensitive information, use GitHub's private vulnerability reporting/security-advisory flow if it is available for this repository rather than a public issue.
