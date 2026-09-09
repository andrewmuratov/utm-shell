# macOS / Linux / WSL quick reference

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/install.sh)
```

## Connect

```bash
ssh utm
```

## Copy files

```bash
scp exercise.py utm:~/exercise.py
scp utm:~/result.txt ./result.txt
scp -r lab01 utm:~/labs/
```

## Diagnose

From a cloned copy of the repository:

```bash
bash doctor.sh
```

## Uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/uninstall.sh)
```

For X11 forwarding and platform-specific details, see [platforms.md](platforms.md).
