# Windows quick reference

Use PowerShell or Windows Terminal.

## Install

```powershell
$installer = "$env:TEMP\utm-shell-install.ps1"
Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.ps1 -OutFile $installer
& $installer
```

## Connect

```powershell
ssh utm
```

## Copy files

```powershell
scp .\exercise.py utm:~/exercise.py
scp utm:~/result.txt .\result.txt
scp -r .\lab01 utm:~/labs/
```

## Diagnose

From a cloned copy of the repository:

```powershell
.\doctor.ps1
```

## Uninstall

```powershell
$uninstaller = "$env:TEMP\utm-shell-uninstall.ps1"
Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.ps1 -OutFile $uninstaller
& $uninstaller
```

For OpenSSH installation and optional X11 forwarding, see [platforms.md](platforms.md#windows-10--11).
