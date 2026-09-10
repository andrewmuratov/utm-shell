#!/bin/sh
set -u

SSH_ALIAS=${1:-utm}
case "${1:-}" in
  --help|-h)
    printf 'Usage: doctor.sh [ssh-alias]\n'
    exit 0
    ;;
esac

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  ESC=$(printf '\033')
  BLUE="${ESC}[1;34m"
  GREEN="${ESC}[1;32m"
  YELLOW="${ESC}[1;33m"
  RED="${ESC}[1;31m"
  DIM="${ESC}[2m"
  RESET="${ESC}[0m"
else
  BLUE=''; GREEN=''; YELLOW=''; RED=''; DIM=''; RESET=''
fi

failed=0
pass() { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%s✗%s %s\n' "$RED" "$RESET" "$*"; failed=1; }

printf '\n%sutm-shell doctor%s\n\n' "$BLUE" "$RESET"
printf 'platform: %s\n' "$(uname -s 2>/dev/null || printf unknown)"

for cmd in ssh ssh-keygen scp; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd: $(command -v "$cmd")"
  elif [ "$cmd" = ssh ]; then
    fail "$cmd not found"
  else
    warn "$cmd not found"
  fi
done

if command -v utm >/dev/null 2>&1; then
  pass "utm command: $(command -v utm)"
else
  warn 'utm is not on PATH in this shell; open a new terminal or rerun setup'
fi

if [ -f "$HOME/.ssh/config" ]; then
  if grep -q '^# >>> utm-shell >>>$' "$HOME/.ssh/config"; then
    pass 'managed SSH config is present'
  else
    warn 'SSH config exists, but no utm-shell block was found'
  fi
else
  fail 'SSH config not found'
fi

if command -v ssh >/dev/null 2>&1; then
  if ssh -G "$SSH_ALIAS" >/dev/null 2>&1; then
    host=$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="hostname" {print $2; exit}')
    user=$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="user" {print $2; exit}')
    pass "SSH alias '$SSH_ALIAS' -> ${user}@${host}"
  else
    fail "SSH alias '$SSH_ALIAS' is invalid"
  fi

  out=$(ssh -o BatchMode=yes -o ConnectTimeout=6 -o ConnectionAttempts=1 "$SSH_ALIAS" true 2>&1)
  rc=$?

  if [ "$rc" -eq 0 ]; then
    pass 'UTM network is reachable'
    pass 'passwordless SSH works'
    remote=$(ssh -o ConnectTimeout=6 "$SSH_ALIAS" 'printf "shell=%s term=%s\n" "$SHELL" "${TERM:-unset}"; command -v bash; command -v scp' 2>/dev/null || true)
    [ -n "$remote" ] && printf '%s%s%s\n' "$DIM" "$remote" "$RESET"
  elif printf '%s\n' "$out" | grep -Eqi 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused'; then
    warn 'UTM is not reachable from this network.'
    warn 'Off campus: run `utm vpn`, connect UTORvpn, then retry.'
  elif printf '%s\n' "$out" | grep -Eqi 'Permission denied'; then
    pass 'UTM network is reachable'
    warn 'Public-key authentication is not working.'
    warn 'Run `utm update`. If a correct password is also rejected, ask course staff about UTORid provisioning.'
  elif printf '%s\n' "$out" | grep -Eqi 'REMOTE HOST IDENTIFICATION HAS CHANGED|Host key verification failed'; then
    pass 'UTM network is reachable'
    warn 'SSH host-key verification needs attention. Verify the host/key change before removing the stale key.'
  else
    warn 'SSH returned an unclassified error:'
    printf '%s%s%s\n' "$DIM" "$out" "$RESET"
  fi
fi

case "$(uname -s 2>/dev/null || true)" in
  FreeBSD|OpenBSD|NetBSD|DragonFly)
    warn 'U of T does not publish Cisco Secure Client for BSD; off-campus VPN must be provided separately.'
    ;;
esac

if [ "$failed" -ne 0 ]; then
  printf '\n%sOne or more required local checks failed.%s\n' "$RED" "$RESET"
  exit 1
fi

printf '\n%sDiagnostics complete.%s\n' "$GREEN" "$RESET"
