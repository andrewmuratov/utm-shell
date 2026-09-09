# Troubleshooting

## `Could not resolve hostname`

Use a real UTM lab hostname such as `dh2026pc08`, not the placeholder pattern `dh20XYpcNM`. Also make sure you are on campus Wi-Fi or connected to UTORvpn.

## `Permission denied (publickey,...)`

Run the installer again while UTM is reachable. It will test key authentication and copy the selected public key when necessary.

## `REMOTE HOST IDENTIFICATION HAS CHANGED`

Do not disable host-key checking globally. Verify the hostname, then remove only the confirmed stale entry:

```bash
ssh-keygen -R dh2026pc08.utm.utoronto.ca
```

The same command works with Windows OpenSSH in PowerShell.

## `unknown terminal type`

Reconnect after installing utm-shell. The remote Bash setup checks whether UTM knows the advertised `TERM` entry and falls back to `xterm-256color` when needed.

## `clear` does not work

Run:

```bash
printf '%s\n' "$TERM"
infocmp "$TERM" >/dev/null && echo known || echo unknown
```

If you installed utm-shell but still get an unknown terminal, run `reload` or reconnect.

## Windows says `ssh.exe` is missing

Install Microsoft's OpenSSH Client from Windows Optional Features, or from an elevated PowerShell:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

## X11 window does not appear

Command-line SSH can be working perfectly while X11 is not. Check the platform-specific graphical requirements in [platforms.md](platforms.md): XQuartz on macOS, an X server on Windows, or X11/XWayland/WSLg on Linux/WSL.

## Run the doctor

macOS/Linux/WSL:

```bash
bash doctor.sh
```

Windows:

```powershell
.\doctor.ps1
```
