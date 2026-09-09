#!/usr/bin/env bash
set -Eeuo pipefail

STATE_FILE="$HOME/.config/utm-shell/config"
SSH_CONFIG="$HOME/.ssh/config"
SSH_START="# >>> utm-shell >>>"
SSH_END="# <<< utm-shell <<<"
LOCAL_ONLY=0
KEEP_AUTH_KEY=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; RESET=$'\033[0m'
else
  BLUE="" GREEN="" YELLOW="" RED="" RESET=""
fi

info() { printf '%s•%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: ./uninstall.sh [options]

Options:
  --local-only      Remove only the local SSH configuration
  --keep-auth-key   Leave the public key in ~/.ssh/authorized_keys on UTM
  -h, --help        Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local-only) LOCAL_ONLY=1; shift ;;
    --keep-auth-key) KEEP_AUTH_KEY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

if [[ -f "$STATE_FILE" ]]; then
  # This file is created by utm-shell and contains shell-escaped scalar values.
  # shellcheck disable=SC1090
  source "$STATE_FILE"
else
  warn "Local state file not found; assuming SSH alias 'utm'."
  SSH_ALIAS="utm"
  KEY_PATH=""
  KEY_CREATED=0
fi

SSH_ALIAS="${SSH_ALIAS:-utm}"
KEY_PATH="${KEY_PATH:-}"
KEY_CREATED="${KEY_CREATED:-0}"

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

if [[ "$LOCAL_ONLY" -eq 0 ]]; then
  PUB_B64=""
  if [[ "$KEEP_AUTH_KEY" -eq 0 && -n "$KEY_PATH" && -f "${KEY_PATH}.pub" ]]; then
    PUB_B64="$(base64 < "${KEY_PATH}.pub" | tr -d '\n')"
  fi

  REMOTE_UNINSTALL=$(cat <<'REMOTE_EOF'
set -Eeuo pipefail
PUB_B64="${1:-}"
START="# >>> utm-shell >>>"
END="# <<< utm-shell <<<"
LOGIN_START="# >>> utm-shell login >>>"
LOGIN_END="# <<< utm-shell login <<<"
STATE_FILE="$HOME/.config/utm-shell/state"
LOGIN_FILE=""
LOGIN_MANAGED=1
HUSH_CREATED=0

if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

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

remove_block "$HOME/.bashrc" "$START" "$END"
if [[ "${LOGIN_MANAGED:-1}" == "1" ]]; then
  if [[ -n "${LOGIN_FILE:-}" ]]; then
    remove_block "$LOGIN_FILE" "$LOGIN_START" "$LOGIN_END"
  else
    remove_block "$HOME/.bash_profile" "$LOGIN_START" "$LOGIN_END"
    remove_block "$HOME/.bash_login" "$LOGIN_START" "$LOGIN_END"
    remove_block "$HOME/.profile" "$LOGIN_START" "$LOGIN_END"
  fi
fi

if [[ "${HUSH_CREATED:-0}" == "1" ]]; then
  rm -f "$HOME/.hushlogin"
fi

if [[ -n "$PUB_B64" && -f "$HOME/.ssh/authorized_keys" ]]; then
  pub="$(printf '%s' "$PUB_B64" | base64 -d)"
  tmp="$(mktemp)"
  grep -Fvx "$pub" "$HOME/.ssh/authorized_keys" > "$tmp" || true
  cat "$tmp" > "$HOME/.ssh/authorized_keys"
  rm -f "$tmp"
fi

rm -rf "$HOME/.config/utm-shell"
REMOTE_EOF
)

  info "Removing the remote shell setup"
  if ssh "$SSH_ALIAS" bash -s -- "$PUB_B64" <<< "$REMOTE_UNINSTALL"; then
    ok "Remote setup removed"
  else
    warn "Could not reach UTM. Remote files were left unchanged."
  fi
fi

# Close a multiplexed control connection before removing its config entry.
ssh -O exit "$SSH_ALIAS" >/dev/null 2>&1 || true
remove_block "$SSH_CONFIG" "$SSH_START" "$SSH_END"
ok "Local SSH config cleaned"

rm -f "$STATE_FILE"
rmdir "$HOME/.config/utm-shell" 2>/dev/null || true

if [[ "$KEY_CREATED" == "1" && -n "$KEY_PATH" && -f "$KEY_PATH" ]]; then
  printf '\nA dedicated key was created by utm-shell at:\n  %s\n' "$KEY_PATH"
  printf 'It has NOT been deleted. Remove it manually if you no longer need it.\n'
fi

printf '\n%sutm-shell has been uninstalled.%s\n' "$GREEN" "$RESET"
