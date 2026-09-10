#!/bin/sh
set -eu

VERSION='1.7.0'
REPO_RAW='https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
DEFAULT_HOST='dh2026pc08'
SSH_ALIAS='utm'
UTORID=''
UTM_HOST=''
KEY_PATH=''
USE_HUSHLOGIN=1
SKIP_KEY_COPY=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  ESC=$(printf '\033')
  BLUE="${ESC}[1;34m"
  GREEN="${ESC}[1;32m"
  YELLOW="${ESC}[1;33m"
  RED="${ESC}[1;31m"
  RESET="${ESC}[0m"
else
  BLUE=''; GREEN=''; YELLOW=''; RED=''; RESET=''
fi

ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
utm-shell setup

Normal install:
  curl -fsSL https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh | sh

Usually the only thing you enter is your UTORid.

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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      [ "$#" -ge 2 ] || die '--user needs a value'
      UTORID=$2; shift 2
      ;;
    --host)
      [ "$#" -ge 2 ] || die '--host needs a value'
      UTM_HOST=$2; shift 2
      ;;
    --alias)
      [ "$#" -ge 2 ] || die '--alias needs a value'
      SSH_ALIAS=$2; shift 2
      ;;
    --key)
      [ "$#" -ge 2 ] || die '--key needs a value'
      KEY_PATH=$2; shift 2
      ;;
    --skip-key-copy)
      SKIP_KEY_COPY=1; shift
      ;;
    --no-hushlogin)
      USE_HUSHLOGIN=0; shift
      ;;
    -h|--help)
      usage; exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

for cmd in ssh ssh-keygen awk mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required. Install OpenSSH, then run setup again."
done

fetch_url() {
  _url=$1
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$_url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$_url"
  elif command -v fetch >/dev/null 2>&1; then
    fetch -q -o - "$_url"
  elif command -v ftp >/dev/null 2>&1; then
    ftp -V -o - "$_url"
  else
    die 'Need one downloader: curl, wget, fetch, or ftp.'
  fi
}

read_tty() {
  _prompt=$1
  [ -r /dev/tty ] || die 'No interactive terminal. Pass --user UTORID.'
  printf '%s: ' "$_prompt" >/dev/tty
  IFS= read -r REPLY </dev/tty || die 'Could not read input.'
  [ -n "$REPLY" ] || die "$_prompt cannot be empty."
}

replace_block() {
  _file=$1
  _start=$2
  _end=$3
  _body=$4
  mkdir -p "$(dirname "$_file")"
  touch "$_file"
  _tmp=$(mktemp)
  awk -v start="$_start" -v end="$_end" '
    $0 == start { skip=1; next }
    $0 == end   { skip=0; next }
    !skip       { print }
  ' "$_file" >"$_tmp"
  cat "$_tmp" >"$_file"
  rm -f "$_tmp"
  printf '\n%s\n%s\n%s\n' "$_start" "$_body" "$_end" >>"$_file"
}

state_value() {
  _key=$1
  [ -r "$STATE_FILE" ] || return 1
  awk -F= -v key="$_key" '
    $1 == key {
      v=substr($0,index($0,"=")+1)
      gsub(/^\047|\047$/, "", v)
      print v
      exit
    }
  ' "$STATE_FILE"
}

