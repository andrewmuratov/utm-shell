#!/usr/bin/env bash
set -uo pipefail

VERSION='1.6.1'
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
  cat <<'EOF_HELP'
utm — UTM lab access

  utm                 connect
  utm status          check connection
  utm vpn             open/setup UTORvpn
  utm host [HOST]     show/change lab computer
  utm files           file-copy examples
  utm doctor          diagnose problems
  utm update          update/repair
  utm help            show this help
EOF_HELP
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

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null
}

open_url() {
  local url="$1"
  if is_wsl 2>/dev/null && command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c start "" "$url" >/dev/null 2>&1
  elif command -v xdg-open >/dev/null 2>&1; then
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

open_vpn_download() {
  open_url "$VPN_DOWNLOAD" || open_url "$VPN_GUIDE" || true
}

windows_vpn_path() {
  command -v powershell.exe >/dev/null 2>&1 || return 1
  powershell.exe -NoProfile -Command '$p=@("$env:ProgramFiles\Cisco\Cisco Secure Client\vpnui.exe","$env:ProgramFiles\Cisco\Cisco Secure Client\UI\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\UI\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe")|Where-Object{Test-Path $_}|Select-Object -First 1; if($p){Write-Output $p; exit 0}else{exit 1}' 2>/dev/null | tr -d '\r'
}

vpn_client_available() {
  case "$(uname -s 2>/dev/null || true)" in
    Darwin)
      open -Ra 'Cisco Secure Client' >/dev/null 2>&1 || open -Ra 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1
      ;;
    Linux*)
      if is_wsl; then
        windows_vpn_path >/dev/null 2>&1
      else
        [[ -x /opt/cisco/secureclient/bin/vpnui || -x /opt/cisco/anyconnect/bin/vpnui ]] || command -v vpnui >/dev/null 2>&1
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*) windows_vpn_path >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
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
      if is_wsl; then
        local win_path
        win_path="$(windows_vpn_path 2>/dev/null || true)"
        [[ -n "$win_path" ]] || return 1
        powershell.exe -NoProfile -Command "Start-Process -FilePath '$win_path'" >/dev/null 2>&1
        return $?
      fi
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
      local win_path
      win_path="$(windows_vpn_path 2>/dev/null || true)"
      [[ -n "$win_path" ]] || return 1
      powershell.exe -NoProfile -Command "Start-Process -FilePath '$win_path'" >/dev/null 2>&1
      return $?
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

print_connect_steps() {
  printf '\n%sUTORvpn%s\n' "$BLUE" "$RESET"
  printf '  %s1.%s Cisco Secure Client opened.\n' "$BLUE" "$RESET"
  printf '  %s2.%s Enter %s%s%s and select Connect.\n' "$BLUE" "$RESET" "$BLUE" "$VPN_SERVER" "$RESET"
  printf '  %s3.%s Sign in with your UTORid and password.\n\n' "$BLUE" "$RESET"
}

