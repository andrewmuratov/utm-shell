# Windows quick reference

Open PowerShell or Windows Terminal and paste:

```powershell
irm https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1 | iex
```

Then use:

```text
utm             connect
utm status      check readiness
utm vpn         open/setup UTORvpn
utm files       file-copy examples
utm doctor      diagnose
utm update      update/repair
```

If OpenSSH Client is missing, setup opens Windows Optional Features and tells you what to install.

For first-time UTORvpn, download the matching Windows Cisco bundle, extract it if needed, and run the MSI whose name contains **core-vpn**. `utm-shell` then launches Cisco and waits for the VPN automatically.