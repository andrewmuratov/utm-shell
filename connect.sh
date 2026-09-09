#!/usr/bin/env bash
set -uo pipefail

VERSION='1.5.0'
REPO_RAW='https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
VPN_GUIDE='https://security.utoronto.ca/services/vpn/usage-guide/'
VPN_DOWNLOAD='https://uoft.me/cisco-vpn-download'
VPN_SERVER='general.vpn.utoronto.ca'
STATE_DIR="$HOME/.config/utm-shell"
STATE_FILE="$STATE_DIR/config"
SSH_ALIAS='utm'

if [[ -r "$STATE_DIR/alias" ]]; then
  IFS= read -r SSH_ALIAS < "$STATE_DIR/alias"
fi
[[ -n "$SSH_ALIAS" ]] || SSH_ALIAS='utm'

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BLUE=''; GREEN=''; YELLOW=''; DIM=''; RESET=''
fi

usage() {
  cat <<'EOF'
utm — UTM lab access

  utm                 connect
  utm status          check connection
  utm vpn             open/setup UTORvpn
  utm host [HOST]     show/change lab computer
  utm files           file-copy examples
  utm doctor          diagnose problems
  utm update          update/repair
  utm help            show this help
EOF
}

state_value() {
  local key="$1"
  [[ -r "$STATE_FILE" ]] || return 1
  awk -F= -v key="$key" '$1==key {v=substr($0,index($0,"=")+1); gsub(/^\047|\047$/, "", v); print v; exit}' "$STATE_FILE"
}

current_host() {
  ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="hostname" {print $2; exit}'
}

current_user() {
  ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="user" {print $2; exit}'
}

open_url() {
  local url="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1
  elif command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c start "" "$url" >/dev/null 2>&1
  else
    printf '%s\n' "$url"
    return 1
  fi
}

launch_vpn_client() {
  case "$(uname -s 2>/dev/null || true)" in
    Darwin)
      if open -Ra 'Cisco Secure Client' >/dev/null 2>&1; then
        open -a 'Cisco Secure Client' >/dev/null 2>&1; return 0
      fi
      if open -Ra 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1; then
        open -a 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1; return 0
      fi
      ;;
    Linux*)
      local candidate
      for candidate in /opt/cisco/secureclient/bin/vpnui /opt/cisco/anyconnect/bin/vpnui; do
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
        powershell.exe -NoProfile -Command '$p=@("$env:ProgramFiles\Cisco\Cisco Secure Client\vpnui.exe","$env:ProgramFiles\Cisco\Cisco Secure Client\UI\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\UI\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe")|Where-Object{Test-Path $_}|Select-Object -First 1; if($p){Start-Process $p; exit 0}else{exit 1}' >/dev/null 2>&1 && return 0
      fi
      ;;
  esac
  return 1
}

probe_network() {
  local out rc=0
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 "$SSH_ALIAS" true 2>&1)" || rc=$?

  if [[ $rc -eq 0 ]]; then
    PROBE_RESULT='reachable'
  elif grep -Eqi 'Permission denied|Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED|authenticity of host' <<<"$out"; then
    PROBE_RESULT='reachable'
  elif grep -Eqi 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused' <<<"$out"; then
    PROBE_RESULT='network'
  else
    PROBE_RESULT='unknown'
  fi
  PROBE_OUTPUT="$out"
}

wait_for_vpn() {
  local i spin='|/-\\'
  printf 'Waiting for UTORvpn... '
  for ((i=0; i<90; i++)); do
    probe_network
    if [[ "$PROBE_RESULT" != 'network' ]]; then
      printf '\r%s✓ UTORvpn connected%s        \n' "$GREEN" "$RESET"
      return 0
    fi
    printf '\rWaiting for UTORvpn... %s' "${spin:i%4:1}"
    sleep 2
  done
  printf '\r%sStill offline.%s              \n' "$YELLOW" "$RESET"
  return 2
}

vpn_open() {
  if launch_vpn_client; then
    printf '%sOpened Cisco Secure Client.%s Connect to %s.\n' "$GREEN" "$RESET" "$VPN_SERVER"
    return 0
  fi

  open_url "$VPN_DOWNLOAD" || open_url "$VPN_GUIDE" || true
  printf '%sCisco Secure Client is not installed.%s\n' "$YELLOW" "$RESET"
  printf 'Opened the official U of T download page. Install the VPN module, then run `utm` again.\n'
  return 2
}

ensure_network() {
  probe_network
  [[ "$PROBE_RESULT" == 'reachable' || "$PROBE_RESULT" == 'unknown' ]] && return 0

  printf '\n%sUTORvpn required off campus.%s\n' "$YELLOW" "$RESET"
  if launch_vpn_client; then
    printf 'Cisco Secure Client opened. Connect to %s.\n' "$VPN_SERVER"
    wait_for_vpn
    return $?
  fi

  open_url "$VPN_DOWNLOAD" || open_url "$VPN_GUIDE" || true
  printf 'Cisco Secure Client is not installed. The official U of T download page was opened.\n'
  printf 'Install the VPN module, then run `utm` again.\n'
  return 2
}

