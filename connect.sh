#!/bin/sh
set -u

VERSION='1.7.1'
REPO_RAW='https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
VPN_GUIDE='https://security.utoronto.ca/services/vpn/usage-guide/'
VPN_DOWNLOAD='https://uoft.me/cisco-vpn-download'
VPN_SERVER='general.vpn.utoronto.ca'
STATE_DIR="$HOME/.config/utm-shell"
STATE_FILE="$STATE_DIR/config"
SSH_ALIAS='utm'
AUTO_INSTALL_TRIED=0
MAC_DOWNLOAD_OPENED=0

if [ -r "$STATE_DIR/alias" ]; then IFS= read -r SSH_ALIAS <"$STATE_DIR/alias" || true; fi
[ -n "$SSH_ALIAS" ] || SSH_ALIAS='utm'

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  ESC=$(printf '\033'); BLUE="${ESC}[1;34m"; GREEN="${ESC}[1;32m"; YELLOW="${ESC}[1;33m"; DIM="${ESC}[2m"; RESET="${ESC}[0m"
else
  BLUE=''; GREEN=''; YELLOW=''; DIM=''; RESET=''
fi

usage() {
  cat <<'EOF_HELP'
utm — UTM lab access

  utm                 connect
  utm status          check connection
  utm vpn             connect/setup UTORvpn
  utm host [HOST]     show/change lab computer
  utm files           file-copy examples
  utm doctor          diagnose problems
  utm update          update/repair
  utm help            help
EOF_HELP
}

state_value() {
  _key=$1
  [ -r "$STATE_FILE" ] || return 1
  awk -F= -v key="$_key" '$1==key {v=substr($0,index($0,"=")+1); gsub(/^\047|\047$/, "", v); print v; exit}' "$STATE_FILE"
}

current_host() { ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="hostname" {print $2; exit}'; }
current_user() { ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1=="user" {print $2; exit}'; }

fetch_url() {
  _url=$1
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$_url"
  elif command -v wget >/dev/null 2>&1; then wget -qO- "$_url"
  elif command -v fetch >/dev/null 2>&1; then fetch -q -o - "$_url"
  elif command -v ftp >/dev/null 2>&1; then ftp -V -o - "$_url"
  else printf 'Need curl, wget, fetch, or ftp.\n' >&2; return 1
  fi
}

uname_s=$(uname -s 2>/dev/null || printf 'Unknown')
uname_m=$(uname -m 2>/dev/null || printf 'unknown')
is_wsl() { [ -n "${WSL_DISTRO_NAME:-}" ] || { [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; }; }
platform_kind() {
  case "$uname_s" in
    Darwin) printf 'macos\n' ;;
    Linux) if is_wsl; then printf 'wsl\n'; else printf 'linux\n'; fi ;;
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
  if is_wsl 2>/dev/null && command -v cmd.exe >/dev/null 2>&1; then cmd.exe /c start "" "$_url" >/dev/null 2>&1
  elif [ "$uname_s" = Darwin ] && command -v open >/dev/null 2>&1; then open "$_url" >/dev/null 2>&1
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$_url" >/dev/null 2>&1 &
  elif command -v cmd.exe >/dev/null 2>&1; then cmd.exe /c start "" "$_url" >/dev/null 2>&1
  else printf '%s\n' "$_url"; return 1
  fi
}
open_vpn_download() { open_url "$VPN_DOWNLOAD" || open_url "$VPN_GUIDE" || true; }

windows_vpn_path() {
  command -v powershell.exe >/dev/null 2>&1 || return 1
  powershell.exe -NoProfile -Command '$p=@("$env:ProgramFiles\Cisco\Cisco Secure Client\vpnui.exe","$env:ProgramFiles\Cisco\Cisco Secure Client\UI\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\vpnui.exe","${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\UI\vpnui.exe")|Where-Object{Test-Path $_}|Select-Object -First 1;if($p){$p}else{exit 1}' 2>/dev/null | tr -d '\r'
}

vpn_client_available() {
  case "$(platform_kind)" in
    macos) open -Ra 'Cisco Secure Client' >/dev/null 2>&1 || open -Ra 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1 ;;
    wsl|windows-unix) windows_vpn_path >/dev/null 2>&1 ;;
    linux) [ -x /opt/cisco/secureclient/bin/vpnui ] || [ -x /opt/cisco/anyconnect/bin/vpnui ] || command -v vpnui >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

