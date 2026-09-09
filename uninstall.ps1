[CmdletBinding()]
param(
    [switch]$LocalOnly,
    [switch]$KeepAuthKey,
    [switch]$Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$SshStart = '# >>> utm-shell >>>'
$SshEnd = '# <<< utm-shell <<<'
$SshDir = Join-Path $HOME '.ssh'
$SshConfig = Join-Path $SshDir 'config'
$StateDir = Join-Path (Join-Path $HOME '.config') 'utm-shell'
$StateFile = Join-Path $StateDir 'config.json'

if ($Help) {
@'
Usage: .\uninstall.ps1 [options]

Options:
  -LocalOnly       Remove only the local SSH configuration
  -KeepAuthKey     Leave the public key in ~/.ssh/authorized_keys on UTM
  -Help            Show this help
'@ | Write-Host
    exit 0
}

$Alias = 'utm'
$KeyPath = ''
$KeyCreated = $false
if (Test-Path $StateFile) {
    $state = Get-Content -Raw $StateFile | ConvertFrom-Json
    if ($state.alias) { $Alias = [string]$state.alias }
    if ($state.keyPath) { $KeyPath = [string]$state.keyPath }
    if ($null -ne $state.keyCreated) { $KeyCreated = [bool]$state.keyCreated }
} else {
    Write-Warning "State file not found; assuming SSH alias 'utm'."
}

$ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
if (-not $LocalOnly -and -not $ssh) {
    Write-Warning 'OpenSSH is unavailable, so the remote setup cannot be removed. Continuing with local cleanup.'
    $LocalOnly = $true
}

if (-not $LocalOnly) {
    $pubB64 = ''
    if (-not $KeepAuthKey -and $KeyPath -and (Test-Path "$KeyPath.pub")) {
        $pubText = ([IO.File]::ReadAllText("$KeyPath.pub")).Trim()
        $pubB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pubText))
    }

    $remoteScript = @'
set -Eeuo pipefail
PUB_B64="${1:-}"
START="# >>> utm-shell >>>"
END="# <<< utm-shell <<<"
LOGIN_START="# >>> utm-shell login >>>"
LOGIN_END="# <<< utm-shell login <<<"
STATE_FILE="$HOME/.config/utm-shell/state"
LOGIN_FILE=""
LOGIN_MANAGED=1
HUSH_CREATED=0

if [[ -f "$STATE_FILE" ]]; then source "$STATE_FILE"; fi
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
remove_block "$HOME/.bashrc" "$START" "$END"
if [[ "${LOGIN_MANAGED:-1}" == "1" ]]; then
  if [[ -n "${LOGIN_FILE:-}" ]]; then remove_block "$LOGIN_FILE" "$LOGIN_START" "$LOGIN_END"
  else
    remove_block "$HOME/.bash_profile" "$LOGIN_START" "$LOGIN_END"
    remove_block "$HOME/.bash_login" "$LOGIN_START" "$LOGIN_END"
    remove_block "$HOME/.profile" "$LOGIN_START" "$LOGIN_END"
  fi
fi
if [[ "${HUSH_CREATED:-0}" == "1" ]]; then rm -f "$HOME/.hushlogin"; fi
if [[ -n "$PUB_B64" && -f "$HOME/.ssh/authorized_keys" ]]; then
  pub="$(printf '%s' "$PUB_B64" | base64 -d)"
  tmp="$(mktemp)"
  grep -Fvx "$pub" "$HOME/.ssh/authorized_keys" > "$tmp" || true
  cat "$tmp" > "$HOME/.ssh/authorized_keys"
  rm -f "$tmp"
fi
rm -rf "$HOME/.config/utm-shell"
'@

    $remoteScript = $remoteScript.Replace("`r`n", "`n")
    $scriptB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
    $remoteCmd = "printf '%s' '$scriptB64' | base64 -d | bash -s -- '$pubB64'"
    Write-Host '• Removing remote shell setup.' -ForegroundColor Cyan
    & $ssh.Source $Alias $remoteCmd
    if ($LASTEXITCODE -eq 0) { Write-Host '✓ Remote setup removed.' -ForegroundColor Green }
    else { Write-Warning 'Could not reach UTM. Remote files were left unchanged.' }
}

if (Test-Path $SshConfig) {
    $current = [IO.File]::ReadAllText($SshConfig)
    $pattern = '(?ms)^# >>> utm-shell >>>\r?\n.*?^# <<< utm-shell <<<\r?\n?'
    $current = [regex]::Replace($current, $pattern, '').TrimEnd()
    if ($current) { $current += "`r`n" }
    [IO.File]::WriteAllText($SshConfig, $current, [Text.UTF8Encoding]::new($false))
}
Write-Host '✓ Local SSH config cleaned.' -ForegroundColor Green

Remove-Item -Force -ErrorAction SilentlyContinue $StateFile
if (Test-Path $StateDir) {
    try { Remove-Item $StateDir -ErrorAction Stop } catch { }
}

if ($KeyCreated -and $KeyPath -and (Test-Path $KeyPath)) {
    Write-Host "`nA dedicated private key created by utm-shell remains at:`n  $KeyPath"
    Write-Host 'It was intentionally not deleted. Remove it manually if you no longer need it.'
}

Write-Host "`nutm-shell has been uninstalled." -ForegroundColor Green
