#!/bin/sh
set -u

STATE_FILE="$HOME/.config/utm-shell/config"
SSH_CONFIG="$HOME/.ssh/config"
SSH_START='# >>> utm-shell >>>'
SSH_END='# <<< utm-shell <<<'
PATH_START='# >>> utm-shell path >>>'
PATH_END='# <<< utm-shell path <<<'
LOCAL_ONLY=0
KEEP_AUTH_KEY=0

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

info() { printf '%s•%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: sh uninstall.sh [options]

  --local-only      remove only your local setup
  --keep-auth-key   leave the public key on UTM
  -h, --help        show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --local-only) LOCAL_ONLY=1; shift ;;
    --keep-auth-key) KEEP_AUTH_KEY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

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

remove_block() {
  _file=$1
  _start=$2
  _end=$3
  [ -f "$_file" ] || return 0
  _tmp=$(mktemp)
  awk -v start="$_start" -v end="$_end" '
    $0 == start { skip=1; next }
    $0 == end   { skip=0; next }
    !skip       { print }
  ' "$_file" >"$_tmp"
  cat "$_tmp" >"$_file"
  rm -f "$_tmp"
}

if [ -f "$STATE_FILE" ]; then
  SSH_ALIAS=$(state_value SSH_ALIAS 2>/dev/null || true)
  KEY_PATH=$(state_value KEY_PATH 2>/dev/null || true)
  KEY_CREATED=$(state_value KEY_CREATED 2>/dev/null || true)
else
  warn "Local state not found; assuming SSH alias 'utm'."
  SSH_ALIAS='utm'
  KEY_PATH=''
  KEY_CREATED=0
fi

[ -n "${SSH_ALIAS:-}" ] || SSH_ALIAS='utm'
[ -n "${KEY_CREATED:-}" ] || KEY_CREATED=0

if [ "$LOCAL_ONLY" -eq 0 ]; then
  remote_tmp=$(mktemp)
  cat >"$remote_tmp" <<'REMOTE_EOF'
set -eu

START='# >>> utm-shell >>>'
END='# <<< utm-shell <<<'
LOGIN_START='# >>> utm-shell login >>>'
LOGIN_END='# <<< utm-shell login <<<'
STATE_FILE="$HOME/.config/utm-shell/state"

remove_block() {
  file=$1
  start=$2
  end=$3
  [ -f "$file" ] || return 0
  tmp=$(mktemp)
  awk -v start="$start" -v end="$end" '
    $0 == start { skip=1; next }
    $0 == end   { skip=0; next }
    !skip       { print }
  ' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

LOGIN_FILE=''
LOGIN_MANAGED=1
HUSH_CREATED=0
if [ -f "$STATE_FILE" ]; then
  . "$STATE_FILE"
fi

remove_block "$HOME/.bashrc" "$START" "$END"

if [ "${LOGIN_MANAGED:-1}" = "1" ]; then
  if [ -n "${LOGIN_FILE:-}" ]; then
    remove_block "$LOGIN_FILE" "$LOGIN_START" "$LOGIN_END"
  else
    remove_block "$HOME/.bash_profile" "$LOGIN_START" "$LOGIN_END"
    remove_block "$HOME/.bash_login" "$LOGIN_START" "$LOGIN_END"
    remove_block "$HOME/.profile" "$LOGIN_START" "$LOGIN_END"
  fi
fi

if [ "${HUSH_CREATED:-0}" = "1" ]; then
  rm -f "$HOME/.hushlogin"
fi

rm -rf "$HOME/.config/utm-shell"
REMOTE_EOF

  info 'Removing remote shell setup'
  if ssh "$SSH_ALIAS" bash -s <"$remote_tmp"; then
    ok 'Remote shell setup removed'

    if [ "$KEEP_AUTH_KEY" -eq 0 ] && [ -n "${KEY_PATH:-}" ] && [ -f "${KEY_PATH}.pub" ]; then
      if cat "${KEY_PATH}.pub" | ssh "$SSH_ALIAS" \
        'IFS= read -r pub; if [ -f ~/.ssh/authorized_keys ]; then tmp=$(mktemp); grep -Fvx "$pub" ~/.ssh/authorized_keys >"$tmp" || true; cat "$tmp" > ~/.ssh/authorized_keys; rm -f "$tmp"; fi'
      then
        ok 'Authorized key removed'
      else
        warn 'Could not remove the authorized key from UTM.'
      fi
    fi
  else
    warn 'Could not reach UTM. Remote files were left unchanged.'
  fi
  rm -f "$remote_tmp"
fi

ssh -O exit "$SSH_ALIAS" >/dev/null 2>&1 || true
remove_block "$SSH_CONFIG" "$SSH_START" "$SSH_END"
ok 'Local SSH config cleaned'

remove_block "$HOME/.bashrc" "$PATH_START" "$PATH_END"
remove_block "$HOME/.zshrc" "$PATH_START" "$PATH_END"
remove_block "$HOME/.profile" "$PATH_START" "$PATH_END"
remove_block "$HOME/.cshrc" "$PATH_START" "$PATH_END"
remove_block "$HOME/.tcshrc" "$PATH_START" "$PATH_END"
rm -f "$HOME/.config/fish/conf.d/utm-shell.fish" 2>/dev/null || true
rm -f "$HOME/.local/bin/utm" 2>/dev/null || true
rm -rf "$HOME/.config/utm-shell"
ok 'Local utm command removed'

if [ "$KEY_CREATED" = "1" ] && [ -n "${KEY_PATH:-}" ] && [ -f "$KEY_PATH" ]; then
  printf '\nA dedicated key was created by utm-shell at:\n  %s\n' "$KEY_PATH"
  printf 'It was not deleted. Remove it manually if you no longer need it.\n'
fi

printf '\n%sutm-shell has been uninstalled.%s\n' "$GREEN" "$RESET"
