#!/bin/sh
set -u

VERSION='1.7.0'
REPO_RAW='https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
VPN_GUIDE='https://security.utoronto.ca/services/vpn/usage-guide/'
VPN_DOWNLOAD='https://uoft.me/cisco-vpn-download'
VPN_SERVER='general.vpn.utoronto.ca'
STATE_DIR="$HOME/.config/utm-shell"
STATE_FILE="$STATE_DIR/config"
SSH_ALIAS='utm'

if [ -r "$STATE_DIR/alias" ]; then
  IFS= read -r SSH_ALIAS <"$STATE_DIR/alias" || true
fi
[ -n "$SSH_ALIAS" ] || SSH_ALIAS='utm'

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  ESC=$(printf '\033')
  BLUE="${ESC}[1;34m"
  GREEN="${ESC}[1;32m"
  YELLOW="${ESC}[1;33m"
  DIM="${ESC}[2m"
  RESET="${ESC}[0m"
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

current_host() {
  ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="hostname" {print $2; exit}'
}

current_user() {
  ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="user" {print $2; exit}'
}

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
    printf 'Need one downloader: curl, wget, fetch, or ftp.\n' >&2
    return 1
  fi
}

uname_s=$(uname -s 2>/dev/null || printf 'Unknown')
uname_m=$(uname -m 2>/dev/null || printf 'unknown')
is_wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] && return 0
  [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null
}

platform_kind() {
  case "$uname_s" in
    Darwin) printf 'macos\n' ;;
    Linux)
      if is_wsl; then printf 'wsl\n'; else printf 'linux\n'; fi
      ;;
    FreeBSD) printf 'freebsd\n' ;;
    OpenBSD) printf 'openbsd\n' ;;
    NetBSD) printf 'netbsd\n' ;;
    DragonFly) printf 'dragonflybsd\n' ;;
    MINGW*|MSYS*|CYGWIN*) printf 'windows-unix\n' ;;
    *) printf 'unix\n' ;;
  esac
}

open_url() {
  _url=$1
  if is_wsl 2>/dev/null && command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c start "" "$_url" >/dev/null 2>&1
  elif [ "$uname_s" = "Darwin" ] && command -v open >/dev/null 2>&1; then
    open "$_url" >/dev/null 2>&1
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$_url" >/dev/null 2>&1 &
  elif command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c start "" "$_url" >/dev/null 2>&1
  else
    printf '%s\n' "$_url"
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
  case "$(platform_kind)" in
    macos)
      open -Ra 'Cisco Secure Client' >/dev/null 2>&1 ||
        open -Ra 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1
      ;;
    wsl|windows-unix)
      windows_vpn_path >/dev/null 2>&1
      ;;
    linux)
      [ -x /opt/cisco/secureclient/bin/vpnui ] ||
        [ -x /opt/cisco/anyconnect/bin/vpnui ] ||
        command -v vpnui >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

launch_vpn_client() {
  case "$(platform_kind)" in
    macos)
      if open -Ra 'Cisco Secure Client' >/dev/null 2>&1; then
        open -a 'Cisco Secure Client' >/dev/null 2>&1
        return 0
      fi
      if open -Ra 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1; then
        open -a 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1
        return 0
      fi
      ;;
    wsl|windows-unix)
      win_path=$(windows_vpn_path 2>/dev/null || true)
      [ -n "$win_path" ] || return 1
      powershell.exe -NoProfile -Command "Start-Process -FilePath '$win_path'" >/dev/null 2>&1
      return $?
      ;;
    linux)
      for candidate in /opt/cisco/secureclient/bin/vpnui /opt/cisco/anyconnect/bin/vpnui; do
        if [ -x "$candidate" ]; then
          "$candidate" >/dev/null 2>&1 &
          return 0
        fi
      done
      if command -v vpnui >/dev/null 2>&1; then
        vpnui >/dev/null 2>&1 &
        return 0
      fi
      ;;
  esac
  return 1
}

probe_network() {
  PROBE_OUTPUT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 "$SSH_ALIAS" true 2>&1)
  _rc=$?

  if [ "$_rc" -eq 0 ]; then
    PROBE_RESULT='reachable'
  elif printf '%s\n' "$PROBE_OUTPUT" | grep -Eqi 'Permission denied|Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED|authenticity of host'; then
    PROBE_RESULT='reachable'
  elif printf '%s\n' "$PROBE_OUTPUT" | grep -Eqi 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused'; then
    PROBE_RESULT='network'
  else
    PROBE_RESULT='unknown'
  fi
}

