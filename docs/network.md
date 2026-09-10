# Network requirement

UTM lab SSH hosts normally require either:

- the **U of T campus network**, or
- **UTORvpn**.

For normal use, just type:

```text
utm
```

On a supported desktop OS, `utm` opens Cisco Secure Client when the VPN is needed and waits for the connection. On a platform without a U of T-supported Cisco package, establish a U of T network path separately and `utm` continues once the lab host is reachable.

A DNS/timeout error can therefore mean the VPN/network path is missing, not that your UTORid password is wrong.