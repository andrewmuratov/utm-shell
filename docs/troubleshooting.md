# Troubleshooting

Start with:

```text
utm doctor
```

## `Could not resolve hostname`

Make sure the host is real (for example `dh2026pc08`) and that you are on the U of T network or UTORvpn.

## Off campus / Cisco not installed

Run:

```text
utm vpn
```

`utm` opens the U of T VPN path for your OS. If your platform has no applicable U of T Cisco package, connect through campus networking or another supported VPN environment, then run `utm` again.

## `Permission denied`

Run:

```text
utm update
```

This retests the selected SSH key and repairs the managed setup. If UTM is reachable but a known-correct UTORid password is also rejected, see [login problems](login-problems.md).

## `REMOTE HOST IDENTIFICATION HAS CHANGED`

Do not disable host-key checking globally. Verify that you are using the intended lab host, then remove only the confirmed stale entry:

```sh
ssh-keygen -R dh2026pc08.utm.utoronto.ca
```

The same command works in Windows PowerShell with OpenSSH installed.

## `utm: command not found` right after install

Open a new terminal once so your shell reads the PATH change. The installer supports Bash, Zsh, Fish, Csh/Tcsh, Ksh and normal POSIX shell startup files.

## `unknown terminal type`

Reconnect. The managed UTM Bash shell falls back to `xterm-256color` when the lab machine does not know your local terminal's `TERM` entry.

## Windows says `ssh.exe` is missing

Install **OpenSSH Client** from Windows Optional Features, then paste the same setup command again.

## Still stuck

```text
utm status
utm doctor
utm update
```