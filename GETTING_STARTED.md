# Getting Started

This guide assumes you have never used SSH before.

You do **not** need a GitHub account.

## Before you start

Have these ready:

- your **UTORid**
- the name of a real UTM lab computer, such as `dh2026pc08`
- either U of T campus Wi-Fi or **UTORvpn**

A hostname containing placeholders such as `dh20XYpcNM` is only an example format and will not work as typed.

## Windows 10 / 11

1. Open the Start menu.
2. Search for **PowerShell** or open **Windows Terminal** and choose PowerShell.
3. Paste these three lines and press Enter:

```powershell
$installer = "$env:TEMP\utm-shell-install.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.ps1 -OutFile $installer
& $installer
```

4. Enter your UTORid when asked.
5. Enter the lab hostname when asked.
6. If OpenSSH asks whether you trust a new host for the first time, check that the hostname is the one you intended to use before accepting it.
7. Your UTORid password may be requested once while the public key is installed. Password characters are normally invisible while you type; that is expected.

When the installer says it is finished, connect with:

```powershell
ssh utm
```

## macOS

1. Open **Terminal** from Applications → Utilities, Spotlight, or Launchpad.
2. Paste:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.sh)
```

3. Enter your UTORid and lab hostname when prompted.
4. Your UTORid password may be requested once while the public key is installed.
5. Connect with:

```bash
ssh utm
```

## Linux / WSL / ChromeOS Linux

Open your terminal and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.sh)
```

Then connect with:

```bash
ssh utm
```

## What success looks like

After `ssh utm`, you should see something similar to:

```text
UTM yourutorid@dh2026pc08 ~
❯
```

You are now working on the remote UTM lab computer. Commands you enter run there until you type:

```bash
exit
```

## Three useful things to know

### Clear the terminal

```bash
c
```

or:

```bash
clear
```

### See the added shortcuts

```bash
utm-help
```

### Copy a file to UTM

Run this on **your own computer**, not inside the SSH session:

```bash
scp exercise.py utm:~/exercise.py
```

## If it asks for your password every time

Run the installer again and let it configure public-key login. If key setup fails even though the hostname and password are correct, see [Login problems](docs/login-problems.md).

## If it says `Permission denied`

Do not assume your password is wrong. If the host is reachable but login fails with correct credentials, the problem can be account provisioning on the lab system. See [Login problems](docs/login-problems.md).

## If the hostname cannot be found

Check all three:

1. you used a real machine name such as `dh2026pc08`
2. you are on campus Wi-Fi or UTORvpn
3. there is no typo in the hostname

## Safety

Never send anyone:

- your UTORid password
- your private SSH key
- authentication tokens

Course staff or system administrators may reasonably ask for your UTORid and the hostname you tried, but they do not need your password.
