# Network requirement

UTM lab SSH hosts are not generally reachable from the public Internet. Connect through either:

- the U of T campus network, or
- UTORvpn

before running the installer, `ssh utm`, `scp`, diagnostics, or X11 forwarding.

A DNS error such as `Could not resolve hostname` can mean either the hostname is a placeholder/typo or the required U of T network path is not active.
