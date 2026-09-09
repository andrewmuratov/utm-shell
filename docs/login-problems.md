# Login problems

Use this page when the lab hostname resolves but SSH login still fails.

## 1. First check the network

UTM lab machines normally require either:

- U of T campus networking, or
- UTORvpn

If the hostname cannot be resolved or the connection times out, fix networking before changing authentication settings.

## 2. Check the hostname

Use a real machine name such as:

```text
dh2026pc08
```

Do not type placeholder examples such as `dh20XYpcNM` literally.

## 3. If the password prompt appears but says `Permission denied`

If you are sure the UTORid and password are correct, this can be a **server-side account provisioning problem** rather than an SSH configuration problem.

This is especially plausible when:

- the same credentials work for normal U of T services
- the lab host is reachable
- multiple lab machines reject the same account
- other students are seeing the same behavior

`utm-shell` cannot repair a UTORid that has not been loaded or enabled on the lab system.

Contact course staff or the relevant system administrator and include:

- your UTORid
- the lab hostname you tried
- the approximate time of the attempt
- the exact error text, with sensitive information removed

Never include your password or private SSH key.

## 4. If password login works but key login does not

Run the installer again and allow it to install your public key.

Then test:

```bash
ssh utm
```

If it still asks for a password, run:

```bash
./doctor.sh
```

or on Windows PowerShell:

```powershell
.\doctor.ps1
```

## 5. If the host key changed

If you see:

```text
REMOTE HOST IDENTIFICATION HAS CHANGED
```

Do not disable host checking globally.

Verify that you are connecting to the expected hostname. If the lab machine was legitimately reimaged and the stored key is stale, remove only that host's old entry with:

```bash
ssh-keygen -R dh2026pc08.utm.utoronto.ca
```

Then reconnect and verify the new host prompt before accepting it.

## 6. If the terminal says `xterm-...: unknown terminal type`

Reconnect after installing `utm-shell`. The remote setup checks whether UTM understands your terminal type and falls back to `xterm-256color` only when necessary.

## What not to do

Do not:

- disable SSH host verification globally
- paste your password into a script or issue report
- upload your private SSH key
- repeatedly regenerate keys when the actual problem is account provisioning
- assume every `Permission denied` means a bad password
