# UTORvpn

UTM lab computers normally need either the **U of T campus network** or **UTORvpn**.

For normal use, just run:

```text
utm
```

If you're off campus, `utm-shell` detects your platform and guides the VPN setup automatically.

Official U of T links:

- [Download Cisco Secure Client](https://uoft.me/cisco-vpn-download)
- [UTORvpn usage guide](https://security.utoronto.ca/services/vpn/usage-guide/)

## Windows 10 / 11

1. On the U of T download page, choose the **Windows** client. Use the ARM64 download only on ARM-based Windows devices.
2. If the download is a `.zip`, extract it.
3. Run the Cisco Secure Client `.msi` installer.
4. Accept the licence and finish installation.

`utm-shell` keeps waiting in the original PowerShell window and detects Cisco when installation finishes.

## macOS

1. On the U of T download page, choose the **macOS** client.
2. Open the downloaded `.dmg`.
3. Run the Cisco Secure Client `.pkg` installer.
4. Accept the licence agreement.
5. Uncheck every module except **VPN**, then finish installation.

Keep the original terminal open while installing.

## Ubuntu / Debian

1. On the U of T download page, choose **Linux (DEB)**.
2. Download and extract the `.tgz` archive.
3. Open a terminal in the extracted directory.
4. Install the **main VPN package**, not `vpn-cli`:

```bash
sudo apt install ./cisco-secure-client-vpn_*_amd64.deb
```

The underscore after `vpn` is intentional. It selects the GUI VPN package and avoids the separate `cisco-secure-client-vpn-cli` package.

Enter your computer password and confirm with `y` if prompted. Keep the original `utm-shell` terminal open.

## Fedora / Red Hat

1. On the U of T download page, choose **Linux (RPM)**.
2. Download and extract the `.tgz` archive.
3. Open a terminal in the extracted directory.
4. Install the **main VPN package**, not `vpn-cli`:

```bash
sudo dnf install ./cisco-secure-client-vpn-[0-9]*.rpm
```

Enter your computer password and confirm if prompted. Keep the original `utm-shell` terminal open.

## WSL

Install Cisco Secure Client on **Windows**, not inside WSL:

1. Choose the Windows client on the U of T download page.
2. Extract the ZIP if needed and run the `.msi` in Windows.
3. Return to WSL. `utm-shell` detects and launches the Windows Cisco client when possible.

## Connecting after installation

Once Cisco is installed, `utm-shell` opens it and shows:

```text
UTORvpn
  1. Cisco Secure Client opened.
  2. Enter general.vpn.utoronto.ca and select Connect.
  3. Sign in with your UTORid and password.

Waiting for UTORvpn...
```

When the VPN connects, `utm-shell` continues automatically.

If you get stuck:

```text
utm status
utm doctor
utm vpn
```

> `utm-shell` is an independent convenience project. U of T's current instructions take precedence.