print_install_steps() {
  printf '\n%sUTORvpn setup%s\n' "$BLUE" "$RESET"

  case "$(uname -s 2>/dev/null || true)" in
    Darwin)
      printf '  %s1.%s In the page that opened, download the %smacOS%s client.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
      printf '  %s2.%s Open the downloaded .dmg, then run the Cisco Secure Client .pkg.\n' "$BLUE" "$RESET"
      printf '  %s3.%s Accept the licence and uncheck every module except %sVPN%s.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
      printf '  %s4.%s Finish installation. Keep this terminal open.\n\n' "$BLUE" "$RESET"
      ;;
    Linux*)
      if is_wsl; then
        printf '  %s1.%s In the page that opened, download the %sWindows%s client.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
        printf '  %s2.%s If it downloads as a .zip, extract it in Windows.\n' "$BLUE" "$RESET"
        printf '  %s3.%s Run the Cisco Secure Client .msi and finish installation in Windows.\n' "$BLUE" "$RESET"
        printf '  %s4.%s Return here. utm-shell will detect the Windows VPN client.\n\n' "$BLUE" "$RESET"
      elif command -v apt >/dev/null 2>&1; then
        printf '  %s1.%s In the page that opened, choose %sLinux (DEB)%s and download the .tgz.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
        printf '  %s2.%s Extract the .tgz, then open a terminal in the extracted folder.\n' "$BLUE" "$RESET"
        printf '  %s3.%s Install the main VPN package (not vpn-cli):\n' "$BLUE" "$RESET"
        printf '       %ssudo apt install ./cisco-secure-client-vpn_*_amd64.deb%s\n' "$GREEN" "$RESET"
        printf '  %s4.%s Enter your computer password and confirm with y if asked. Keep this terminal open.\n\n' "$BLUE" "$RESET"
      elif command -v dnf >/dev/null 2>&1; then
        printf '  %s1.%s In the page that opened, choose %sLinux (RPM)%s and download the .tgz.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
        printf '  %s2.%s Extract the .tgz, then open a terminal in the extracted folder.\n' "$BLUE" "$RESET"
        printf '  %s3.%s Install the main VPN package (not vpn-cli):\n' "$BLUE" "$RESET"
        printf '       %ssudo dnf install ./cisco-secure-client-vpn-[0-9]*.rpm%s\n' "$GREEN" "$RESET"
        printf '  %s4.%s Enter your computer password and confirm if asked. Keep this terminal open.\n\n' "$BLUE" "$RESET"
      else
        printf '  %s1.%s In the page that opened, download the Linux package for your distro.\n' "$BLUE" "$RESET"
        printf '  %s2.%s Extract the archive.\n' "$BLUE" "$RESET"
        printf '  %s3.%s Install the main cisco-secure-client-vpn package, not vpn-cli.\n' "$BLUE" "$RESET"
        printf '  %s4.%s Keep this terminal open.\n\n' "$BLUE" "$RESET"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      printf '  %s1.%s In the page that opened, download the %sWindows%s client.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
      printf '  %s2.%s If it downloads as a .zip, extract it.\n' "$BLUE" "$RESET"
      printf '  %s3.%s Run the Cisco Secure Client .msi and accept the licence.\n' "$BLUE" "$RESET"
      printf '  %s4.%s Finish installation. Keep this terminal open.\n\n' "$BLUE" "$RESET"
      ;;
    *)
      printf '  %s1.%s Download Cisco Secure Client for your operating system.\n' "$BLUE" "$RESET"
      printf '  %s2.%s Install the VPN component using U of T instructions.\n' "$BLUE" "$RESET"
      printf '  %s3.%s Keep this terminal open.\n\n' "$BLUE" "$RESET"
      ;;
  esac
}

wait_for_vpn() {
  local i spin='|/-\\'
  printf 'Waiting for UTORvpn... '
  for ((i=0; i<90; i++)); do
    probe_network
    if [[ "$PROBE_RESULT" != 'network' ]]; then
      printf '\r%s✓ UTORvpn connected%s                    \n' "$GREEN" "$RESET"
      return 0
    fi
    printf '\rWaiting for UTORvpn... %s' "${spin:i%4:1}"
    sleep 2
  done
  printf '\r%sStill offline.%s                          \n' "$YELLOW" "$RESET"
  return 2
}

wait_for_vpn_client() {
  local i spin='|/-\\'
  printf 'Waiting for Cisco Secure Client... '
  for ((i=0; i<300; i++)); do
    if vpn_client_available; then
      printf '\r%s✓ Cisco Secure Client installed%s        \n' "$GREEN" "$RESET"
      launch_vpn_client || return 2
      print_connect_steps
      wait_for_vpn
      return $?
    fi
    printf '\rWaiting for Cisco Secure Client... %s' "${spin:i%4:1}"
    sleep 2
  done
  printf '\r%sStill waiting for Cisco Secure Client.%s  \n' "$YELLOW" "$RESET"
  return 2
}

vpn_open() {
  probe_network
  if [[ "$PROBE_RESULT" != 'network' ]]; then
    printf '%s✓ UTM is already reachable.%s\n' "$GREEN" "$RESET"
    return 0
  fi

  if launch_vpn_client; then
    print_connect_steps
    wait_for_vpn
    return $?
  fi

  open_vpn_download
  print_install_steps
  wait_for_vpn_client
}

ensure_network() {
  probe_network
  [[ "$PROBE_RESULT" == 'reachable' || "$PROBE_RESULT" == 'unknown' ]] && return 0

  if launch_vpn_client; then
    print_connect_steps
    wait_for_vpn
    return $?
  fi

  open_vpn_download
  print_install_steps
  wait_for_vpn_client
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
  cat <<EOF_FILES
scp FILE ${SSH_ALIAS}:~/            # computer → UTM
scp ${SSH_ALIAS}:~/FILE .            # UTM → computer
scp -r FOLDER ${SSH_ALIAS}:~/        # folder → UTM
EOF_FILES
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