launch_vpn_client() {
  case "$(platform_kind)" in
    macos)
      if open -Ra 'Cisco Secure Client' >/dev/null 2>&1; then open -a 'Cisco Secure Client' >/dev/null 2>&1; return 0; fi
      if open -Ra 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1; then open -a 'Cisco AnyConnect Secure Mobility Client' >/dev/null 2>&1; return 0; fi
      ;;
    wsl|windows-unix)
      _p=$(windows_vpn_path 2>/dev/null || true); [ -n "$_p" ] || return 1
      powershell.exe -NoProfile -Command "Start-Process -FilePath '$_p'" >/dev/null 2>&1; return $?
      ;;
    linux)
      for _p in /opt/cisco/secureclient/bin/vpnui /opt/cisco/anyconnect/bin/vpnui; do [ ! -x "$_p" ] || { "$_p" >/dev/null 2>&1 & return 0; }; done
      command -v vpnui >/dev/null 2>&1 && { vpnui >/dev/null 2>&1 & return 0; }
      ;;
  esac
  return 1
}

probe_network() {
  PROBE_OUTPUT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 "$SSH_ALIAS" true 2>&1); _rc=$?
  if [ "$_rc" -eq 0 ]; then PROBE_RESULT=reachable
  elif printf '%s\n' "$PROBE_OUTPUT" | grep -Eqi 'Permission denied|Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED|authenticity of host'; then PROBE_RESULT=reachable
  elif printf '%s\n' "$PROBE_OUTPUT" | grep -Eqi 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused'; then PROBE_RESULT=network
  else PROBE_RESULT=unknown
  fi
}

print_connect_steps() {
  printf '\n%sUTORvpn%s\n' "$BLUE" "$RESET"
  printf '  1. Connect to %s%s%s.\n' "$BLUE" "$VPN_SERVER" "$RESET"
  printf '  2. Sign in with your UTORid and password.\n\n'
}

find_linux_package() {
  _kind=$1
  for _d in "$HOME/Downloads" "$HOME/downloads"; do
    [ -d "$_d" ] || continue
    if [ "$_kind" = deb ]; then
      _p=$(find "$_d" -type f -name 'cisco-secure-client-vpn_[0-9]*_amd64.deb' -print 2>/dev/null | head -n 1)
    else
      _p=$(find "$_d" -type f -name 'cisco-secure-client-vpn-[0-9]*.rpm' -print 2>/dev/null | grep -v 'vpn-cli' | head -n 1)
    fi
    [ -z "$_p" ] || { printf '%s\n' "$_p"; return 0; }
  done
  return 1
}

find_linux_archive() {
  _kind=$1
  for _d in "$HOME/Downloads" "$HOME/downloads"; do
    [ -d "$_d" ] || continue
    if [ "$_kind" = deb ]; then _pat='cisco-secure-client-linux64-*-predeploy-deb-k9.tgz'; else _pat='cisco-secure-client-linux64-*-predeploy-rpm-k9.tgz'; fi
    _p=$(find "$_d" -maxdepth 1 -type f -name "$_pat" -print 2>/dev/null | head -n 1)
    [ -z "$_p" ] || { printf '%s\n' "$_p"; return 0; }
  done
  return 1
}

