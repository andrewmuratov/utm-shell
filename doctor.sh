#!/usr/bin/env bash
set -uo pipefail

SSH_ALIAS="utm"
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf 'Usage: ./doctor.sh [ssh-alias]\n'
  exit 0
fi
[[ $# -ge 1 ]] && SSH_ALIAS="$1"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BLUE="" GREEN="" YELLOW="" RED="" DIM="" RESET=""
fi

failed=0
pass() { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%s✗%s %s\n' "$RED" "$RESET" "$*"; failed=1; }

os="$(uname -s 2>/dev/null || printf unknown)"
printf '\n%sutm-shell doctor%s — %s\n\n' "$BLUE" "$RESET" "$os"

for cmd in ssh ssh-keygen scp; do
  if command -v "$cmd" >/dev/null 2>&1; then pass "$cmd: $(command -v "$cmd")"
  else
    if [[ "$cmd" == ssh ]]; then fail "$cmd not found"; else warn "$cmd not found"; fi
  fi
done

if [[ -f "$HOME/.ssh/config" ]]; then
  if grep -q '^# >>> utm-shell >>>$' "$HOME/.ssh/config"; then pass 'utm-shell managed SSH config is present'
  else warn 'SSH config exists, but no utm-shell managed block was found'; fi
else fail 'SSH config not found'; fi

if command -v ssh >/dev/null 2>&1; then
  if ssh -G "$SSH_ALIAS" >/dev/null 2>&1; then pass "SSH alias '$SSH_ALIAS' resolves"
  else fail "SSH alias '$SSH_ALIAS' is invalid"; fi

  if ssh -o ControlMaster=no -o ControlPath=none -o BatchMode=yes -o ConnectTimeout=8 "$SSH_ALIAS" true >/dev/null 2>&1; then
    pass 'Passwordless public-key authentication works'
    if remote="$(ssh -o ConnectTimeout=8 "$SSH_ALIAS" 'printf "shell=%s term=%s\n" "$SHELL" "${TERM:-unset}"; command -v bash; command -v scp' 2>/dev/null)"; then
      pass 'Remote shell is reachable'
      printf '%s%s%s\n' "$DIM" "$remote" "$RESET"
    else warn 'Connected, but remote diagnostic command failed'; fi
  else
    warn 'Key-only authentication failed or UTM is unreachable. Connect to campus Wi-Fi/UTORvpn and try ssh utm.'
  fi
fi

if [[ "$failed" -ne 0 ]]; then
  printf '\n%sOne or more required checks failed.%s\n' "$RED" "$RESET"
  exit 1
fi
printf '\n%sCore checks passed.%s\n' "$GREEN" "$RESET"
