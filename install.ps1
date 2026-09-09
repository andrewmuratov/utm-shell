[CmdletBinding()]
param(
    [string]$User,
    [Alias('Host')][string]$HostName,
    [string]$Alias = 'utm',
    [string]$KeyPath,
    [switch]$SkipKeyCopy,
    [switch]$NoHushLogin,
    [switch]$Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Version = '1.1.0'
$SshStart = '# >>> utm-shell >>>'
$SshEnd = '# <<< utm-shell <<<'

function Write-Info([string]$Message) { Write-Host "• $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Warning $Message }
function Fail([string]$Message)       { throw "utm-shell: $Message" }

function Show-Usage {
@'
utm-shell — native Windows setup for UTM lab SSH

Usage:
  .\install.ps1 [-User UTORID] [-HostName HOST] [options]

Options:
  -User UTORID        UTORid used to log in
  -HostName HOST      Lab hostname, e.g. dh2026pc08 or full hostname
  -Alias NAME         Local SSH alias (default: utm)
  -KeyPath PATH       SSH private key to use
  -SkipKeyCopy        Do not install the public key on the UTM account
  -NoHushLogin        Keep the Ubuntu login banner
  -Help               Show this help
'@ | Write-Host
}

if ($Help) { Show-Usage; exit 0 }

Write-Host "`nutm-shell $Version" -ForegroundColor Blue
Write-Host "Native Windows / PowerShell installer.`n" -ForegroundColor DarkGray

$ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
$sshKeygen = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
if (-not $ssh -or -not $sshKeygen) {
    Fail @'
OpenSSH Client is required. On Windows 10/11 install it from:
Settings → System → Optional features → View features → OpenSSH Client

Or from an elevated PowerShell:
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
'@
}

if ([string]::IsNullOrWhiteSpace($User)) { $User = Read-Host 'UTORid' }
if ([string]::IsNullOrWhiteSpace($HostName)) { $HostName = Read-Host 'UTM lab host (for example dh2026pc08)' }

if ($User -notmatch '^[A-Za-z0-9._-]+$') { Fail 'UTORid contains unsupported characters.' }
if ($Alias -notmatch '^[A-Za-z0-9._-]+$') { Fail 'SSH alias contains unsupported characters.' }
if ($HostName -notmatch '^[A-Za-z0-9.-]+$') { Fail 'Hostname contains unsupported characters.' }
if ($HostName -notmatch '\.') { $HostName = "$HostName.utm.utoronto.ca" }

$SshDir = Join-Path $HOME '.ssh'
$SshConfig = Join-Path $SshDir 'config'
$StateDir = Join-Path (Join-Path $HOME '.config') 'utm-shell'
$StateFile = Join-Path $StateDir 'config.json'
New-Item -ItemType Directory -Force -Path $SshDir, $StateDir | Out-Null

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    $existing = Join-Path $SshDir 'id_ed25519'
    $dedicated = Join-Path $SshDir 'id_ed25519_utm'
    if ((Test-Path $existing) -and (Test-Path "$existing.pub")) {
        $answer = Read-Host 'Use your existing Ed25519 key at ~/.ssh/id_ed25519? [Y/n]'
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^[Yy]') { $KeyPath = $existing }
        else { $KeyPath = $dedicated }
    } else {
        $KeyPath = $dedicated
    }
}

$KeyPath = [Environment]::ExpandEnvironmentVariables($KeyPath)
if ($KeyPath.StartsWith('~')) { $KeyPath = Join-Path $HOME $KeyPath.Substring(1).TrimStart('/','\') }
$KeyPath = [IO.Path]::GetFullPath($KeyPath)
$KeyCreated = $false

if (-not (Test-Path $KeyPath)) {
    Write-Info "Creating Ed25519 SSH key at $KeyPath"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $KeyPath) | Out-Null
    & $sshKeygen.Source -t ed25519 -a 100 -f $KeyPath -C "utm-shell:$User@$HostName"
    if ($LASTEXITCODE -ne 0) { Fail 'ssh-keygen failed.' }
    $KeyCreated = $true
}

if (-not (Test-Path "$KeyPath.pub")) {
    Write-Info 'Rebuilding missing public key.'
    $pub = & $sshKeygen.Source -y -f $KeyPath
    if ($LASTEXITCODE -ne 0) { Fail 'Could not derive the public key.' }
    [IO.File]::WriteAllText("$KeyPath.pub", (($pub -join "`n").Trim() + "`n"), [Text.UTF8Encoding]::new($false))
}

$identityForConfig = $KeyPath.Replace('\','/')
$managedBlock = @"
$SshStart
Host $Alias
    HostName $HostName
    User $User
    IdentityFile "$identityForConfig"
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
$SshEnd
"@

$current = if (Test-Path $SshConfig) { [IO.File]::ReadAllText($SshConfig) } else { '' }
$pattern = '(?ms)^# >>> utm-shell >>>\r?\n.*?^# <<< utm-shell <<<\r?\n?'
$current = [regex]::Replace($current, $pattern, '').TrimEnd()
$newConfig = if ($current) { "$current`r`n`r`n$managedBlock`r`n" } else { "$managedBlock`r`n" }
[IO.File]::WriteAllText($SshConfig, $newConfig, [Text.UTF8Encoding]::new($false))
Write-Ok "Configured ssh $Alias → $User@$HostName"

& $ssh.Source -G $Alias *> $null
if ($LASTEXITCODE -ne 0) { Fail 'OpenSSH rejected the generated SSH configuration.' }

function Test-KeyAuth {
    & $ssh.Source -o BatchMode=yes -o ConnectTimeout=8 $Alias true *> $null
    return ($LASTEXITCODE -eq 0)
}

if (-not $SkipKeyCopy) {
    if (Test-KeyAuth) {
        Write-Ok 'SSH key authentication already works.'
    } else {
        Write-Info 'Installing your public key on UTM. Your UTORid password may be requested once.'
        Write-Info 'You must be on the U of T network or connected through UTORvpn.'
        $pubText = ([IO.File]::ReadAllText("$KeyPath.pub")).Trim()
        $pubB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pubText))
        $remote = 'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; pub=$(printf ''%s'' ''{0}'' | base64 -d); grep -qxF "$pub" ~/.ssh/authorized_keys || printf ''%s\n'' "$pub" >> ~/.ssh/authorized_keys' -f $pubB64
        & $ssh.Source $Alias $remote
        if ($LASTEXITCODE -ne 0) { Fail 'Could not install the SSH key. Check UTORvpn/campus network, hostname, and password.' }
        if (-not (Test-KeyAuth)) { Fail 'The public key was copied, but key-only authentication still failed.' }
        Write-Ok 'Passwordless SSH is working.'
    }
} else {
    Write-Warn 'Skipped SSH key installation.'
}

$useHush = if ($NoHushLogin) { '0' } else { '1' }
$remoteSetup = @'
set -Eeuo pipefail
USE_HUSHLOGIN="${1:-1}"
BASHRC="$HOME/.bashrc"
START="# >>> utm-shell >>>"
END="# <<< utm-shell <<<"
LOGIN_START="# >>> utm-shell login >>>"
LOGIN_END="# <<< utm-shell login <<<"
STATE_DIR="$HOME/.config/utm-shell"
STATE_FILE="$STATE_DIR/state"
mkdir -p "$STATE_DIR"
touch "$BASHRC"

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

remove_block "$BASHRC" "$START" "$END"
cat >> "$BASHRC" <<'BASHRC_EOF'

# >>> utm-shell >>>
if [[ $- == *i* ]]; then
  # Some modern terminal emulators advertise a TERM entry that the older UTM
  # image does not know. Fall back only when the remote terminfo database lacks it.
  if command -v infocmp >/dev/null 2>&1 && ! infocmp "${TERM:-}" >/dev/null 2>&1; then
    export TERM=xterm-256color
  fi

  HISTCONTROL=ignoreboth:erasedups
  HISTSIZE=10000
  HISTFILESIZE=20000
  shopt -s histappend checkwinsize cdspell globstar

  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
  alias diff='diff --color=auto'
  alias ll='ls -lah'
  alias la='ls -A'
  alias l='ls -CF'
  alias ..='cd ..'
  alias ...='cd ../..'
  alias ....='cd ../../..'
  alias home='cd ~'
  alias c='clear'
  alias cls='clear'
  alias reload='source ~/.bashrc'
  alias disk='df -h'
  alias usage='du -sh -- * 2>/dev/null | sort -h'
  alias py='python3'
  alias gs='git status'
  alias gd='git diff'
  alias gl='git log --oneline --graph --decorate -15'

  mkcd() { [[ $# -eq 1 ]] || { printf 'usage: mkcd <directory>\n' >&2; return 2; }; mkdir -p -- "$1" && cd -- "$1"; }
  ff() { [[ $# -ge 1 ]] || { printf 'usage: ff <name>\n' >&2; return 2; }; find . -iname "*$1*" 2>/dev/null; }
  path() { printf '%s\n' "$PATH" | tr ':' '\n'; }
  utm-help() {
    cat <<'HELP_EOF'
utm-shell commands

  ll / la       detailed / hidden-file listings
  .. / ...      move up one / two directories
  c / cls       clear the terminal
  reload        reload ~/.bashrc
  mkcd DIR      create a directory and enter it
  ff NAME       find files/directories by name below .
  disk          filesystem disk usage
  usage         sizes of items in the current directory
  path          print PATH one entry per line
  py            python3
  gs / gd / gl  compact Git shortcuts
  utm-help      show this help
HELP_EOF
  }

  if command -v bind >/dev/null 2>&1; then
    bind '"\e[A": history-search-backward' 2>/dev/null || true
    bind '"\e[B": history-search-forward' 2>/dev/null || true
  fi

  PS1='\[\e[1;34m\]UTM\[\e[0m\] \[\e[90m\]\u@\h\[\e[0m\] \[\e[1;37m\]\w\[\e[0m\]\n\[\e[1;34m\]❯\[\e[0m\] '
fi
# <<< utm-shell <<<
BASHRC_EOF

if [[ -f "$HOME/.bash_profile" ]]; then LOGIN_FILE="$HOME/.bash_profile"
elif [[ -f "$HOME/.bash_login" ]]; then LOGIN_FILE="$HOME/.bash_login"
else LOGIN_FILE="$HOME/.profile"; touch "$LOGIN_FILE"
fi

remove_block "$LOGIN_FILE" "$LOGIN_START" "$LOGIN_END"
LOGIN_MANAGED=0
if ! grep -Eq '(^|[[:space:]])(\.|source)[[:space:]].*\.bashrc' "$LOGIN_FILE" 2>/dev/null; then
  cat >> "$LOGIN_FILE" <<'LOGIN_EOF'

# >>> utm-shell login >>>
if [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi
# <<< utm-shell login <<<
LOGIN_EOF
  LOGIN_MANAGED=1
fi

HUSH_CREATED=0
if [[ "$USE_HUSHLOGIN" == "1" && ! -e "$HOME/.hushlogin" ]]; then touch "$HOME/.hushlogin"; HUSH_CREATED=1; fi
{
  printf 'VERSION=%q\n' '1.1.0'
  printf 'LOGIN_FILE=%q\n' "$LOGIN_FILE"
  printf 'LOGIN_MANAGED=%q\n' "$LOGIN_MANAGED"
  printf 'HUSH_CREATED=%q\n' "$HUSH_CREATED"
} > "$STATE_FILE"
chmod 600 "$STATE_FILE"
'@

$remoteSetup = $remoteSetup.Replace("`r`n", "`n")
$setupB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteSetup))
$setupCmd = "printf '%s' '$setupB64' | base64 -d | bash -s -- '$useHush'"
Write-Info 'Installing the remote Bash setup.'
& $ssh.Source $Alias $setupCmd
if ($LASTEXITCODE -ne 0) { Fail 'Remote shell setup failed.' }
Write-Ok 'Remote shell configured.'

$state = [ordered]@{
    version = $Version
    alias = $Alias
    user = $User
    host = $HostName
    keyPath = $KeyPath
    keyCreated = $KeyCreated
}
$state | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8

Write-Host "`nDone. Your UTM shell is ready.`n" -ForegroundColor Green
Write-Host "  ssh $Alias`n" -ForegroundColor Blue
Write-Host 'Inside UTM, run utm-help to see the added shortcuts.' -ForegroundColor DarkGray