install_linux_download_if_ready() {
  [ "$(platform_kind)" = linux ] || return 1
  case "$uname_m" in x86_64|amd64) ;; *) return 1 ;; esac
  [ "$AUTO_INSTALL_TRIED" -eq 0 ] || return 1

  _kind=''
  if command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then _kind=deb
  elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then _kind=rpm
  else return 1
  fi

  _pkg=$(find_linux_package "$_kind" 2>/dev/null || true)
  _work=''
  if [ -z "$_pkg" ]; then
    _archive=$(find_linux_archive "$_kind" 2>/dev/null || true)
    [ -n "$_archive" ] || return 1
    command -v tar >/dev/null 2>&1 || return 1
    _work=$(mktemp -d "${TMPDIR:-/tmp}/utm-shell-vpn.XXXXXX") || return 1
    chmod 755 "$_work" 2>/dev/null || true
    printf '\r%s✓ Cisco download found.%s Extracting...                 \n' "$GREEN" "$RESET"
    tar -xzf "$_archive" -C "$_work" >/dev/null 2>&1 || { rm -rf "$_work"; AUTO_INSTALL_TRIED=1; return 1; }
    if [ "$_kind" = deb ]; then _pkg=$(find "$_work" -type f -name 'cisco-secure-client-vpn_[0-9]*_amd64.deb' -print 2>/dev/null | head -n 1)
    else _pkg=$(find "$_work" -type f -name 'cisco-secure-client-vpn-[0-9]*.rpm' -print 2>/dev/null | grep -v 'vpn-cli' | head -n 1)
    fi
  fi

  [ -n "$_pkg" ] || { [ -z "$_work" ] || rm -rf "$_work"; return 1; }
  AUTO_INSTALL_TRIED=1
  _stage=$(mktemp -d "${TMPDIR:-/tmp}/utm-shell-vpn-pkg.XXXXXX") || return 1
  chmod 755 "$_stage" 2>/dev/null || true
  _ext=${_pkg##*.}; cp "$_pkg" "$_stage/vpn.$_ext" || { rm -rf "$_stage" "${_work:-}"; return 1; }
  chmod 644 "$_stage/vpn.$_ext" 2>/dev/null || true

  printf '%sInstalling Cisco Secure Client automatically.%s\n' "$BLUE" "$RESET"
  printf '%sYour computer may ask for its administrator password once.%s\n' "$DIM" "$RESET"
  _ok=1
  if [ "$_kind" = deb ]; then
    if command -v apt >/dev/null 2>&1; then sudo apt install -y "$_stage/vpn.deb" || _ok=0
    else sudo apt-get install -y "$_stage/vpn.deb" || _ok=0
    fi
  elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y "$_stage/vpn.rpm" || _ok=0
  else sudo yum install -y "$_stage/vpn.rpm" || _ok=0
  fi
  rm -rf "$_stage"; [ -z "$_work" ] || rm -rf "$_work"
  [ "$_ok" -eq 1 ] && vpn_client_available
}

maybe_open_macos_download() {
  [ "$(platform_kind)" = macos ] || return 1
  [ "$MAC_DOWNLOAD_OPENED" -eq 0 ] || return 1
  for _f in "$HOME"/Downloads/cisco-secure-client-macos-*.dmg; do
    [ -f "$_f" ] || continue
    MAC_DOWNLOAD_OPENED=1
    printf '\r%s✓ Cisco download found.%s Opening installer...          \n' "$GREEN" "$RESET"
    open "$_f" >/dev/null 2>&1 || true
    return 0
  done
  return 1
}

