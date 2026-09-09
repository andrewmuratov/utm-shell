# UTORvpn

UTM lab computers normally require the **U of T network**. If you are at home, off campus, on public Wi-Fi, or on another network, connect to **UTORvpn** before using the lab machines.

`utm-shell` makes this easier:

```text
utm
```

If the lab network is unreachable, `utm` explains why and offers to open Cisco Secure Client or the official U of T VPN instructions.

You can also open VPN help directly:

```text
utm vpn
```

## Connection details

U of T's current general VPN connection is:

```text
Server: general.vpn.utoronto.ca
Group:  UofT Default
```

Sign in with your **UTORid and UTORid password**.

Official U of T instructions:

https://security.utoronto.ca/services/vpn/usage-guide/

## Windows 10 / 11

1. Run `utm vpn`.
2. If Cisco Secure Client is installed, it opens automatically.
3. Otherwise the official U of T setup page opens.
4. Install **Cisco Secure Client** using U of T's instructions.
5. Open Cisco Secure Client and connect to `general.vpn.utoronto.ca`.
6. Choose **UofT Default** when a group is requested.
7. Sign in with your UTORid and password.
8. Return to the terminal and run `utm`.

Installing the desktop VPN client may require administrator permission.

## macOS

1. Run `utm vpn`.
2. If Cisco Secure Client is installed, it opens automatically.
3. Otherwise the official U of T setup page opens.
4. Install Cisco Secure Client. U of T's instructions say to install the **VPN** module; other Cisco modules are not needed for UTORvpn.
5. Connect to `general.vpn.utoronto.ca` and sign in.
6. Return to the terminal and run `utm`.

## Ubuntu / Debian Linux

Run:

```text
utm vpn
```

If Cisco Secure Client is already installed, its UI opens. Otherwise the official U of T guide opens.

U of T currently distributes a Cisco Secure Client package. After downloading and extracting it according to the official instructions, Debian-based systems such as Ubuntu can install the VPN package with the package filename supplied by U of T, for example:

```bash
sudo apt install ./cisco-secure-client-vpn-[version]_amd64.deb
```

Then open Cisco Secure Client, connect to `general.vpn.utoronto.ca`, and sign in with your UTORid.

## Fedora / Red Hat Linux

After downloading and extracting the U of T Cisco Secure Client package, the official instructions use the RPM package, for example:

```bash
sudo dnf install ./cisco-secure-client-vpn-[version].x86-64.rpm
```

Then connect to `general.vpn.utoronto.ca` in Cisco Secure Client.

## WSL

UTORvpn normally runs on the **Windows host**, not inside WSL. Install/connect Cisco Secure Client in Windows, then return to WSL and run:

```text
utm
```

## Why utm-shell does not silently install Cisco

The Cisco package is distributed through U of T's current installation flow and desktop installation requires administrator access. `utm-shell` therefore does not redistribute Cisco software or silently elevate privileges. It instead:

- detects when the UTM lab network is unreachable
- opens an already-installed Cisco Secure Client automatically
- otherwise opens U of T's current official installation guide
- waits for you to connect and then retries

This keeps the setup simple without bypassing U of T's software distribution or security process.

## Still cannot connect?

Run:

```text
utm status
utm doctor
```

If UTM is reachable but a known-correct password is rejected, see [Login problems](login-problems.md). That can be an account-provisioning issue rather than a VPN problem.

> `utm-shell` is an independent convenience project. U of T's current official instructions take precedence if VPN software, addresses, or policies change.
