# Platform support

`utm-shell` supports the major desktop operating systems used to connect to UTM lab machines.

| Platform | Installer | SSH / SCP | Passwordless keys | X11 GUI forwarding |
|---|---|---:|---:|---:|
| Windows 10/11 | `install.ps1` | ✓ | ✓ | ✓ with an X server |
| macOS (Intel / Apple Silicon) | `install.sh` | ✓ | ✓ | ✓ with XQuartz |
| Linux | `install.sh` | ✓ | ✓ | ✓ when an X server/XWayland is available |
| WSL | `install.sh` | ✓ | ✓ | ✓ through WSLg/X server |
| ChromeOS Linux environment | `install.sh` | ✓ | ✓ | depends on Linux GUI support |
| BSD / other Unix | `install.sh` | ✓ when Bash + OpenSSH are installed | ✓ | platform-dependent |

The UTM machine itself runs Linux/Bash, so the remote shell setup is identical regardless of the operating system on your own computer.

> You still need to be on the U of T network or connected through **UTORvpn** before a UTM lab hostname can be reached.

## Windows 10 / 11

Use **PowerShell** or **Windows Terminal**. The native installer does not require WSL, Git Bash, Cygwin, or a Unix compatibility layer.

```powershell
$installer = "$env:TEMP\utm-shell-install.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.ps1 -OutFile $installer
& $installer
```

If `ssh.exe` is missing, install **OpenSSH Client** from:

**Settings → System → Optional features → View features → OpenSSH Client**

or from an elevated PowerShell:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

After setup:

```powershell
ssh utm
scp .\exercise.py utm:~/exercise.py
scp utm:~/result.txt .\result.txt
```

Diagnostics:

```powershell
.\doctor.ps1
```

Uninstall:

```powershell
.\uninstall.ps1
```

### Windows X11 / graphical applications

Native OpenSSH can forward X11, but Windows needs an X server such as **MobaXterm**, **VcXsrv**, or **Xming** running locally.

With an X server running, a common PowerShell setup is:

```powershell
$env:DISPLAY = '127.0.0.1:0.0'
ssh -Y utm
```

Then on the UTM machine you can test with an X11 application such as `xeyes` when available.

`-Y` enables **trusted X11 forwarding**. Use it only with machines you trust. Normal command-line work does not need X11 forwarding.

## macOS

OpenSSH ships with macOS. Run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.sh)
```

After setup:

```bash
ssh utm
scp exercise.py utm:~/exercise.py
scp utm:~/result.txt ./result.txt
```

Diagnostics:

```bash
./doctor.sh
```

### macOS X11 / graphical applications

macOS does not ship an X server. Install and launch **XQuartz**, then open a new terminal and use:

```bash
ssh -Y utm
```

If XQuartz was just installed, logging out and back in may be required before `DISPLAY` integration works correctly.

## Linux

Most distributions already include an OpenSSH client. Install with your distribution package manager if `ssh -V` fails.

Then run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.sh)
```

Examples:

```bash
ssh utm
scp exercise.py utm:~/exercise.py
scp utm:~/result.txt ./result.txt
```

For graphical forwarding, Linux desktop environments generally already have X11 or XWayland support:

```bash
ssh -Y utm
```

## WSL

Treat WSL as Linux and run `install.sh` inside your WSL distribution. Your SSH config and key live inside that distribution's Linux home directory.

On Windows 11 with WSLg, remote Linux GUI applications may work through:

```bash
ssh -Y utm
```

If you instead run `ssh` from native PowerShell, use `install.ps1`; native Windows and WSL have separate home directories and therefore separate SSH configuration unless you intentionally share them.

## Terminal compatibility

The remote UTM image can be older than your local terminal emulator. Modern terminals may advertise a `TERM` value the UTM terminfo database does not know.

The setup keeps the remote shell compatible by falling back to `xterm-256color` when necessary. This covers terminals such as Ghostty without changing your local terminal configuration.

## Host-key warnings

The first connection to a lab machine may ask you to confirm its SSH host key. That is normal for a hostname you have never used before.

If OpenSSH later reports **REMOTE HOST IDENTIFICATION HAS CHANGED**, do not globally disable host verification. UTM lab machines may be reimaged, but an unexpected key change can also indicate a security problem. Verify that you are using the intended UTM hostname, then remove only the stale entry with:

```bash
ssh-keygen -R dh2026pc08.utm.utoronto.ca
```

The same command works in PowerShell when Windows OpenSSH is installed.

## What "cross-platform" means here

The project supports operating systems that can run a modern OpenSSH client. Mobile operating systems and locked-down systems without OpenSSH are outside the supported installer matrix, although any compatible SSH client can still connect manually using the same hostname and UTORid.