expand_home() {
  case "$1" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

script_dir=''
_candidate=''
case "$0" in
  */*)
    _candidate=$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd || true)
    ;;
  setup.sh)
    _candidate=$(pwd)
    ;;
esac
if [ -n "$_candidate" ] && [ -f "$_candidate/connect.sh" ] && [ -f "$_candidate/remote.sh" ]; then
  script_dir=$_candidate
fi

STATE_DIR="$HOME/.config/utm-shell"
BIN_DIR="$HOME/.local/bin"
SSH_CONFIG="$HOME/.ssh/config"
STATE_FILE="$STATE_DIR/config"

mkdir -p "$HOME/.ssh" "$STATE_DIR" "$BIN_DIR"
chmod 700 "$HOME/.ssh" 2>/dev/null || true

if [ -r "$STATE_FILE" ]; then
  [ -n "$UTORID" ] || UTORID=$(state_value UTORID 2>/dev/null || true)
  [ -n "$UTM_HOST" ] || UTM_HOST=$(state_value UTM_HOST 2>/dev/null || true)
  [ -n "$KEY_PATH" ] || KEY_PATH=$(state_value KEY_PATH 2>/dev/null || true)
fi

if [ -z "$UTM_HOST" ]; then
  existing_host=$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="hostname" {print $2; exit}' || true)
  case "$existing_host" in
    *.utm.utoronto.ca)
      UTM_HOST=$existing_host
      [ -n "$UTORID" ] || UTORID=$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="user" {print $2; exit}' || true)
      if [ -z "$KEY_PATH" ]; then
        candidate=$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="identityfile" {print $2; exit}' || true)
        candidate=$(expand_home "$candidate")
        [ -f "$candidate" ] && KEY_PATH=$candidate || true
      fi
      ;;
  esac
fi

printf '\n%sutm-shell%s %s\n' "$BLUE" "$RESET" "$VERSION"

[ -n "$UTORID" ] || { read_tty 'UTORid'; UTORID=$REPLY; }
[ -n "$UTM_HOST" ] || UTM_HOST=$DEFAULT_HOST

case "$UTORID" in
  ''|*[!A-Za-z0-9._-]*) die 'Invalid UTORid.' ;;
esac
case "$SSH_ALIAS" in
  ''|*[!A-Za-z0-9._-]*) die 'Invalid SSH alias.' ;;
esac
case "$UTM_HOST" in
  ''|*[!A-Za-z0-9.-]*) die 'Invalid lab hostname.' ;;
esac
case "$UTM_HOST" in
  *.*) ;;
  *) UTM_HOST="${UTM_HOST}.utm.utoronto.ca" ;;
esac

if [ -n "$KEY_PATH" ]; then
  KEY_PATH=$(expand_home "$KEY_PATH")
fi
if [ -z "$KEY_PATH" ] || [ ! -f "$KEY_PATH" ]; then
  KEY_PATH="$HOME/.ssh/id_ed25519_utm"
fi

KEY_CREATED=0
if [ ! -f "$KEY_PATH" ]; then
  ssh-keygen -q -t ed25519 -a 100 -N '' -f "$KEY_PATH" -C "utm-shell:${UTORID}@${UTM_HOST}" ||
    die 'Could not create SSH key.'
  KEY_CREATED=1
fi
if [ ! -f "${KEY_PATH}.pub" ]; then
  ssh-keygen -y -f "$KEY_PATH" >"${KEY_PATH}.pub" || die 'Could not rebuild public key.'
fi
chmod 600 "$KEY_PATH" 2>/dev/null || true
chmod 644 "${KEY_PATH}.pub" 2>/dev/null || true

write_ssh_config() {
  _tmp=$(mktemp)
  touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG" 2>/dev/null || true

  awk -v start='# >>> utm-shell >>>' -v end='# <<< utm-shell <<<' '
    $0 == start { skip=1; next }
    $0 == end   { skip=0; next }
    !skip       { print }
  ' "$SSH_CONFIG" >"$_tmp"

  awk '
    { line[NR]=$0 }
    NF { last=NR }
    END { for (i=1; i<=last; i++) print line[i] }
  ' "$_tmp" >"$SSH_CONFIG"
  rm -f "$_tmp"

  [ -s "$SSH_CONFIG" ] && printf '\n\n' >>"$SSH_CONFIG"
  cat >>"$SSH_CONFIG" <<EOF
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

  ssh -G "$SSH_ALIAS" >/dev/null 2>&1 || die 'Generated SSH config is invalid.'
}

SETUP_COMPLETE=0
save_state() {
  cat >"$STATE_FILE" <<EOF
VERSION=$VERSION
SSH_ALIAS=$SSH_ALIAS
UTORID=$UTORID
UTM_HOST=$UTM_HOST
KEY_PATH=$KEY_PATH
KEY_CREATED=$KEY_CREATED
SETUP_COMPLETE=$SETUP_COMPLETE
EOF
  chmod 600 "$STATE_FILE" 2>/dev/null || true
}

write_ssh_config
printf '%s\n' "$SSH_ALIAS" >"$STATE_DIR/alias"

if [ -n "$script_dir" ] && [ -f "$script_dir/connect.sh" ]; then
  cp "$script_dir/connect.sh" "$BIN_DIR/utm"
else
  fetch_url "$REPO_RAW/connect.sh" >"$BIN_DIR/utm"
fi
chmod 755 "$BIN_DIR/utm"

PATH_START='# >>> utm-shell path >>>'
PATH_END='# <<< utm-shell path <<<'
PATH_BODY='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH"; export PATH ;; esac'

shell_name=$(basename "${SHELL:-sh}")
case "$shell_name" in
  zsh)
    replace_block "$HOME/.zshrc" "$PATH_START" "$PATH_END" "$PATH_BODY"
    ;;
  bash)
    replace_block "$HOME/.bashrc" "$PATH_START" "$PATH_END" "$PATH_BODY"
    ;;
  fish)
    mkdir -p "$HOME/.config/fish/conf.d"
    printf 'fish_add_path -g $HOME/.local/bin\n' >"$HOME/.config/fish/conf.d/utm-shell.fish"
    ;;
  csh|tcsh)
    rc="$HOME/.cshrc"
    [ "$shell_name" = "tcsh" ] && rc="$HOME/.tcshrc"
    CSH_BODY='set path = ( $HOME/.local/bin $path )'
    replace_block "$rc" "$PATH_START" "$PATH_END" "$CSH_BODY"
    ;;
  *)
    replace_block "$HOME/.profile" "$PATH_START" "$PATH_END" "$PATH_BODY"
    ;;
esac

save_state
ok 'Local setup'

key_works() {
  ssh -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 "$SSH_ALIAS" true >/dev/null 2>&1
}

test_key_path() {
  _candidate=$1
  ssh -o BatchMode=yes \
      -o IdentitiesOnly=yes \
      -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=5 \
      -o ConnectionAttempts=1 \
      -i "$_candidate" \
      "$UTORID@$UTM_HOST" true >/dev/null 2>&1
}

find_authorized_key() {
  for candidate in \
    "$HOME/.ssh/id_ed25519" \
    "$HOME/.ssh/id_ecdsa" \
    "$HOME/.ssh/id_rsa"
  do
    [ -f "$candidate" ] || continue
    [ "$candidate" = "$KEY_PATH" ] && continue
    if test_key_path "$candidate"; then
      KEY_PATH=$candidate
      KEY_CREATED=0
      write_ssh_config
      save_state
      ok 'Reused existing authorized SSH key'
      return 0
    fi
  done

  for pub in "$HOME"/.ssh/*.pub; do
    [ -f "$pub" ] || continue
    candidate=${pub%.pub}
    [ -f "$candidate" ] || continue
    [ "$candidate" = "$KEY_PATH" ] && continue
    if test_key_path "$candidate"; then
      KEY_PATH=$candidate
      KEY_CREATED=0
      write_ssh_config
      save_state
      ok 'Reused existing authorized SSH key'
      return 0
    fi
  done

  return 1
}

if [ "$SKIP_KEY_COPY" -eq 0 ]; then
  if ! key_works; then
    if ! "$BIN_DIR/utm" --ensure-network; then
      printf '\n%sSetup paused.%s Type %sutm%s whenever your VPN/network is ready.\n' \
        "$YELLOW" "$RESET" "$BLUE" "$RESET"
      exit 2
    fi

    if find_authorized_key; then
      :
    else
      printf '\n%sPassword once:%s enter your UTORid password if SSH asks.\n' "$BLUE" "$RESET"

      if ! cat "${KEY_PATH}.pub" | ssh -o StrictHostKeyChecking=accept-new "$SSH_ALIAS" \
        'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; IFS= read -r pub; grep -qxF "$pub" ~/.ssh/authorized_keys || printf "%s\n" "$pub" >> ~/.ssh/authorized_keys'
      then
        die 'Login failed. Check UTORvpn/UTORid and retry.'
      fi

      key_works || die 'Passwordless login could not be verified.'
      ok 'Passwordless login'
    fi
  else
    ok 'Passwordless login'
  fi
fi

if [ -n "$script_dir" ] && [ -f "$script_dir/remote.sh" ]; then
  ssh "$SSH_ALIAS" bash -s -- "$USE_HUSHLOGIN" <"$script_dir/remote.sh" >/dev/null ||
    die 'Remote shell setup failed.'
else
  fetch_url "$REPO_RAW/remote.sh" | ssh "$SSH_ALIAS" bash -s -- "$USE_HUSHLOGIN" >/dev/null ||
    die 'Remote shell setup failed.'
fi

ok 'Remote shell'
SETUP_COMPLETE=1
save_state

printf '\n%sReady.%s Type: %sutm%s\n' "$GREEN" "$RESET" "$BLUE" "$RESET"