print_install_steps() {
  printf '\n%sUTORvpn setup%s\n' "$BLUE" "$RESET"
  case "$(platform_kind)" in
    linux)
      if command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then
        printf '  1. In the page that opened, click %sLinux (DEB)%s.\n' "$BLUE" "$RESET"
        printf '  2. Leave this terminal open. %sutm-shell will extract and install it for you.%s\n' "$GREEN" "$RESET"
        printf '  3. Approve the administrator-password prompt when it appears.\n\n'
      elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        printf '  1. In the page that opened, click %sLinux (RPM)%s.\n' "$BLUE" "$RESET"
        printf '  2. Leave this terminal open. %sutm-shell will extract and install it for you.%s\n' "$GREEN" "$RESET"
        printf '  3. Approve the administrator-password prompt when it appears.\n\n'
      else
        printf '  1. Use the U of T VPN page that opened for your Linux environment.\n'
        printf '  2. Leave this terminal open; setup continues when UTM becomes reachable.\n\n'
      fi
      ;;
    macos)
      printf '  1. Download the %smacOS%s client. utm-shell will open the .dmg when it appears.\n' "$BLUE" "$RESET"
      printf '  2. Run the .pkg and install only the %sVPN%s module.\n' "$BLUE" "$RESET"
      printf '  3. Leave this terminal open.\n\n'
      ;;
    wsl|windows-unix)
      printf '  1. Download the %sWindows%s client.\n' "$BLUE" "$RESET"
      printf '  2. Install the VPN component in Windows, then return here.\n\n'
      ;;
    freebsd|openbsd|netbsd|dragonflybsd)
      printf '  U of T does not publish a native Cisco client for this BSD platform.\n'
      printf '  Use campus networking or another U of T-supported VPN environment.\n\n'
      ;;
    *)
      printf '  Follow the official U of T VPN page that opened, then leave this terminal open.\n\n'
      ;;
  esac
}

wait_for_network() {
  _label=$1; _limit=$2; _i=0; printf '%s... ' "$_label"
  while [ "$_i" -lt "$_limit" ]; do
    probe_network
    if [ "$PROBE_RESULT" != network ]; then printf '\r%s✓ UTM network ready%s                         \n' "$GREEN" "$RESET"; return 0; fi
    case $((_i % 4)) in 0) _char='|' ;; 1) _char='/' ;; 2) _char='-' ;; *) _char='\\' ;; esac
    printf '\r%s... %s' "$_label" "$_char"; sleep 2; _i=$((_i + 1))
  done
  printf '\r%sStill offline.%s                              \n' "$YELLOW" "$RESET"; return 2
}
wait_for_vpn() { wait_for_network 'Waiting for UTORvpn' 150; }

wait_for_vpn_client() {
  _i=0; printf 'Waiting for Cisco Secure Client... '
  while [ "$_i" -lt 900 ]; do
    if vpn_client_available; then
      printf '\r%s✓ Cisco Secure Client ready%s                  \n' "$GREEN" "$RESET"
      launch_vpn_client || return 2; print_connect_steps; wait_for_vpn; return $?
    fi
    install_linux_download_if_ready || true
    maybe_open_macos_download || true
    if vpn_client_available; then continue; fi
    case $((_i % 4)) in 0) _char='|' ;; 1) _char='/' ;; 2) _char='-' ;; *) _char='\\' ;; esac
    printf '\rWaiting for Cisco Secure Client... %s' "$_char"; sleep 2; _i=$((_i + 1))
  done
  printf '\r%sStill waiting for Cisco Secure Client.%s       \n' "$YELLOW" "$RESET"; return 2
}

vpn_flow() {
  probe_network
  [ "$PROBE_RESULT" = network ] || { printf '%s✓ UTM is already reachable.%s\n' "$GREEN" "$RESET"; return 0; }
  if launch_vpn_client; then print_connect_steps; wait_for_vpn; return $?; fi
  if install_linux_download_if_ready; then
    launch_vpn_client || true; print_connect_steps; wait_for_vpn; return $?
  fi
  open_vpn_download
  print_install_steps
  case "$(platform_kind)" in
    linux|macos|wsl|windows-unix) wait_for_vpn_client ;;
    *) wait_for_network 'Waiting for UTM network' 900 ;;
  esac
}

