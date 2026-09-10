# Unix quick reference

For macOS, Linux, WSL and ChromeOS Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

FreeBSD:

```sh
fetch -q -o - https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
```

OpenBSD:

```sh
ftp -V -o - https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh
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

You do not need Bash on your own Unix machine. The local installer/client use POSIX `sh`; Bash is used only on the UTM lab machine.