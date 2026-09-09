[CmdletBinding()]
param([string]$Alias = 'utm', [switch]$Help)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

if ($Help) {
    Write-Host 'Usage: doctor.ps1 [-Alias utm]'
    exit 0
}

$failed = $false
function Pass([string]$m) { Write-Host "✓ $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "! $m" -ForegroundColor Yellow }
function Fail([string]$m) { Write-Host "✗ $m" -ForegroundColor Red; $script:failed = $true }

Write-Host "`nutm-shell doctor — Windows`n" -ForegroundColor Blue

$ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
$scp = Get-Command scp.exe -ErrorAction SilentlyContinue
$keygen = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
$utm = Get-Command utm -ErrorAction SilentlyContinue
if ($ssh) { Pass "OpenSSH client: $($ssh.Source)" } else { Fail 'ssh.exe not found' }
if ($scp) { Pass "SCP client: $($scp.Source)" } else { Warn 'scp.exe not found' }
if ($keygen) { Pass "ssh-keygen: $($keygen.Source)" } else { Warn 'ssh-keygen.exe not found' }
if ($utm) { Pass "utm command: $($utm.Source)" } else { Warn 'utm command is not on PATH in this shell; open a new terminal or rerun setup' }

$config = Join-Path (Join-Path $HOME '.ssh') 'config'
if (Test-Path $config) {
    $text = Get-Content -Raw $config
    if ($text -match '# >>> utm-shell >>>') { Pass 'utm-shell managed SSH config is present' }
    else { Warn 'SSH config exists, but no utm-shell managed block was found' }
} else { Fail "SSH config not found at $config" }

if ($ssh) {
    $cfg = & $ssh.Source -G $Alias 2>$null
    if ($LASTEXITCODE -eq 0) {
        $hostName = (($cfg | Where-Object { $_ -match '^hostname\s+' } | Select-Object -First 1) -replace '^hostname\s+','').Trim()
        $userName = (($cfg | Where-Object { $_ -match '^user\s+' } | Select-Object -First 1) -replace '^user\s+','').Trim()
        Pass "SSH alias '$Alias' resolves to $userName@$hostName"
    } else { Fail "SSH alias '$Alias' is invalid" }

    $output = & $ssh.Source -o BatchMode=yes -o ConnectTimeout=6 -o ConnectionAttempts=1 $Alias true 2>&1
    $code = $LASTEXITCODE
    $message = ($output | Out-String)

    if ($code -eq 0) {
        Pass 'UTM network is reachable'
        Pass 'Passwordless public-key authentication works'
        $remote = & $ssh.Source -o ConnectTimeout=6 $Alias 'printf "shell=%s term=%s\n" "$SHELL" "${TERM:-unset}"; command -v bash; command -v scp' 2>$null
        if ($LASTEXITCODE -eq 0) { $remote | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray } }
    } elseif ($message -match 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused') {
        Warn 'UTM network is not reachable from this connection.'
        Warn 'If you are off campus, this is expected: run `utm vpn`, connect UTORvpn, then retry.'
    } elseif ($message -match 'Permission denied') {
        Pass 'UTM network is reachable'
        Warn 'Public-key authentication is not working for this account/key.'
        Warn 'Run `utm update` to repair key setup. If a known-correct password is also rejected, contact course staff about UTORid provisioning.'
    } elseif ($message -match 'REMOTE HOST IDENTIFICATION HAS CHANGED|Host key verification failed') {
        Pass 'UTM network is reachable'
        Warn 'SSH host-key verification needs attention. Do not bypass it blindly; verify the host/key change first.'
    } else {
        Warn 'SSH returned an unclassified error:'
        Write-Host $message.Trim() -ForegroundColor DarkGray
    }
}

if ($failed) { Write-Host "`nOne or more required local checks failed." -ForegroundColor Red; exit 1 }
Write-Host "`nDiagnostics complete." -ForegroundColor Green
