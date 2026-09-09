# UTORvpn

Off campus, UTM lab computers normally need **UTORvpn**.

Most users do not need to read this page. Just run:

```text
utm
```

If UTM is unreachable, utm-shell handles the next step automatically.

## What happens

### Cisco Secure Client is already installed

`utm` opens it and waits for the VPN to connect.

Connect to:

```text
general.vpn.utoronto.ca
```

Sign in with your UTORid and password. Once the lab network becomes reachable, utm-shell continues automatically.

### Cisco Secure Client is not installed

`utm` opens U of T's official Cisco Secure Client download page.

Install the **VPN** module, then run `utm` again.

Official U of T instructions:

https://security.utoronto.ca/services/vpn/usage-guide/

Direct U of T download shortcut:

https://uoft.me/cisco-vpn-download

## Platform notes

**Windows / macOS / Linux:** Cisco Secure Client runs directly on the computer.

**WSL:** run Cisco Secure Client on the Windows host, then return to WSL and run `utm`.

**Linux package install:** U of T's current guide provides Debian/Ubuntu and Fedora/RHEL package instructions after you download and extract Cisco Secure Client.

Desktop installation may require administrator access.

## Manual VPN helper

At any time:

```text
utm vpn
```

That opens Cisco Secure Client if present, otherwise the official U of T download page.

## Still not working?

```text
utm status
utm doctor
```

If UTM is reachable but a known-correct password is rejected, see [Login problems](login-problems.md).

utm-shell does not redistribute Cisco software, store your UTORid password, or bypass U of T authentication.