print_connect_steps() {
  printf '\n%sUTORvpn%s\n' "$BLUE" "$RESET"
  printf '  %s1.%s Cisco Secure Client opened.\n' "$BLUE" "$RESET"
  printf '  %s2.%s Enter %s%s%s and select Connect.\n' "$BLUE" "$RESET" "$BLUE" "$VPN_SERVER" "$RESET"
  printf '  %s3.%s Sign in with your UTORid and password.\n\n' "$BLUE" "$RESET"
}

native_cisco_install_supported() {
  case "$(platform_kind)" in
    macos|wsl|windows-unix) return 0 ;;
    linux)
      case "$uname_m" in
        x86_64|amd64) ;;
        *) return 1 ;;
      esac
      command -v apt >/dev/null 2>&1 && return 0
      command -v apt-get >/dev/null 2>&1 && return 0
      command -v dnf >/dev/null 2>&1 && return 0
      command -v yum >/dev/null 2>&1 && return 0
      return 1
      ;;
    *) return 1 ;;
  esac
}

print_install_steps() {
  printf '\n%sUTORvpn setup%s\n' "$BLUE" "$RESET"

  case "$(platform_kind)" in
    macos)
      printf '  %s1.%s Download the %smacOS%s Cisco Secure Client from the page that opened.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
      printf '  %s2.%s Open the .dmg, run the .pkg, and install only the %sVPN%s module.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
      printf '  %s3.%s Finish installation. Leave this terminal open.\n\n' "$BLUE" "$RESET"
      ;;
    wsl)
      printf '  %s1.%s Download the %sWindows%s Cisco Secure Client from the page that opened.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
      printf '  %s2.%s Extract the ZIP if needed and run the VPN .msi in Windows.\n' "$BLUE" "$RESET"
      printf '  %s3.%s Finish installation. Return here; detection is automatic.\n\n' "$BLUE" "$RESET"
      ;;
    windows-unix)
      printf '  %s1.%s Download the %sWindows%s Cisco Secure Client from the page that opened.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
      printf '  %s2.%s Extract the ZIP if needed and run the VPN .msi.\n' "$BLUE" "$RESET"
      printf '  %s3.%s Finish installation. Leave this terminal open.\n\n' "$BLUE" "$RESET"
      ;;
    linux)
      if [ "$uname_m" != "x86_64" ] && [ "$uname_m" != "amd64" ]; then
        printf '  %s1.%s U of T currently publishes the Linux Cisco download for x86_64 systems.\n' "$BLUE" "$RESET"
        printf '  %s2.%s Use campus Wi-Fi or another U of T-supported VPN environment on this architecture.\n' "$BLUE" "$RESET"
        printf '  %s3.%s Leave this terminal open; utm-shell will continue when UTM is reachable.\n\n' "$BLUE" "$RESET"
      elif command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then
        printf '  %s1.%s Choose %sLinux (DEB)%s and download the .tgz.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
        printf '  %s2.%s Extract it, then install the main VPN package (not vpn-cli):\n' "$BLUE" "$RESET"
        printf '       %ssudo apt install ./cisco-secure-client-vpn_*_amd64.deb%s\n' "$GREEN" "$RESET"
        printf '  %s3.%s Leave this terminal open; detection is automatic.\n\n' "$BLUE" "$RESET"
      elif command -v dnf >/dev/null 2>&1; then
        printf '  %s1.%s Choose %sLinux (RPM)%s and download the .tgz.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
        printf '  %s2.%s Extract it, then install the main VPN package (not vpn-cli):\n' "$BLUE" "$RESET"
        printf '       %ssudo dnf install ./cisco-secure-client-vpn-[0-9]*.rpm%s\n' "$GREEN" "$RESET"
        printf '  %s3.%s Leave this terminal open; detection is automatic.\n\n' "$BLUE" "$RESET"
      elif command -v yum >/dev/null 2>&1; then
        printf '  %s1.%s Choose %sLinux (RPM)%s and download the .tgz.\n' "$BLUE" "$RESET" "$BLUE" "$RESET"
        printf '  %s2.%s Extract it, then install the main VPN package (not vpn-cli):\n' "$BLUE" "$RESET"
        printf '       %ssudo yum install ./cisco-secure-client-vpn-[0-9]*.rpm%s\n' "$GREEN" "$RESET"
        printf '  %s3.%s Leave this terminal open; detection is automatic.\n\n' "$BLUE" "$RESET"
      else
        printf '  %s1.%s U of T currently publishes Linux Cisco clients as DEB/RPM packages.\n' "$BLUE" "$RESET"
        printf '  %s2.%s If your distro can use one, install the main VPN package from the page opened.\n' "$BLUE" "$RESET"
        printf '  %s3.%s Otherwise use campus Wi-Fi or another U of T-supported VPN environment.\n' "$BLUE" "$RESET"
        printf '  %s4.%s Leave this terminal open; utm-shell will continue when UTM is reachable.\n\n' "$BLUE" "$RESET"
      fi
      ;;
    freebsd|openbsd|netbsd|dragonflybsd)
      printf '  %s1.%s U of T does not publish a Cisco Secure Client package for this BSD platform.\n' "$BLUE" "$RESET"
      printf '  %s2.%s Use U of T campus Wi-Fi or connect through a supported VPN environment.\n' "$BLUE" "$RESET"
      printf '  %s3.%s Leave this terminal open; utm-shell will continue when UTM is reachable.\n\n' "$BLUE" "$RESET"
      ;;
    *)
      printf '  %s1.%s Open the U of T VPN guide shown in your browser.\n' "$BLUE" "$RESET"
      printf '  %s2.%s Connect so that UTM lab hosts are reachable.\n' "$BLUE" "$RESET"
      printf '  %s3.%s Leave this terminal open; utm-shell will continue automatically.\n\n' "$BLUE" "$RESET"
      ;;
  esac
}

