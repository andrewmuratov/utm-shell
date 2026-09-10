# UTORvpn

UTM lab computers normally require the **U of T network**. Off campus, just run:

```text
utm
```

`utm` detects that VPN is needed and handles as much of setup as the OS allows.

## Ubuntu / Debian

1. `utm` opens U of T's official Cisco download page.
2. Click **Linux (DEB)**.
3. Leave the terminal open.
4. `utm-shell` detects the `.tgz`, extracts it, selects the **main VPN package** (not `vpn-cli`), stages it safely, and runs `apt` automatically.
5. Enter your computer's administrator password once when `sudo` asks.

You do **not** need to extract the archive, find the `.deb`, or type an install command yourself.

## Fedora / RHEL

1. Click **Linux (RPM)** on the page `utm` opens.
2. Leave the terminal open.
3. `utm-shell` detects the download, extracts it, selects the main VPN RPM, and runs `dnf`/`yum` automatically.
4. Approve the administrator-password prompt.

## Windows 10 / 11

1. Click **Windows** or **Windows ARM64** on the page `utm` opens.
2. Leave PowerShell open.
3. `utm-shell` detects the Cisco ZIP, extracts it, finds the `core-vpn` MSI, and starts that installer automatically.
4. Approve the Windows administrator prompt.

## macOS

1. Click **macOS** on the page `utm` opens.
2. `utm-shell` detects the downloaded DMG and opens it automatically.
3. Run the Cisco package and install only the **VPN** module.

macOS keeps the final package-install choice visible because U of T instructs users to select only the VPN module.

## WSL

Install Cisco Secure Client on **Windows**, not inside WSL. `utm-shell` detects and launches the Windows client from WSL. Once Windows is connected, WSL continues automatically.

## Other Linux / BSD

The SSH/setup side of `utm-shell` is portable POSIX `sh` and OpenSSH. U of T currently documents Cisco desktop installation for Windows, macOS, Debian-based Linux, and Fedora-based Linux. If your OS cannot use one of those packages, use campus networking or another U of T-supported VPN environment; `utm-shell` continues as soon as the UTM host becomes reachable.

## After Cisco is installed

`utm-shell` opens Cisco and shows only:

```text
1. Connect to general.vpn.utoronto.ca
2. Sign in with your UTORid and password
```

Then it waits for UTM to become reachable and continues automatically.

Official U of T links:

- [Cisco Secure Client download](https://uoft.me/cisco-vpn-download)
- [UTORvpn usage guide](https://security.utoronto.ca/services/vpn/usage-guide/)

If something fails, run `utm doctor`.
