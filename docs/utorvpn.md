# UTORvpn

UTM lab computers are normally reachable only from the **U of T network** or through **UTORvpn**.

You usually do not need to think about this. Just run:

```text
utm
```

If UTM is not reachable, `utm` opens the right VPN path for your operating system and waits for you.

## Windows 10 / 11

1. Download **Cisco Secure Client for Windows** from U of T. Use the ARM64 download only on an ARM Windows PC.
2. Extract the ZIP if the download is zipped.
3. Run the `.msi` whose name contains **core-vpn** and finish the installer.
4. Cisco opens. Connect to `general.vpn.utoronto.ca` and sign in with your UTORid.

## macOS

1. Download **Cisco Secure Client for macOS** from U of T.
2. Open the downloaded installer and run the Cisco package.
3. Leave only the **VPN** module selected, then finish installation.
4. Cisco opens. Connect to `general.vpn.utoronto.ca` and sign in with your UTORid.

## Ubuntu / Debian

1. Choose **Linux (DEB)** on U of T's Cisco download page and download the `.tgz`.
2. Extract it.
3. In the extracted directory, install the **main VPN package**, not `vpn-cli`:

```bash
sudo apt install ./cisco-secure-client-vpn_*_amd64.deb
```

4. Cisco opens. Connect to `general.vpn.utoronto.ca` and sign in with your UTORid.

## Fedora / RHEL

1. Choose **Linux (RPM)** and download the `.tgz`.
2. Extract it.
3. In the extracted directory, install the main VPN package:

```bash
sudo dnf install ./cisco-secure-client-vpn-[0-9]*.rpm
```

4. Cisco opens. Connect to `general.vpn.utoronto.ca` and sign in with your UTORid.

## WSL

Install Cisco Secure Client on **Windows**, not inside WSL. `utm-shell` can detect and launch the Windows Cisco client from WSL. Once Windows is connected to UTORvpn, the WSL `utm` command continues automatically.

## Other Linux distributions

The local `utm-shell` installer and SSH workflow are distribution-independent: they use POSIX `sh` and OpenSSH rather than `apt` or `rpm`.

U of T currently documents Cisco desktop packages for Debian-based and Fedora-based Linux. If your distribution can install one of those packages compatibly, use the matching U of T package. Otherwise, connect from the U of T campus network or establish U of T-supported VPN connectivity separately; `utm-shell` will continue as soon as the UTM host becomes reachable.

## FreeBSD / OpenBSD / other BSD

`utm-shell` itself works natively with the base shell/OpenSSH toolchain. U of T does not currently publish a Cisco Secure Client package for BSD, so off-campus VPN connectivity must come from a supported environment or another network path. On campus, no VPN client is needed.

## What `utm` does

Once Cisco is installed on a supported desktop platform, normal off-campus use is:

```text
utm
```

`utm` opens Cisco, shows only these steps, and waits:

```text
UTORvpn
  1. Cisco Secure Client opened.
  2. Enter general.vpn.utoronto.ca and select Connect.
  3. Sign in with your UTORid and password.
```

If first-time setup is interrupted while you install/connect VPN, you do **not** need to paste the installer again. When the network is ready, run `utm`; it finishes setup for you.

Official U of T links:

- [Cisco Secure Client download](https://uoft.me/cisco-vpn-download)
- [UTORvpn usage guide](https://security.utoronto.ca/services/vpn/usage-guide/)

If you get stuck, run `utm doctor`.