show_status() {
  _host=$(current_host); _user=$(current_user); probe_network; printf '%s@%s — ' "${_user:-?}" "${_host:-?}"
  case "$PROBE_RESULT" in reachable) printf '%sready%s\n' "$GREEN" "$RESET" ;; network) printf '%sUTORvpn needed%s\n' "$YELLOW" "$RESET" ;; *) printf '%scheck failed%s\n' "$YELLOW" "$RESET"; [ -z "$PROBE_OUTPUT" ] || printf '%s%s%s\n' "$DIM" "$PROBE_OUTPUT" "$RESET" ;; esac
}

set_host() {
  _new=${1:-}; [ -n "$_new" ] || { current_host; return 0; }
  case "$_new" in *[!A-Za-z0-9.-]*) printf 'Invalid host.\n' >&2; return 2 ;; esac
  case "$_new" in *.*) ;; *) _new="${_new}.utm.utoronto.ca" ;; esac
  _config="$HOME/.ssh/config"; [ -f "$_config" ] || { printf 'Run setup again.\n' >&2; return 2; }
  _tmp=$(mktemp)
  awk -v start='# >>> utm-shell >>>' -v end='# <<< utm-shell <<<' -v host="$_new" '$0==start{inside=1;print;next}$0==end{inside=0;print;next}inside&&$1=="HostName"{print "    HostName " host;next}{print}' "$_config" >"$_tmp" && cat "$_tmp" >"$_config"; rm -f "$_tmp"
  printf '%s%s%s\n' "$GREEN" "$_new" "$RESET"
}

show_files() { printf 'scp FILE %s:~/             # computer -> UTM\nscp %s:~/FILE .             # UTM -> computer\nscp -r FOLDER %s:~/         # folder -> UTM\n' "$SSH_ALIAS" "$SSH_ALIAS" "$SSH_ALIAS"; }

run_doctor() { _tmp=$(mktemp); fetch_url "$REPO_RAW/doctor.sh" >"$_tmp" || { rm -f "$_tmp"; return 1; }; sh "$_tmp" "$SSH_ALIAS"; _rc=$?; rm -f "$_tmp"; return "$_rc"; }
run_update() {
  _user=$(state_value UTORID 2>/dev/null || true); _host=$(state_value UTM_HOST 2>/dev/null || true); _key=$(state_value KEY_PATH 2>/dev/null || true)
  [ -n "$_user" ] && [ -n "$_host" ] || { printf 'Run setup again.\n' >&2; return 2; }
  _tmp=$(mktemp); fetch_url "$REPO_RAW/setup.sh" >"$_tmp" || { rm -f "$_tmp"; return 1; }
  if [ -n "$_key" ]; then sh "$_tmp" --user "$_user" --host "$_host" --key "$_key"; else sh "$_tmp" --user "$_user" --host "$_host"; fi
  _rc=$?; rm -f "$_tmp"; return "$_rc"
}

case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
  status) show_status; exit $? ;;
  vpn|--vpn) vpn_flow; exit $? ;;
  guide) open_url "$VPN_GUIDE" || true; exit 0 ;;
  host) set_host "${2:-}"; exit $? ;;
  files) show_files; exit 0 ;;
  doctor) run_doctor; exit $? ;;
  update|repair) run_update; exit $? ;;
  raw|--raw) exec ssh "$SSH_ALIAS" ;;
  --probe) probe_network; [ "$PROBE_RESULT" = reachable ] && exit 0; [ "$PROBE_RESULT" = network ] && exit 2; exit 1 ;;
  --ensure-network) vpn_flow; exit $? ;;
  '') ;;
  *) printf 'Unknown command. Try `utm help`.\n' >&2; exit 2 ;;
esac

if [ "$(state_value SETUP_COMPLETE 2>/dev/null || true)" != 1 ]; then
  printf '%sFinishing setup...%s\n' "$BLUE" "$RESET"; run_update; exit $?
fi

vpn_flow || { printf '%sType `utm` again whenever the VPN/network is ready.%s\n' "$YELLOW" "$RESET"; exit 2; }
exec ssh "$SSH_ALIAS"
