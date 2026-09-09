[CmdletBinding()]
param([string]$Alias = 'utm', [switch]$Help)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

if ($Help) {
    Write-Host 'Usage: .\doctor.ps1 [-Alias utm]'
    exit 0
}

$failed = $false
function Pass([string]$m) { Write-Host "✓ $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "! $m" -ForegroundColor Yellow }
function Fail([string]$m) { Write-Host "✗ $m" -ForegroundColor Red; $script:failed = $true }

Write-Host "`nutm-shell doctor — Windows`n" -ForegroundColor Blue

$ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
$scp = Get-Command scp.exe -ErrorAction SilentlyContinue
$sshKeygen = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
if ($ssh) { Pass "OpenSSH client: $($ssh.Source)" } else { Fail 'ssh.exe not found' }
if ($scp) { Pass "SCP client: $($scp.Source)" } else { Warn 'scp.exe not found' }
if ($sshKeygen) { Pass "ssh-keygen: $($sshKeygen.Source)" } else { Warn 'ssh-keygen.exe not found' }

$config = Join-Path (Join-Path $HOME '.ssh') 'config'
if (Test-Path $config) {
    $text = Get-Content -Raw $config
    if ($text -match '# >>> utm-shell >>>') { Pass 'utm-shell managed SSH config is present' }
    else { Warn 'SSH config exists, but no utm-shell managed block was found' }
} else { Fail "SSH config not found at $config" }

if ($ssh) {
    & $ssh.Source -G $Alias *> $null
    if ($LASTEXITCODE -eq 0) { Pass "SSH alias '$Alias' resolves" } else { Fail "SSH alias '$Alias' is invalid" }

    & $ssh.Source -o BatchMode=yes -o ConnectTimeout=8 $Alias true *> $null
    if ($LASTEXITCODE -eq 0) {
        Pass 'Passwordless public-key authentication works'
        $remote = & $ssh.Source -o ConnectTimeout=8 $Alias 'printf "shell=%s term=%s\n" "$SHELL" "${TERM:-unset}"; command -v bash; command -v scp' 2>$null
        if ($LASTEXITCODE -eq 0) {
            Pass 'Remote shell is reachable'
            $remote | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        } else { Warn 'Connected, but remote diagnostic command failed' }
    } else {
        Warn 'Key-only authentication failed or UTM is unreachable. Connect to campus Wi-Fi/UTORvpn and try ssh utm.'
    }
}

if ($failed) { Write-Host "`nOne or more required checks failed." -ForegroundColor Red; exit 1 }
Write-Host "`nCore checks passed." -ForegroundColor Green