wait_for_network() {
  _label=$1
  _limit=$2
  _i=0
  printf '%s... ' "$_label"

  while [ "$_i" -lt "$_limit" ]; do
    probe_network
    if [ "$PROBE_RESULT" != 'network' ]; then
      printf '\r%s✓ UTM network ready%s                         \n' "$GREEN" "$RESET"
      return 0
    fi
    case $(( _i % 4 )) in
      0) _char='|' ;;
      1) _char='/' ;;
      2) _char='-' ;;
      *) _char='\\' ;;
    esac
    printf '\r%s... %s' "$_label" "$_char"
    sleep 2
    _i=$(( _i + 1 ))
  done

  printf '\r%sStill offline.%s                              \n' "$YELLOW" "$RESET"
  return 2
}

wait_for_vpn() {
  wait_for_network 'Waiting for UTORvpn' 150
}

wait_for_vpn_client() {
  _i=0
  printf 'Waiting for Cisco Secure Client... '

  while [ "$_i" -lt 900 ]; do
    if vpn_client_available; then
      printf '\r%s✓ Cisco Secure Client installed%s             \n' "$GREEN" "$RESET"
      launch_vpn_client || return 2
      print_connect_steps
      wait_for_vpn
      return $?
    fi

    case $(( _i % 4 )) in
      0) _char='|' ;;
      1) _char='/' ;;
      2) _char='-' ;;
      *) _char='\\' ;;
    esac
    printf '\rWaiting for Cisco Secure Client... %s' "$_char"
    sleep 2
    _i=$(( _i + 1 ))
  done

  printf '\r%sStill waiting for Cisco Secure Client.%s      \n' "$YELLOW" "$RESET"
  return 2
}

vpn_open() {
  probe_network
  if [ "$PROBE_RESULT" != 'network' ]; then
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

  if native_cisco_install_supported; then
    wait_for_vpn_client
  else
    wait_for_network 'Waiting for UTM network' 900
  fi
}

ensure_network() {
  probe_network
  if [ "$PROBE_RESULT" = 'reachable' ] || [ "$PROBE_RESULT" = 'unknown' ]; then
    return 0
  fi

  if launch_vpn_client; then
    print_connect_steps
    wait_for_vpn
    return $?
  fi

  open_vpn_download
  print_install_steps

  if native_cisco_install_supported; then
    wait_for_vpn_client
  else
    wait_for_network 'Waiting for UTM network' 900
  fi
}

show_status() {
  host=$(current_host)
  user=$(current_user)
  probe_network
  printf '%s@%s — ' "${user:-?}" "${host:-?}"

  case "$PROBE_RESULT" in
    reachable) printf '%sready%s\n' "$GREEN" "$RESET" ;;
    network) printf '%sUTORvpn/network needed%s\n' "$YELLOW" "$RESET" ;;
    *)
      printf '%scheck failed%s\n' "$YELLOW" "$RESET"
      [ -n "$PROBE_OUTPUT" ] && printf '%s%s%s\n' "$DIM" "$PROBE_OUTPUT" "$RESET"
      ;;
  esac
}

