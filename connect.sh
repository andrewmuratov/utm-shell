#!/usr/bin/env bash
set -uo pipefail

VERSION='1.4.0'
REPO_RAW='https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
VPN_GUIDE='https://security.utoronto.ca/services/vpn/usage-guide/'
VPN_SERVER='general.vpn.utoronto.ca'
STATE_DIR="$HOME/.config/utm-shell"
STATE_FILE="$STATE_DIR/config"
SSH_ALIAS='utm'

if [[ -r "$STATE_DIR/alias" ]]; then
  IFS= read -r SSH_ALIAS < "$STATE_DIR/alias"
fi
[[ -n "$SSH_ALIAS" ]] || SSH_ALIAS='utm'

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BLUE=''; GREEN=''; YELLOW=''; RED=''; DIM=''; RESET=''
fi

usage() {
  cat <<'EOF'
utm — simple UTM lab access

Most of the time:
  utm                 connect to your configured UTM lab computer

Useful commands:
  utm status          show host + whether UTM is reachable right now
  utm vpn             open Cisco Secure Client, or U of T's VPN setup guide
  utm host             show the configured lab computer
  utm host HOST        switch to another lab computer
  utm files           show copy-to/from-UTM examples
  utm doctor          run current diagnostics
  utm update          update/repair utm-shell
  utm raw             run plain `ssh utm`
  utm help            show this help

Off campus:
  `utm` detects the common home/public-Wi-Fi case before SSH starts and offers
  UTORvpn help instead of leaving you at a timeout.
EOF
}

state_value() {
  local key="$1"
  [[ -r "$STATE_FILE" ]] || return 1
  awk -F= -v key="$key" '$1==key {value=substr($0,index($0,"=")+1); gsub(/^\047|\047$/, "", value); print value; exit}' "$STATE_FILE"
}

current_host() {
  local host=''
  host="$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="hostname" {print $2; exit}')"
  printf '%s' "$host"
}

current_user() {
  local user=''
  user="$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="user" {print $2; exit}')"
  printf '%s' "$user"
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

vpn_client_available() {
  case "$(uname -s 2>/dev/null || true)" in
    Darwin)
      open -Ra 'Cisco Secure Client' >/dev/null 2>&1 || open -Ra 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1
      ;;
    Linux*)
      [[ -x /opt/cisco/secureclient/bin/vpnui || -x /opt/cisco/anyconnect/bin/vpnui ]] || command -v vpnui >/dev/null 2>&1
      ;;
    MINGW*|MSYS*|CYGWIN*)
      command -v powershell.exe >/dev/null 2>&1 && powershell.exe -NoProfile -Command '$p=@("$env:ProgramFiles\Cisco\Cisco Secure Client\vpnui.exe","$env:ProgramFiles\Cisco\Cisco Secure Client\UI\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\UI\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe"); if($p|Where-Object{Test-Path $_}|Select-Object -First 1){exit 0}else{exit 1}' >/dev/null 2>&1
      ;;
    *) return 1 ;;
  esac
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

vpn_open() {
  printf '\n%sUTORvpn%s\n' "$BLUE" "$RESET"
  if launch_vpn_client; then
    printf '%sOpened Cisco Secure Client.%s\n' "$GREEN" "$RESET"
    printf 'Server: %s%s%s\n' "$BLUE" "$VPN_SERVER" "$RESET"
    printf 'Group:  UofT Default\n'
    printf 'Sign in with your UTORid and password, then return here.\n'
  else
    printf 'Cisco Secure Client is not installed yet.\n'
    printf 'Opening the official U of T install/connect guide...\n'
    if ! open_url "$VPN_GUIDE"; then
      printf 'Guide: %s\n' "$VPN_GUIDE"
    fi
    printf '\nAfter installing Cisco Secure Client, connect to:\n'
    printf '  %s%s%s\n' "$BLUE" "$VPN_SERVER" "$RESET"
  fi
}

probe_network() {
  local out rc=0
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=6 -o ConnectionAttempts=1 "$SSH_ALIAS" true 2>&1)" || rc=$?

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

network_message() {
  cat <<EOF

${YELLOW}UTM is not reachable from this network.${RESET}

This is normal if you're at home, off campus, in residence on a non-U of T
network, or on public Wi-Fi. UTM lab computers normally require either:

  • the U of T campus network, or
  • ${BLUE}UTORvpn${RESET}

This usually is ${GREEN}not a password problem${RESET}.
UTORvpn server: ${BLUE}${VPN_SERVER}${RESET}
EOF
}

