#!/usr/bin/env bash
set -Eeuo pipefail

VERSION='1.5.0'
REPO_RAW='https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
DEFAULT_HOST='dh2026pc08'
SSH_ALIAS='utm'
UTORID=''
UTM_HOST=''
KEY_PATH=''
USE_HUSHLOGIN=1
SKIP_KEY_COPY=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BLUE=''; GREEN=''; YELLOW=''; RED=''; DIM=''; RESET=''
fi

ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
utm-shell setup

Usually just run the one-line installer from the README.
Only your UTORid is needed on a new install.

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
    --user) [[ $# -ge 2 ]] || die '--user needs a value'; UTORID="$2"; shift 2 ;;
    --host) [[ $# -ge 2 ]] || die '--host needs a value'; UTM_HOST="$2"; shift 2 ;;
    --alias) [[ $# -ge 2 ]] || die '--alias needs a value'; SSH_ALIAS="$2"; shift 2 ;;
    --key) [[ $# -ge 2 ]] || die '--key needs a value'; KEY_PATH="$2"; shift 2 ;;
    --skip-key-copy) SKIP_KEY_COPY=1; shift ;;
    --no-hushlogin) USE_HUSHLOGIN=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

for cmd in ssh ssh-keygen awk mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required. Install OpenSSH, then rerun setup."
done

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then wget -qO- "$1"
  else die 'curl or wget is required'
  fi
}

read_tty() {
  local var="$1" prompt="$2" value=''
  [[ -r /dev/tty ]] || die 'No interactive terminal. Pass --user.'
  printf '%s: ' "$prompt" >/dev/tty
  IFS= read -r value </dev/tty || die 'Could not read input'
  [[ -n "$value" ]] || die "$prompt cannot be empty"
  printf -v "$var" '%s' "$value"
}

replace_block() {
  local file="$1" start="$2" end="$3" body="$4" tmp
  mkdir -p "$(dirname "$file")"; touch "$file"; tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" '$0==start{skip=1;next} $0==end{skip=0;next} !skip{print}' "$file" > "$tmp"
  cat "$tmp" > "$file"; rm -f "$tmp"
  printf '\n%s\n%s\n%s\n' "$start" "$body" "$end" >> "$file"
}

STATE_DIR="$HOME/.config/utm-shell"
BIN_DIR="$HOME/.local/bin"
SSH_CONFIG="$HOME/.ssh/config"
STATE_FILE="$STATE_DIR/config"
mkdir -p "$HOME/.ssh" "$STATE_DIR" "$BIN_DIR"
chmod 700 "$HOME/.ssh" 2>/dev/null || true

# Reuse a previous utm-shell setup.
if [[ -r "$STATE_FILE" ]]; then
  [[ -n "$UTORID" ]] || UTORID="$(awk -F= '$1=="UTORID" {v=substr($0,index($0,"=")+1); gsub(/^\047|\047$/, "", v); print v; exit}' "$STATE_FILE" 2>/dev/null || true)"
  [[ -n "$UTM_HOST" ]] || UTM_HOST="$(awk -F= '$1=="UTM_HOST" {v=substr($0,index($0,"=")+1); gsub(/^\047|\047$/, "", v); print v; exit}' "$STATE_FILE" 2>/dev/null || true)"
  [[ -n "$KEY_PATH" ]] || KEY_PATH="$(awk -F= '$1=="KEY_PATH" {v=substr($0,index($0,"=")+1); gsub(/^\047|\047$/, "", v); print v; exit}' "$STATE_FILE" 2>/dev/null || true)"
fi

# Also adopt an older/manual `Host utm` setup when possible.
if [[ -z "$UTM_HOST" ]]; then
  existing_host="$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="hostname" {print $2; exit}' || true)"
  if [[ "$existing_host" == *.utm.utoronto.ca ]]; then
    UTM_HOST="$existing_host"
    [[ -n "$UTORID" ]] || UTORID="$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="user" {print $2; exit}' || true)"
    if [[ -z "$KEY_PATH" ]]; then
      while IFS= read -r candidate; do
        candidate="${candidate/#\~/$HOME}"
        if [[ -f "$candidate" ]]; then KEY_PATH="$candidate"; break; fi
      done < <(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="identityfile" {print $2}' || true)
    fi
  fi
fi

printf '\n%sutm-shell%s %s\n' "$BLUE" "$RESET" "$VERSION"
[[ -n "$UTORID" ]] || read_tty UTORID 'UTORid'
[[ -n "$UTM_HOST" ]] || UTM_HOST="$DEFAULT_HOST"

[[ "$UTORID" =~ ^[A-Za-z0-9._-]+$ ]] || die 'Invalid UTORid'
[[ "$SSH_ALIAS" =~ ^[A-Za-z0-9._-]+$ ]] || die 'Invalid SSH alias'
[[ "$UTM_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || die 'Invalid lab hostname'
[[ "$UTM_HOST" == *.* ]] || UTM_HOST="${UTM_HOST}.utm.utoronto.ca"

[[ -n "$KEY_PATH" && -f "${KEY_PATH/#\~/$HOME}" ]] || KEY_PATH="$HOME/.ssh/id_ed25519_utm"
KEY_PATH="${KEY_PATH/#\~/$HOME}"
KEY_CREATED=0
if [[ ! -f "$KEY_PATH" ]]; then
  ssh-keygen -q -t ed25519 -a 100 -N '' -f "$KEY_PATH" -C "utm-shell:${UTORID}@${UTM_HOST}" || die 'Could not create SSH key'
  KEY_CREATED=1
fi
if [[ ! -f "${KEY_PATH}.pub" ]]; then
  ssh-keygen -y -f "$KEY_PATH" > "${KEY_PATH}.pub" || die 'Could not rebuild public key'
fi
chmod 600 "$KEY_PATH" 2>/dev/null || true
chmod 644 "${KEY_PATH}.pub" 2>/dev/null || true

write_ssh_config() {
  local tmp="$(mktemp)"
  touch "$SSH_CONFIG"; chmod 600 "$SSH_CONFIG" 2>/dev/null || true
  awk -v start='# >>> utm-shell >>>' -v end='# <<< utm-shell <<<' '$0==start{skip=1;next} $0==end{skip=0;next} !skip{print}' "$SSH_CONFIG" > "$tmp"
  awk 'NF{blank=0}!NF{blank++}{line[NR]=$0} END{last=NR-blank; for(i=1;i<=last;i++) print line[i]}' "$tmp" > "$SSH_CONFIG"
  rm -f "$tmp"
  [[ -s "$SSH_CONFIG" ]] && printf '\n\n' >> "$SSH_CONFIG"
  cat >> "$SSH_CONFIG" <<EOF
# >>> utm-shell >>>
Host $SSH_ALIAS
    HostName $UTM_HOST
    User $UTORID
    IdentityFile "$KEY_PATH"
    IdentitiesOnly yes
    ConnectTimeout 5
    ConnectionAttempts 1
    ServerAliveInterval 60
    ServerAliveCountMax 3
# <<< utm-shell <<<
EOF
  ssh -G "$SSH_ALIAS" >/dev/null 2>&1 || die 'Generated SSH config is invalid'
}

save_state() {
  cat > "$STATE_FILE" <<EOF
VERSION='$VERSION'
SSH_ALIAS='$SSH_ALIAS'
UTORID='$UTORID'
UTM_HOST='$UTM_HOST'
KEY_PATH='$KEY_PATH'
KEY_CREATED='$KEY_CREATED'
EOF
  chmod 600 "$STATE_FILE" 2>/dev/null || true
}

write_ssh_config
printf '%s\n' "$SSH_ALIAS" > "$STATE_DIR/alias"
fetch "$REPO_RAW/connect.sh" > "$BIN_DIR/utm"
chmod 755 "$BIN_DIR/utm"

PATH_START='# >>> utm-shell path >>>'
PATH_END='# <<< utm-shell path <<<'
PATH_BODY='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
case "$(basename "${SHELL:-sh}")" in
  zsh) replace_block "$HOME/.zshrc" "$PATH_START" "$PATH_END" "$PATH_BODY" ;;
  bash) replace_block "$HOME/.bashrc" "$PATH_START" "$PATH_END" "$PATH_BODY" ;;
  fish) mkdir -p "$HOME/.config/fish/conf.d"; printf 'fish_add_path -g $HOME/.local/bin\n' > "$HOME/.config/fish/conf.d/utm-shell.fish" ;;
  *) replace_block "$HOME/.profile" "$PATH_START" "$PATH_END" "$PATH_BODY" ;;
esac
save_state
ok 'Local setup'

key_works() {
  ssh -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 "$SSH_ALIAS" true >/dev/null 2>&1
}

test_key_path() {
  local candidate="$1"
  ssh -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o ConnectionAttempts=1 -i "$candidate" "$UTORID@$UTM_HOST" true >/dev/null 2>&1
}

find_authorized_key() {
  local candidate pub
  for candidate in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ecdsa" "$HOME/.ssh/id_rsa"; do
    [[ -f "$candidate" && "$candidate" != "$KEY_PATH" ]] || continue
    if test_key_path "$candidate"; then
      KEY_PATH="$candidate"; KEY_CREATED=0; write_ssh_config; save_state
      ok 'Reused existing authorized SSH key'
      return 0
    fi
  done
  shopt -s nullglob
  for pub in "$HOME/.ssh/"*.pub; do
    candidate="${pub%.pub}"
    [[ -f "$candidate" && "$candidate" != "$KEY_PATH" ]] || continue
    if test_key_path "$candidate"; then
      KEY_PATH="$candidate"; KEY_CREATED=0; write_ssh_config; save_state
      ok 'Reused existing authorized SSH key'
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

if [[ "$SKIP_KEY_COPY" -eq 0 ]]; then
  if ! key_works; then
    if ! "$BIN_DIR/utm" --ensure-network; then
      printf '%sSetup saved.%s Install/connect UTORvpn, then paste the same setup command again.\n' "$YELLOW" "$RESET"
      exit 2
    fi

    if find_authorized_key; then
      :
    else
      printf '\n%sPassword once:%s enter your UTORid password if SSH asks.\n' "$BLUE" "$RESET"
      if command -v ssh-copy-id >/dev/null 2>&1; then
        ssh-copy-id -o StrictHostKeyChecking=accept-new -i "${KEY_PATH}.pub" "$SSH_ALIAS" >/dev/null || die 'Login failed. Check UTORvpn/UTORid and retry.'
      else
        command -v base64 >/dev/null 2>&1 || die 'base64 is required'
        pub_b64="$(base64 < "${KEY_PATH}.pub" | tr -d '\r\n')"
        ssh -o StrictHostKeyChecking=accept-new "$SSH_ALIAS" "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; pub=\$(printf '%s' '$pub_b64' | base64 -d); grep -qxF \"\$pub\" ~/.ssh/authorized_keys || printf '%s\\n' \"\$pub\" >> ~/.ssh/authorized_keys" >/dev/null || die 'Login failed. Check UTORvpn/UTORid and retry.'
      fi
      key_works || die 'Passwordless login could not be verified'
      ok 'Passwordless login'
    fi
  else
    ok 'Passwordless login'
  fi
fi

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
else
  SCRIPT_DIR=''
fi

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/remote.sh" ]]; then
  ssh "$SSH_ALIAS" bash -s -- "$USE_HUSHLOGIN" < "$SCRIPT_DIR/remote.sh" >/dev/null || die 'Remote shell setup failed'
else
  fetch "$REPO_RAW/remote.sh" | ssh "$SSH_ALIAS" bash -s -- "$USE_HUSHLOGIN" >/dev/null || die 'Remote shell setup failed'
fi
ok 'Remote shell'

printf '\n%sReady.%s Open a new terminal and type: %sutm%s\n' "$GREEN" "$RESET" "$BLUE" "$RESET"
