# UTORvpn

UTM lab computers normally need either the **U of T campus network** or **UTORvpn**.

For normal use, just run:

```text
utm
```

If you're off campus, utm-shell handles the VPN flow for you.

## What utm-shell does

If Cisco Secure Client is already installed:

```text
UTORvpn
  1. Cisco Secure Client opened.
  2. Connect to general.vpn.utoronto.ca.
  3. Sign in with your UTORid and password.

Waiting for UTORvpn...
```

When the VPN connects, utm-shell continues automatically.

If Cisco is not installed, utm-shell opens the official U of T VPN instructions and shows short platform-specific install steps. It then waits for Cisco to appear, opens it automatically, and continues.

## Windows 10 / 11

```text
1. Download Cisco Secure Client for Windows.
2. Run the .msi installer.
3. Leave the terminal open.
```

Windows may request administrator approval during installation.

## macOS

```text
1. Download Cisco Secure Client for macOS.
2. Run the .pkg installer.
3. Install only the VPN module.
4. Leave the terminal open.
```

## Ubuntu / Debian

```text
1. Download Cisco Secure Client for Linux.
2. Extract the downloaded archive.
3. Open a terminal in the extracted folder.
4. Run:

   sudo apt install ./cisco-secure-client-vpn-*_amd64.deb
```

Leave the original utm-shell terminal open while installing.

## Fedora / Red Hat

```text
1. Download Cisco Secure Client for Linux.
2. Extract the downloaded archive.
3. Open a terminal in the extracted folder.
4. Install the VPN RPM with dnf.
```

Use the exact package filename supplied by U of T.

## WSL

Install Cisco Secure Client on **Windows**, not inside WSL. utm-shell detects the Windows client from WSL and launches it for you when possible.

## Connect

After installation:

```text
1. Open Cisco Secure Client.
2. Connect to general.vpn.utoronto.ca.
3. Sign in with your UTORid and password.
```

Official U of T instructions:

https://security.utoronto.ca/services/vpn/usage-guide/

If you get stuck:

```text
utm status
utm doctor
utm vpn
```

> utm-shell is an independent convenience project. U of T's current instructions take precedence.