ensure_network() {
  while true; do
    probe_network
    case "$PROBE_RESULT" in
      reachable) return 0 ;;
      unknown)
        return 0
        ;;
      network)
        network_message
        if [[ ! -r /dev/tty ]]; then
          printf '\nRun `utm vpn`, connect, then run `utm` again.\n'
          return 2
        fi

        printf '\nPress Enter to open/setup UTORvpn, or choose:\n'
        printf '  [g] official U of T VPN guide\n'
        printf '  [r] retry\n'
        printf '  [q] quit\n\n'
        printf 'Choice [Enter]: ' >/dev/tty
        local answer=''
        IFS= read -r answer </dev/tty || return 2
        case "$answer" in
          ''|v|V)
            vpn_open
            printf '\nConnect to UTORvpn, then press Enter to retry (q to quit): ' >/dev/tty
            IFS= read -r answer </dev/tty || return 2
            [[ "$answer" =~ ^[Qq]$ ]] && return 2
            ;;
          g|G)
            open_url "$VPN_GUIDE" || true
            printf 'Connect to UTORvpn, then press Enter to retry (q to quit): ' >/dev/tty
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

show_status() {
  local host user
  host="$(current_host)"
  user="$(current_user)"
  printf '\n%sutm-shell%s %s\n' "$BLUE" "$RESET" "$VERSION"
  printf 'User: %s\n' "${user:-unknown}"
  printf 'Host: %s\n' "${host:-unknown}"
  if vpn_client_available; then
    printf 'Cisco Secure Client: installed\n'
  else
    printf 'Cisco Secure Client: not detected\n'
  fi
  printf 'Checking UTM network... '
  probe_network
  case "$PROBE_RESULT" in
    reachable) printf '%sreachable%s\n' "$GREEN" "$RESET" ;;
    network) printf '%snot reachable%s — use `utm vpn` off campus\n' "$YELLOW" "$RESET" ;;
    unknown) printf '%suncertain%s\n' "$YELLOW" "$RESET"; [[ -n "$PROBE_OUTPUT" ]] && printf '%s%s%s\n' "$DIM" "$PROBE_OUTPUT" "$RESET" ;;
  esac
}

set_host() {
  local new="${1:-}"
  if [[ -z "$new" ]]; then
    current_host
    printf '\n'
    return 0
  fi
  [[ "$new" =~ ^[A-Za-z0-9.-]+$ ]] || { printf 'Invalid lab hostname.\n' >&2; return 2; }
  [[ "$new" == *.* ]] || new="${new}.utm.utoronto.ca"

  local config="$HOME/.ssh/config" tmp
  [[ -f "$config" ]] || { printf 'SSH config not found. Run setup again.\n' >&2; return 2; }
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
    awk -v host="$new" '
      /^UTM_HOST=/ {print "UTM_HOST=\047" host "\047"; done=1; next}
      {print}
      END {if(!done) print "UTM_HOST=\047" host "\047"}
    ' "$STATE_FILE" > "$tmp" && cat "$tmp" > "$STATE_FILE"
    rm -f "$tmp"
  fi
  printf '%sSwitched UTM host to:%s %s\n' "$GREEN" "$RESET" "$new"
}

show_files() {
  cat <<EOF

Copy files from your own computer:

  computer → UTM
    scp FILE ${SSH_ALIAS}:~/

  UTM → computer
    scp ${SSH_ALIAS}:~/FILE .

  whole folder → UTM
    scp -r FOLDER ${SSH_ALIAS}:~/
EOF
}

run_doctor() {
  local tmp
  tmp="$(mktemp)"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW/doctor.sh" > "$tmp" || { rm -f "$tmp"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp" "$REPO_RAW/doctor.sh" || { rm -f "$tmp"; return 1; }
  else
    printf 'curl or wget is required to run the current doctor.\n' >&2
    return 1
  fi
  bash "$tmp" "$SSH_ALIAS"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

run_update() {
  local user host key tmp
  user="$(state_value UTORID 2>/dev/null || true)"
  host="$(state_value UTM_HOST 2>/dev/null || true)"
  key="$(state_value KEY_PATH 2>/dev/null || true)"
  [[ -n "$user" && -n "$host" ]] || {
    printf 'Saved setup information is missing. Run the setup command from the README again.\n' >&2
    return 2
  }
  tmp="$(mktemp)"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW/setup.sh" > "$tmp" || { rm -f "$tmp"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp" "$REPO_RAW/setup.sh" || { rm -f "$tmp"; return 1; }
  else
    printf 'curl or wget is required to update.\n' >&2
    return 1
  fi
  if [[ -n "$key" ]]; then
    bash "$tmp" --user "$user" --host "$host" --key "$key"
  else
    bash "$tmp" --user "$user" --host "$host"
  fi
  local rc=$?
  rm -f "$tmp"
  return $rc
}

case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
  status) show_status; exit $? ;;
  vpn|--vpn) vpn_open; exit 0 ;;
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
  *)
    printf 'Unknown command: %s\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

if ensure_network; then
  exec ssh "$SSH_ALIAS"
fi
exit $?
