#!/usr/bin/env bash
set -uo pipefail

SSH_ALIAS="${1:-utm}"
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf 'Usage: doctor.sh [ssh-alias]\n'
  exit 0
fi

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BLUE="" GREEN="" YELLOW="" RED="" DIM="" RESET=""
fi

failed=0
pass() { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%s✗%s %s\n' "$RED" "$RESET" "$*"; failed=1; }

printf '\n%sutm-shell doctor%s\n\n' "$BLUE" "$RESET"

for cmd in ssh ssh-keygen scp; do
  if command -v "$cmd" >/dev/null 2>&1; then pass "$cmd: $(command -v "$cmd")"
  elif [[ "$cmd" == ssh ]]; then fail "$cmd not found"
  else warn "$cmd not found"
  fi
done

if command -v utm >/dev/null 2>&1; then pass "utm command: $(command -v utm)"
else warn 'utm command is not on PATH in this shell; open a new terminal or rerun setup'; fi

if [[ -f "$HOME/.ssh/config" ]]; then
  if grep -q '^# >>> utm-shell >>>$' "$HOME/.ssh/config"; then pass 'utm-shell managed SSH config is present'
  else warn 'SSH config exists, but no utm-shell managed block was found'; fi
else fail 'SSH config not found'; fi

if command -v ssh >/dev/null 2>&1; then
  if ssh -G "$SSH_ALIAS" >/dev/null 2>&1; then
    host="$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="hostname" {print $2; exit}')"
    user="$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="user" {print $2; exit}')"
    pass "SSH alias '$SSH_ALIAS' resolves to ${user}@${host}"
  else
    fail "SSH alias '$SSH_ALIAS' is invalid"
  fi

  out=''; rc=0
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=6 -o ConnectionAttempts=1 "$SSH_ALIAS" true 2>&1)" || rc=$?
  if [[ $rc -eq 0 ]]; then
    pass 'UTM network is reachable'
    pass 'Passwordless public-key authentication works'
    remote="$(ssh -o ConnectTimeout=6 "$SSH_ALIAS" 'printf "shell=%s term=%s\n" "$SHELL" "${TERM:-unset}"; command -v bash; command -v scp' 2>/dev/null || true)"
    [[ -n "$remote" ]] && printf '%s%s%s\n' "$DIM" "$remote" "$RESET"
  elif grep -Eqi 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused' <<<"$out"; then
    warn 'UTM network is not reachable from this connection.'
    warn 'If you are off campus, this is expected: run `utm vpn`, connect UTORvpn, then retry.'
  elif grep -Eqi 'Permission denied' <<<"$out"; then
    pass 'UTM network is reachable'
    warn 'Public-key authentication is not working for this account/key.'
    warn 'Run `utm update` to repair key setup. If a known-correct password is also rejected, contact course staff about UTORid provisioning.'
  elif grep -Eqi 'REMOTE HOST IDENTIFICATION HAS CHANGED|Host key verification failed' <<<"$out"; then
    pass 'UTM network is reachable'
    warn 'SSH host-key verification needs attention. Do not bypass it blindly; verify the host/key change first.'
  else
    warn 'SSH returned an unclassified error:'
    printf '%s%s%s\n' "$DIM" "$out" "$RESET"
  fi
fi

if [[ "$failed" -ne 0 ]]; then
  printf '\n%sOne or more required local checks failed.%s\n' "$RED" "$RESET"
  exit 1
fi
printf '\n%sDiagnostics complete.%s\n' "$GREEN" "$RESET"
