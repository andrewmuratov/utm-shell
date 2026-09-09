#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.0.0"
SSH_ALIAS="utm"
UTORID=""
UTM_HOST=""
KEY_PATH=""
SKIP_KEY_COPY=0
USE_HUSHLOGIN=1

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m'
  DIM=$'\033[2m'
  GREEN=$'\033[1;32m'
  YELLOW=$'\033[1;33m'
  RED=$'\033[1;31m'
  RESET=$'\033[0m'
else
  BLUE="" DIM="" GREEN="" YELLOW="" RED="" RESET=""
fi

info() { printf '%s•%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
utm-shell — minimal SSH + Bash setup for UTM lab machines

Usage:
  ./install.sh [options]

Options:
  --user UTORID       UTORid used to log in
  --host HOST         Lab hostname, e.g. dh2026pc08 or full hostname
  --alias NAME        Local SSH alias (default: utm)
  --key PATH          SSH private key to use
  --skip-key-copy     Do not install the public key on the UTM account
  --no-hushlogin      Keep the Ubuntu login banner
  -h, --help          Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) [[ $# -ge 2 ]] || die "--user requires a value"; UTORID="$2"; shift 2 ;;
    --host) [[ $# -ge 2 ]] || die "--host requires a value"; UTM_HOST="$2"; shift 2 ;;
    --alias) [[ $# -ge 2 ]] || die "--alias requires a value"; SSH_ALIAS="$2"; shift 2 ;;
    --key) [[ $# -ge 2 ]] || die "--key requires a value"; KEY_PATH="$2"; shift 2 ;;
    --skip-key-copy) SKIP_KEY_COPY=1; shift ;;
    --no-hushlogin) USE_HUSHLOGIN=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

for cmd in ssh ssh-keygen awk mktemp base64 tr; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

read_tty() {
  local __var="$1" __prompt="$2" __default="${3:-}" __value=""
  [[ -r /dev/tty ]] || die "Interactive input requires a TTY. Pass --user and --host explicitly."
  if [[ -n "$__default" ]]; then
    printf '%s [%s]: ' "$__prompt" "$__default" >/dev/tty
  else
    printf '%s: ' "$__prompt" >/dev/tty
  fi
  IFS= read -r __value </dev/tty || die "Could not read input"
  [[ -n "$__value" ]] || __value="$__default"
  printf -v "$__var" '%s' "$__value"
}

confirm() {
  local prompt="$1" default="${2:-y}" answer=""
  local suffix='[Y/n]'
  [[ "$default" == "n" ]] && suffix='[y/N]'
  printf '%s %s ' "$prompt" "$suffix" >/dev/tty
  IFS= read -r answer </dev/tty || return 1
  [[ -n "$answer" ]] || answer="$default"
  [[ "$answer" =~ ^[Yy]$ ]]
}

printf '\n%sutm-shell%s %s%s%s\n' "$BLUE" "$RESET" "$DIM" "$VERSION" "$RESET"
printf '%sA small, reversible setup for UTM lab SSH.%s\n\n' "$DIM" "$RESET"

[[ -n "$UTORID" ]] || read_tty UTORID "UTORid"
[[ -n "$UTM_HOST" ]] || read_tty UTM_HOST "UTM lab host (for example dh2026pc08)"

[[ "$UTORID" =~ ^[A-Za-z0-9._-]+$ ]] || die "UTORid contains unsupported characters"
[[ "$SSH_ALIAS" =~ ^[A-Za-z0-9._-]+$ ]] || die "SSH alias contains unsupported characters"
[[ "$UTM_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || die "Hostname contains unsupported characters"

if [[ "$UTM_HOST" != *.* ]]; then
  UTM_HOST="${UTM_HOST}.utm.utoronto.ca"
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ -z "$KEY_PATH" ]]; then
  if [[ -f "$HOME/.ssh/id_ed25519" && -f "$HOME/.ssh/id_ed25519.pub" ]]; then
    if confirm "Use your existing Ed25519 key at ~/.ssh/id_ed25519?" y; then
      KEY_PATH="$HOME/.ssh/id_ed25519"
    else
      KEY_PATH="$HOME/.ssh/id_ed25519_utm"
    fi
  else
    KEY_PATH="$HOME/.ssh/id_ed25519_utm"
  fi
fi
KEY_PATH="${KEY_PATH/#\~/$HOME}"

KEY_CREATED=0
if [[ ! -f "$KEY_PATH" ]]; then
  info "Creating a dedicated Ed25519 SSH key at $KEY_PATH"
  mkdir -p "$(dirname "$KEY_PATH")"
  ssh-keygen -t ed25519 -a 100 -f "$KEY_PATH" -C "utm-shell:${UTORID}@${UTM_HOST}"
  KEY_CREATED=1
fi

if [[ ! -f "${KEY_PATH}.pub" ]]; then
  info "Rebuilding missing public key"
  ssh-keygen -y -f "$KEY_PATH" > "${KEY_PATH}.pub"
  chmod 644 "${KEY_PATH}.pub"
fi

SSH_CONFIG="$HOME/.ssh/config"
SSH_START="# >>> utm-shell >>>"
SSH_END="# <<< utm-shell <<<"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
awk -v start="$SSH_START" -v end="$SSH_END" '
  $0 == start { skip=1; next }
  $0 == end   { skip=0; next }
  !skip       { print }
' "$SSH_CONFIG" > "$tmp"

awk 'NF {blank=0} !NF {blank++} {lines[NR]=$0} END {last=NR-blank; for(i=1;i<=last;i++) print lines[i]}' "$tmp" > "${tmp}.clean"
mv "${tmp}.clean" "$tmp"

{
  [[ -s "$tmp" ]] && { cat "$tmp"; printf '\n\n'; }
  cat <<EOF_CONFIG
$SSH_START
Host $SSH_ALIAS
    HostName $UTM_HOST
    User $UTORID
    IdentityFile $KEY_PATH
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/control-%C
    ControlPersist 30m
$SSH_END
EOF_CONFIG
} > "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"
ok "Configured ssh $SSH_ALIAS → $UTORID@$UTM_HOST"

ssh -G "$SSH_ALIAS" >/dev/null 2>&1 || die "OpenSSH rejected the generated SSH configuration"

key_auth_works() {
  ssh \
    -o ControlMaster=no \
    -o ControlPath=none \
    -o BatchMode=yes \
    -o ConnectTimeout=8 \
    "$SSH_ALIAS" true >/dev/null 2>&1
}

if [[ "$SKIP_KEY_COPY" -eq 0 ]]; then
  if key_auth_works; then
    ok "SSH key authentication already works"
  else
    info "Installing your public key on UTM (your UTORid password may be requested once)"
    info "You must be on the U of T network or connected through UTORvpn."
    if command -v ssh-copy-id >/dev/null 2>&1; then
      ssh-copy-id -i "${KEY_PATH}.pub" "$SSH_ALIAS" || die "Could not copy the SSH key. Check the hostname, network/VPN, and your UTORid password."
    else
      PUB_B64="$(base64 < "${KEY_PATH}.pub" | tr -d '\n')"
      ssh "$SSH_ALIAS" "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; pub=\$(printf '%s' '$PUB_B64' | base64 -d); grep -qxF \"\$pub\" ~/.ssh/authorized_keys || printf '%s\\n' \"\$pub\" >> ~/.ssh/authorized_keys" \
        || die "Could not install the SSH key. Check the hostname, network/VPN, and your UTORid password."
    fi
    key_auth_works || die "The key was copied, but key-only authentication still failed."
    ok "Passwordless SSH is working"
  fi
else
  warn "Skipped SSH key installation"
fi

REMOTE_INSTALL=$(cat <<'REMOTE_EOF'
set -Eeuo pipefail

USE_HUSHLOGIN="${1:-1}"
BASHRC="$HOME/.bashrc"
START="# >>> utm-shell >>>"
END="# <<< utm-shell <<<"
LOGIN_START="# >>> utm-shell login >>>"
LOGIN_END="# <<< utm-shell login <<<"
STATE_DIR="$HOME/.config/utm-shell"
STATE_FILE="$STATE_DIR/state"

mkdir -p "$STATE_DIR"
touch "$BASHRC"

remove_block() {
  local file="$1" start="$2" end="$3" tmp
  [[ -f "$file" ]] || return 0
  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" '
    $0 == start { skip=1; next }
    $0 == end   { skip=0; next }
    !skip       { print }
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

remove_block "$BASHRC" "$START" "$END"
cat >> "$BASHRC" <<'BASHRC_EOF'

# >>> utm-shell >>>
if [[ $- == *i* ]]; then
  if [[ ${TERM:-} == "xterm-ghostty" ]]; then
    export TERM=xterm-256color
  fi

  HISTCONTROL=ignoreboth:erasedups
  HISTSIZE=10000
  HISTFILESIZE=20000
  shopt -s histappend checkwinsize cdspell globstar

  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
  alias diff='diff --color=auto'
  alias ll='ls -lah'
  alias la='ls -A'
  alias l='ls -CF'

  alias ..='cd ..'
  alias ...='cd ../..'
  alias ....='cd ../../..'
  alias home='cd ~'

  alias c='clear'
  alias cls='clear'
  alias reload='source ~/.bashrc'
  alias disk='df -h'
  alias usage='du -sh -- * 2>/dev/null | sort -h'
  alias py='python3'

  alias gs='git status'
  alias gd='git diff'
  alias gl='git log --oneline --graph --decorate -15'

  mkcd() {
    [[ $# -eq 1 ]] || { printf 'usage: mkcd <directory>\n' >&2; return 2; }
    mkdir -p -- "$1" && cd -- "$1"
  }

  ff() {
    [[ $# -ge 1 ]] || { printf 'usage: ff <name>\n' >&2; return 2; }
    find . -iname "*$1*" 2>/dev/null
  }

  path() {
    printf '%s\n' "$PATH" | tr ':' '\n'
  }

  utm-help() {
    cat <<'HELP_EOF'
utm-shell commands

  ll / la       detailed / hidden-file listings
  .. / ...      move up one / two directories
  c / cls       clear the terminal
  reload        reload ~/.bashrc
  mkcd DIR      create a directory and enter it
  ff NAME       find files/directories by name below .
  disk          filesystem disk usage
  usage         sizes of items in the current directory
  path          print PATH one entry per line
  py            python3
  gs / gd / gl  compact Git shortcuts
  utm-help      show this help
HELP_EOF
  }

  if command -v bind >/dev/null 2>&1; then
    bind '"\e[A": history-search-backward' 2>/dev/null || true
    bind '"\e[B": history-search-forward' 2>/dev/null || true
  fi

  PS1='\[\e[1;34m\]UTM\[\e[0m\] \[\e[90m\]\u@\h\[\e[0m\] \[\e[1;37m\]\w\[\e[0m\]\n\[\e[1;34m\]❯\[\e[0m\] '
fi
# <<< utm-shell <<<
BASHRC_EOF

if [[ -f "$HOME/.bash_profile" ]]; then
  LOGIN_FILE="$HOME/.bash_profile"
elif [[ -f "$HOME/.bash_login" ]]; then
  LOGIN_FILE="$HOME/.bash_login"
else
  LOGIN_FILE="$HOME/.profile"
  touch "$LOGIN_FILE"
fi

remove_block "$LOGIN_FILE" "$LOGIN_START" "$LOGIN_END"
LOGIN_MANAGED=0
if ! grep -Eq '(^|[[:space:]])(\.|source)[[:space:]].*\.bashrc' "$LOGIN_FILE" 2>/dev/null; then
  cat >> "$LOGIN_FILE" <<'LOGIN_EOF'

# >>> utm-shell login >>>
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
# <<< utm-shell login <<<
LOGIN_EOF
  LOGIN_MANAGED=1
fi

HUSH_CREATED=0
if [[ "$USE_HUSHLOGIN" == "1" && ! -e "$HOME/.hushlogin" ]]; then
  touch "$HOME/.hushlogin"
  HUSH_CREATED=1
fi

{
  printf 'VERSION=%q\n' '1.0.0'
  printf 'LOGIN_FILE=%q\n' "$LOGIN_FILE"
  printf 'LOGIN_MANAGED=%q\n' "$LOGIN_MANAGED"
  printf 'HUSH_CREATED=%q\n' "$HUSH_CREATED"
} > "$STATE_FILE"
chmod 600 "$STATE_FILE"
REMOTE_EOF
)

info "Installing the remote Bash setup"
ssh "$SSH_ALIAS" bash -s -- "$USE_HUSHLOGIN" <<< "$REMOTE_INSTALL" \
  || die "Remote shell setup failed"
ok "Remote shell configured"

STATE_DIR="$HOME/.config/utm-shell"
STATE_FILE="$STATE_DIR/config"
mkdir -p "$STATE_DIR"
{
  printf 'VERSION=%q\n' "$VERSION"
  printf 'SSH_ALIAS=%q\n' "$SSH_ALIAS"
  printf 'UTORID=%q\n' "$UTORID"
  printf 'UTM_HOST=%q\n' "$UTM_HOST"
  printf 'KEY_PATH=%q\n' "$KEY_PATH"
  printf 'KEY_CREATED=%q\n' "$KEY_CREATED"
} > "$STATE_FILE"
chmod 600 "$STATE_FILE"

printf '\n%sDone.%s Your UTM shell is ready.\n\n' "$GREEN" "$RESET"
printf '  %sssh %s%s\n\n' "$BLUE" "$SSH_ALIAS" "$RESET"
printf '%sInside UTM, run `utm-help` to see the added shortcuts.%s\n' "$DIM" "$RESET"
