#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.3.0"
REPO_RAW="https://raw.githubusercontent.com/andrewmuratov/utm-shell/main"
SSH_ALIAS="utm"
UTORID=""
UTM_HOST=""
KEY_PATH=""
USE_HUSHLOGIN=1
SKIP_KEY_COPY=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BLUE="" GREEN="" YELLOW="" RED="" DIM="" RESET=""
fi

info() { printf '%s•%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
utm-shell setup

Normal use: run it and answer two questions.

Options:
  --user UTORID
  --host HOST
  --alias NAME
  --key PATH
  --skip-key-copy
  --no-hushlogin
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) [[ $# -ge 2 ]] || die "--user needs a value"; UTORID="$2"; shift 2 ;;
    --host) [[ $# -ge 2 ]] || die "--host needs a value"; UTM_HOST="$2"; shift 2 ;;
    --alias) [[ $# -ge 2 ]] || die "--alias needs a value"; SSH_ALIAS="$2"; shift 2 ;;
    --key) [[ $# -ge 2 ]] || die "--key needs a value"; KEY_PATH="$2"; shift 2 ;;
    --skip-key-copy) SKIP_KEY_COPY=1; shift ;;
    --no-hushlogin) USE_HUSHLOGIN=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

for cmd in ssh ssh-keygen awk mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done

fetch() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url"
  else
    die "curl or wget is required"
  fi
}

read_tty() {
  local var="$1" prompt="$2" value=""
  [[ -r /dev/tty ]] || die "No interactive terminal. Pass --user and --host."
  printf '%s: ' "$prompt" >/dev/tty
  IFS= read -r value </dev/tty || die "Could not read input"
  [[ -n "$value" ]] || die "$prompt cannot be empty"
  printf -v "$var" '%s' "$value"
}

replace_block() {
  local file="$1" start="$2" end="$3" body="$4" tmp
  mkdir -p "$(dirname "$file")"
  touch "$file"
  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" '
    $0 == start { skip=1; next }
    $0 == end   { skip=0; next }
    !skip       { print }
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
  printf '\n%s\n%s\n%s\n' "$start" "$body" "$end" >> "$file"
}

printf '\n%sutm-shell%s %s\n' "$BLUE" "$RESET" "$VERSION"
printf '%sSet up UTM lab access in about a minute.%s\n\n' "$DIM" "$RESET"

[[ -n "$UTORID" ]] || read_tty UTORID "UTORid"
[[ -n "$UTM_HOST" ]] || read_tty UTM_HOST "Lab computer (example: dh2026pc08)"

[[ "$UTORID" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid UTORid"
[[ "$SSH_ALIAS" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid SSH alias"
[[ "$UTM_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || die "Invalid lab hostname"
[[ "$UTM_HOST" == *.* ]] || UTM_HOST="${UTM_HOST}.utm.utoronto.ca"

STATE_DIR="$HOME/.config/utm-shell"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$HOME/.ssh" "$STATE_DIR" "$BIN_DIR"
chmod 700 "$HOME/.ssh" 2>/dev/null || true

# Keep setup predictable: use a dedicated UTM key by default. If this machine
# was already configured by utm-shell, keep using the previous key.
if [[ -z "$KEY_PATH" && -r "$STATE_DIR/config" ]]; then
  previous_key="$(awk -F= '$1=="KEY_PATH" {gsub(/^\047|\047$/, "", $2); print $2; exit}' "$STATE_DIR/config" 2>/dev/null || true)"
  [[ -n "$previous_key" && -f "$previous_key" ]] && KEY_PATH="$previous_key"
fi
[[ -n "$KEY_PATH" ]] || KEY_PATH="$HOME/.ssh/id_ed25519_utm"
KEY_PATH="${KEY_PATH/#\~/$HOME}"
KEY_CREATED=0

if [[ ! -f "$KEY_PATH" ]]; then
  info "Creating a dedicated SSH key"
  mkdir -p "$(dirname "$KEY_PATH")"
  ssh-keygen -q -t ed25519 -a 100 -N '' -f "$KEY_PATH" -C "utm-shell:${UTORID}@${UTM_HOST}" || die "Could not create SSH key"
  KEY_CREATED=1
fi
if [[ ! -f "${KEY_PATH}.pub" ]]; then
  ssh-keygen -y -f "$KEY_PATH" > "${KEY_PATH}.pub" || die "Could not rebuild public key"
fi
chmod 600 "$KEY_PATH" 2>/dev/null || true
chmod 644 "${KEY_PATH}.pub" 2>/dev/null || true

SSH_CONFIG="$HOME/.ssh/config"
START="# >>> utm-shell >>>"
END="# <<< utm-shell <<<"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG" 2>/dev/null || true

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
awk -v start="$START" -v end="$END" '
  $0 == start { skip=1; next }
  $0 == end   { skip=0; next }
  !skip       { print }
' "$SSH_CONFIG" > "$tmp"
awk 'NF {blank=0} !NF {blank++} {line[NR]=$0} END {last=NR-blank; for(i=1;i<=last;i++) print line[i]}' "$tmp" > "$SSH_CONFIG"
[[ -s "$SSH_CONFIG" ]] && printf '\n\n' >> "$SSH_CONFIG"
cat >> "$SSH_CONFIG" <<EOF
$START
Host $SSH_ALIAS
    HostName $UTM_HOST
    User $UTORID
    IdentityFile "$KEY_PATH"
    IdentitiesOnly yes
    ConnectTimeout 6
    ConnectionAttempts 1
    ServerAliveInterval 60
    ServerAliveCountMax 3
$END
EOF

ssh -G "$SSH_ALIAS" >/dev/null 2>&1 || die "Generated SSH config is invalid"
ok "Created SSH shortcut: ssh $SSH_ALIAS"

# Install the smart local `utm` command. It detects the common off-campus case
# before starting an interactive SSH session and offers UTORvpn help.
printf '%s\n' "$SSH_ALIAS" > "$STATE_DIR/alias"
fetch "$REPO_RAW/connect.sh" > "$BIN_DIR/utm"
chmod 755 "$BIN_DIR/utm"

PATH_START="# >>> utm-shell path >>>"
PATH_END="# <<< utm-shell path <<<"
PATH_BODY='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
SHELL_NAME="$(basename "${SHELL:-sh}")"
case "$SHELL_NAME" in
  zsh)
    replace_block "$HOME/.zshrc" "$PATH_START" "$PATH_END" "$PATH_BODY"
    ;;
  bash)
    replace_block "$HOME/.bashrc" "$PATH_START" "$PATH_END" "$PATH_BODY"
    ;;
  fish)
    mkdir -p "$HOME/.config/fish/conf.d"
    printf 'fish_add_path -g $HOME/.local/bin\n' > "$HOME/.config/fish/conf.d/utm-shell.fish"
    ;;
  *)
    replace_block "$HOME/.profile" "$PATH_START" "$PATH_END" "$PATH_BODY"
    ;;
esac
ok "Installed smart command: utm"

key_works() {
  ssh -o BatchMode=yes -o ConnectTimeout=6 -o ConnectionAttempts=1 "$SSH_ALIAS" true >/dev/null 2>&1
}

if [[ "$SKIP_KEY_COPY" -eq 0 ]]; then
  if key_works; then
    ok "Passwordless login already works"
  else
    # If the lab network is unreachable, pause setup and explain UTORvpn rather
    # than leaving the user at a hanging SSH command or vague timeout.
    if "$BIN_DIR/utm" --probe >/dev/null 2>&1; then
      :
    else
      probe_rc=$?
      if [[ $probe_rc -eq 2 ]]; then
        "$BIN_DIR/utm" --ensure-network || die "UTM network is still unreachable"
      fi
    fi

    printf '\n%sOne-time step:%s enter your UTORid password when SSH asks for it.\n' "$BLUE" "$RESET"
    printf '%sIf this is your first connection, SSH may also ask you to confirm the host.%s\n\n' "$DIM" "$RESET"

    if command -v ssh-copy-id >/dev/null 2>&1; then
      ssh-copy-id -o StrictHostKeyChecking=accept-new -i "${KEY_PATH}.pub" "$SSH_ALIAS" || {
        printf '\n' >&2
        warn "Could not log in. If you are off campus, connect to UTORvpn and retry."
        warn "If the password is definitely correct but UTM still says Permission denied, your UTORid may not be provisioned on the lab system yet; contact course staff."
        exit 1
      }
    else
      command -v base64 >/dev/null 2>&1 || die "base64 is required because ssh-copy-id is unavailable"
      pub_b64="$(base64 < "${KEY_PATH}.pub" | tr -d '\r\n')"
      ssh -o StrictHostKeyChecking=accept-new "$SSH_ALIAS" "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; pub=\$(printf '%s' '$pub_b64' | base64 -d); grep -qxF \"\$pub\" ~/.ssh/authorized_keys || printf '%s\\n' \"\$pub\" >> ~/.ssh/authorized_keys" || {
        warn "Could not log in. Check campus Wi-Fi/UTORvpn, hostname, and your UTORid password."
        exit 1
      }
    fi

    key_works || die "The key was copied, but passwordless login did not verify"
    ok "Passwordless login works"
  fi
else
  warn "Skipped key installation"
fi

info "Installing the clean UTM shell"
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/remote.sh" ]]; then
  ssh "$SSH_ALIAS" bash -s -- "$USE_HUSHLOGIN" < "$SCRIPT_DIR/remote.sh" || die "Remote shell setup failed"
else
  fetch "$REPO_RAW/remote.sh" | ssh "$SSH_ALIAS" bash -s -- "$USE_HUSHLOGIN" || die "Remote shell setup failed"
fi
ok "Remote shell installed"

cat > "$STATE_DIR/config" <<EOF
VERSION='$VERSION'
SSH_ALIAS='$SSH_ALIAS'
UTORID='$UTORID'
UTM_HOST='$UTM_HOST'
KEY_PATH='$KEY_PATH'
KEY_CREATED='$KEY_CREATED'
EOF
chmod 600 "$STATE_DIR/config" 2>/dev/null || true

printf '\n%sDone.%s Open a new terminal, then just run:\n\n' "$GREEN" "$RESET"
printf '    %sutm%s\n\n' "$BLUE" "$RESET"
printf '%s`utm` checks whether the UTM network is reachable and helps with UTORvpn when you are off campus.%s\n' "$DIM" "$RESET"
printf '%sRaw SSH still works as: ssh %s%s\n' "$DIM" "$SSH_ALIAS" "$RESET"
