# Security

`utm-shell` modifies SSH configuration and installs a public key on a university account, so changes should be treated with care.

## Guarantees and design goals

The project should never:

- collect, echo, log, or transmit a UTORid password itself
- copy a private SSH key to the UTM machine
- commit or upload private key material
- disable SSH host-key verification globally
- add `StrictHostKeyChecking no` as a convenience workaround
- silently elevate privileges
- require root/administrator access for the remote UTM setup
- modify unrelated dotfile content outside clearly marked managed blocks
- add analytics, telemetry, background agents, or network services

On macOS/Linux/WSL, the Bash installer uses `ssh-copy-id` when available and otherwise appends the selected **public** key through an ordinary SSH session. On Windows, the PowerShell installer performs the same public-key operation through Microsoft's OpenSSH client. In both cases, any UTORid password prompt is displayed and handled by OpenSSH itself; utm-shell does not read or store that password.

The Windows installer does not silently install Windows optional features. If Microsoft's OpenSSH Client is missing, it stops and gives the user the standard Windows installation command/UI path. Installing that optional feature can require administrator privileges; running utm-shell itself does not.

## Host verification

A first connection to a lab hostname can legitimately require accepting a host key. A later `REMOTE HOST IDENTIFICATION HAS CHANGED` warning should **not** be bypassed by weakening global SSH settings. Verify the intended UTM hostname first and remove only a confirmed stale `known_hosts` entry.

## Reporting a concern

For non-sensitive security bugs, open a GitHub issue with a minimal reproduction. Do **not** paste passwords, private keys, access tokens, personal data, or live credentials into an issue.

If the report itself contains sensitive information, use GitHub's private vulnerability-reporting/security-advisory flow when available rather than a public issue.