set_host() {
  new=${1:-}
  if [ -z "$new" ]; then
    current_host
    return 0
  fi

  case "$new" in
    *[!A-Za-z0-9.-]*)
      printf 'Invalid host.\n' >&2
      return 2
      ;;
  esac

  case "$new" in
    *.*) ;;
    *) new="${new}.utm.utoronto.ca" ;;
  esac

  config="$HOME/.ssh/config"
  [ -f "$config" ] || { printf 'Run setup again.\n' >&2; return 2; }

  tmp=$(mktemp)
  awk -v start='# >>> utm-shell >>>' -v end='# <<< utm-shell <<<' -v host="$new" '
    $0 == start { inside=1; print; next }
    $0 == end   { inside=0; print; next }
    inside && $1 == "HostName" { print "    HostName " host; next }
    { print }
  ' "$config" >"$tmp" && cat "$tmp" >"$config"
  rm -f "$tmp"

  if [ -f "$STATE_FILE" ]; then
    tmp=$(mktemp)
    awk -F= -v host="$new" '
      $1 == "UTM_HOST" { print "UTM_HOST=" host; done=1; next }
      { print }
      END { if (!done) print "UTM_HOST=" host }
    ' "$STATE_FILE" >"$tmp" && cat "$tmp" >"$STATE_FILE"
    rm -f "$tmp"
  fi

  printf '%s%s%s\n' "$GREEN" "$new" "$RESET"
}

show_files() {
  cat <<EOF
scp FILE ${SSH_ALIAS}:~/             # computer -> UTM
scp ${SSH_ALIAS}:~/FILE .             # UTM -> computer
scp -r FOLDER ${SSH_ALIAS}:~/         # folder -> UTM
EOF
}

run_doctor() {
  tmp=$(mktemp)
  if ! fetch_url "$REPO_RAW/doctor.sh" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  sh "$tmp" "$SSH_ALIAS"
  rc=$?
  rm -f "$tmp"
  return "$rc"
}

run_update() {
  user=$(state_value UTORID 2>/dev/null || true)
  host=$(state_value UTM_HOST 2>/dev/null || true)
  key=$(state_value KEY_PATH 2>/dev/null || true)

  if [ -z "$user" ] || [ -z "$host" ]; then
    printf 'Run setup again.\n' >&2
    return 2
  fi

  tmp=$(mktemp)
  if ! fetch_url "$REPO_RAW/setup.sh" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  if [ -n "$key" ]; then
    sh "$tmp" --user "$user" --host "$host" --key "$key"
  else
    sh "$tmp" --user "$user" --host "$host"
  fi
  rc=$?
  rm -f "$tmp"
  return "$rc"
}

case "${1:-}" in
  -h|--help|help)
    usage; exit 0
    ;;
  status)
    show_status; exit $?
    ;;
  vpn|--vpn)
    vpn_open; exit $?
    ;;
  guide)
    open_url "$VPN_GUIDE" || true
    exit 0
    ;;
  host)
    set_host "${2:-}"
    exit $?
    ;;
  files)
    show_files
    exit 0
    ;;
  doctor)
    run_doctor
    exit $?
    ;;
  update|repair)
    run_update
    exit $?
    ;;
  raw|--raw)
    exec ssh "$SSH_ALIAS"
    ;;
  --probe)
    probe_network
    [ "$PROBE_RESULT" = 'reachable' ] && exit 0
    [ "$PROBE_RESULT" = 'network' ] && exit 2
    exit 1
    ;;
  --ensure-network)
    ensure_network
    exit $?
    ;;
  '')
    ;;
  *)
    printf 'Unknown command. Try `utm help`.\n' >&2
    exit 2
    ;;
esac

if [ "$(state_value SETUP_COMPLETE 2>/dev/null || true)" != "1" ]; then
  printf '%sFinishing setup...%s\n' "$BLUE" "$RESET"
  run_update
  exit $?
fi

ensure_network || {
  printf '%sType `utm` again whenever the VPN/network is ready.%s\n' "$YELLOW" "$RESET"
  exit 2
}

exec ssh "$SSH_ALIAS"