show_status() {
  local host user
  host="$(current_host)"
  user="$(current_user)"
  probe_network
  printf '%s@%s — ' "${user:-?}" "${host:-?}"
  case "$PROBE_RESULT" in
    reachable) printf '%sready%s\n' "$GREEN" "$RESET" ;;
    network) printf '%sUTORvpn needed%s\n' "$YELLOW" "$RESET" ;;
    *) printf '%scheck failed%s\n' "$YELLOW" "$RESET"; [[ -n "$PROBE_OUTPUT" ]] && printf '%s%s%s\n' "$DIM" "$PROBE_OUTPUT" "$RESET" ;;
  esac
}

set_host() {
  local new="${1:-}"
  if [[ -z "$new" ]]; then
    current_host
    return 0
  fi
  [[ "$new" =~ ^[A-Za-z0-9.-]+$ ]] || { printf 'Invalid host.\n' >&2; return 2; }
  [[ "$new" == *.* ]] || new="${new}.utm.utoronto.ca"

  local config="$HOME/.ssh/config" tmp
  [[ -f "$config" ]] || { printf 'Run setup again.\n' >&2; return 2; }
  tmp="$(mktemp)"
  awk -v start='# >>> utm-shell >>>' -v end='# <<< utm-shell <<<' -v host="$new" '
    $0==start {inside=1; print; next}
    $0==end {inside=0; print; next}
    inside && $1=="HostName" {print "    HostName " host; next}
    {print}
  ' "$config" > "$tmp" && cat "$tmp" > "$config"
  rm -f "$tmp"

  if [[ -f "$STATE_FILE" ]]; then
    tmp="$(mktemp)"
    awk -v host="$new" '/^UTM_HOST=/ {print "UTM_HOST=\047" host "\047"; done=1; next} {print} END {if(!done) print "UTM_HOST=\047" host "\047"}' "$STATE_FILE" > "$tmp" && cat "$tmp" > "$STATE_FILE"
    rm -f "$tmp"
  fi
  printf '%s%s%s\n' "$GREEN" "$new" "$RESET"
}

show_files() {
  cat <<EOF
scp FILE ${SSH_ALIAS}:~/            # computer → UTM
scp ${SSH_ALIAS}:~/FILE .            # UTM → computer
scp -r FOLDER ${SSH_ALIAS}:~/        # folder → UTM
EOF
}

run_doctor() {
  local tmp="$(mktemp)" rc
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW/doctor.sh" > "$tmp" || { rm -f "$tmp"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp" "$REPO_RAW/doctor.sh" || { rm -f "$tmp"; return 1; }
  else
    printf 'curl or wget required.\n' >&2; rm -f "$tmp"; return 1
  fi
  bash "$tmp" "$SSH_ALIAS"; rc=$?; rm -f "$tmp"; return $rc
}

run_update() {
  local user host key tmp="$(mktemp)" rc
  user="$(state_value UTORID 2>/dev/null || true)"
  host="$(state_value UTM_HOST 2>/dev/null || true)"
  key="$(state_value KEY_PATH 2>/dev/null || true)"
  [[ -n "$user" && -n "$host" ]] || { printf 'Run setup again.\n' >&2; rm -f "$tmp"; return 2; }

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW/setup.sh" > "$tmp" || { rm -f "$tmp"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp" "$REPO_RAW/setup.sh" || { rm -f "$tmp"; return 1; }
  else
    printf 'curl or wget required.\n' >&2; rm -f "$tmp"; return 1
  fi

  if [[ -n "$key" ]]; then
    bash "$tmp" --user "$user" --host "$host" --key "$key"
  else
    bash "$tmp" --user "$user" --host "$host"
  fi
  rc=$?; rm -f "$tmp"; return $rc
}

case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
  status) show_status; exit $? ;;
  vpn|--vpn) vpn_open; exit $? ;;
  guide) open_url "$VPN_GUIDE" || true; exit 0 ;;
  host) set_host "${2:-}"; exit $? ;;
  files) show_files; exit 0 ;;
  doctor) run_doctor; exit $? ;;
  update|repair) run_update; exit $? ;;
  raw|--raw) exec ssh "$SSH_ALIAS" ;;
  --probe)
    probe_network
    [[ "$PROBE_RESULT" == 'reachable' ]] && exit 0
    [[ "$PROBE_RESULT" == 'network' ]] && exit 2
    exit 1
    ;;
  --ensure-network) ensure_network; exit $? ;;
  '') ;;
  *) printf 'Unknown command. Try `utm help`.\n' >&2; exit 2 ;;
esac

ensure_network || exit $?
exec ssh "$SSH_ALIAS"
