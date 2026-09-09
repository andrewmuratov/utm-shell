#!/usr/bin/env bash
set -uo pipefail

VPN_GUIDE='https://security.utoronto.ca/services/vpn/usage-guide/'
VPN_SERVER='general.vpn.utoronto.ca'
STATE_DIR="$HOME/.config/utm-shell"
SSH_ALIAS='utm'
[[ -r "$STATE_DIR/alias" ]] && IFS= read -r SSH_ALIAS < "$STATE_DIR/alias"
[[ -n "$SSH_ALIAS" ]] || SSH_ALIAS='utm'

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BLUE=''; GREEN=''; YELLOW=''; DIM=''; RESET=''
fi

usage() {
  cat <<'EOF'
utm — smart UTM lab connection

Usage:
  utm          connect to the configured UTM lab computer
  utm vpn      open Cisco Secure Client, or the official UTORvpn setup guide
  utm raw      run normal `ssh utm` without the network pre-check
  utm help     show this help
EOF
}

open_url() {
  local url="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
    return 0
  elif command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1
    return $?
  elif command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c start "" "$url" >/dev/null 2>&1
    return $?
  fi
  printf '%s\n' "$url"
  return 1
}

launch_vpn_client() {
  case "$(uname -s 2>/dev/null || true)" in
    Darwin)
      if open -Ra 'Cisco Secure Client' >/dev/null 2>&1; then
        open -a 'Cisco Secure Client' >/dev/null 2>&1
        return 0
      fi
      if open -Ra 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1; then
        open -a 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1
        return 0
      fi
      ;;
    Linux*)
      local candidate
      for candidate in \
        /opt/cisco/secureclient/bin/vpnui \
        /opt/cisco/anyconnect/bin/vpnui; do
        if [[ -x "$candidate" ]]; then
          nohup "$candidate" >/dev/null 2>&1 &
          return 0
        fi
      done
      if command -v vpnui >/dev/null 2>&1; then
        nohup vpnui >/dev/null 2>&1 &
        return 0
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -Command \
          '$c=@("$env:ProgramFiles\Cisco\Cisco Secure Client\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe"); $p=$c|Where-Object{Test-Path $_}|Select-Object -First 1; if($p){Start-Process $p; exit 0}else{exit 1}' \
          >/dev/null 2>&1 && return 0
      fi
      ;;
  esac
  return 1
}

vpn_open() {
  printf '\n%sUTORvpn%s\n' "$BLUE" "$RESET"
  if launch_vpn_client; then
    printf '%sOpened Cisco Secure Client.%s\n' "$GREEN" "$RESET"
    printf 'Connect to: %s%s%s\n' "$BLUE" "$VPN_SERVER" "$RESET"
    printf 'Sign in with your UTORid and password.\n'
  else
    printf 'Cisco Secure Client was not found on this computer.\n'
    printf 'Opening the official U of T UTORvpn setup guide...\n'
    if ! open_url "$VPN_GUIDE"; then
      printf 'Guide: %s\n' "$VPN_GUIDE"
    fi
  fi
}

probe_network() {
  local out rc=0
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=6 -o ConnectionAttempts=1 "$SSH_ALIAS" true 2>&1)" || rc=$?

  if [[ $rc -eq 0 ]]; then
    PROBE_RESULT='reachable'
    PROBE_OUTPUT="$out"
    return 0
  fi

  if grep -Eqi 'Permission denied|Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED|authenticity of host' <<<"$out"; then
    PROBE_RESULT='reachable'
  elif grep -Eqi 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused' <<<"$out"; then
    PROBE_RESULT='network'
  else
    PROBE_RESULT='unknown'
  fi
  PROBE_OUTPUT="$out"
  return 0
}

network_message() {
  cat <<EOF

${YELLOW}Can't reach the UTM lab computer.${RESET}

UTM lab machines are normally reachable only from the U of T network.
If you're at home, in a residence/off-campus network, or on public Wi-Fi,
connect to ${BLUE}UTORvpn${RESET} first, then try again.

UTORvpn uses Cisco Secure Client and the general VPN address is:
  ${BLUE}${VPN_SERVER}${RESET}
EOF
}

ensure_network() {
  while true; do
    probe_network
    case "$PROBE_RESULT" in
      reachable|unknown)
        return 0
        ;;
      network)
        network_message
        if [[ ! -t 0 || ! -r /dev/tty ]]; then
          printf '\nRun `%s vpn` for setup help, then retry.\n' "utm"
          return 2
        fi

        printf '\n  [1] Open Cisco Secure Client / UTORvpn setup\n'
        printf '  [2] Open the official U of T VPN guide\n'
        printf '  [r] Retry\n'
        printf '  [q] Quit\n\n'
        printf 'Choose: ' >/dev/tty
        local answer=''
        IFS= read -r answer </dev/tty || return 2
        case "$answer" in
          1|'')
            vpn_open
            printf '\nConnect to UTORvpn, then press Enter to retry (or q to quit): ' >/dev/tty
            IFS= read -r answer </dev/tty || return 2
            [[ "$answer" =~ ^[Qq]$ ]] && return 2
            ;;
          2)
            open_url "$VPN_GUIDE" || true
            printf 'Connect to UTORvpn, then press Enter to retry (or q to quit): ' >/dev/tty
            IFS= read -r answer </dev/tty || return 2
            [[ "$answer" =~ ^[Qq]$ ]] && return 2
            ;;
          r|R) ;;
          q|Q) return 2 ;;
          *) printf 'Unknown choice.\n' ;;
        esac
        ;;
    esac
  done
}

case "${1:-}" in
  -h|--help|help)
    usage
    exit 0
    ;;
  vpn|--vpn)
    vpn_open
    exit 0
    ;;
  raw|--raw)
    exec ssh "$SSH_ALIAS"
    ;;
  --probe)
    probe_network
    [[ "$PROBE_RESULT" == 'reachable' ]] && exit 0
    [[ "$PROBE_RESULT" == 'network' ]] && exit 2
    exit 1
    ;;
  --ensure-network)
    ensure_network
    exit $?
    ;;
  '') ;;
  *)
    printf 'Unknown argument: %s\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

if ensure_network; then
  exec ssh "$SSH_ALIAS"
fi
exit $?
