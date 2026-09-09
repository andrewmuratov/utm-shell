[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$Command,
    [switch]$Probe,
    [switch]$EnsureNetwork
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$VpnGuide = 'https://security.utoronto.ca/services/vpn/usage-guide/'
$VpnServer = 'general.vpn.utoronto.ca'
$StateDir = Join-Path (Join-Path $HOME '.config') 'utm-shell'
$AliasFile = Join-Path $StateDir 'alias'
$SshAlias = 'utm'
if (Test-Path $AliasFile) {
    $candidate = ([IO.File]::ReadAllText($AliasFile)).Trim()
    if ($candidate) { $SshAlias = $candidate }
}

function Show-Usage {
@'
utm — smart UTM lab connection

Usage:
  utm          connect to the configured UTM lab computer
  utm vpn      open Cisco Secure Client, or the official UTORvpn setup guide
  utm raw      run normal `ssh utm` without the network pre-check
  utm help     show this help
'@ | Write-Host
}

function Open-VpnGuide {
    try { Start-Process $VpnGuide | Out-Null; return $true }
    catch { Write-Host "Official guide: $VpnGuide"; return $false }
}

function Open-VpnClient {
    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles 'Cisco\Cisco Secure Client\vpnui.exe')
        $candidates += (Join-Path $env:ProgramFiles 'Cisco\Cisco Secure Client\UI\vpnui.exe')
    }
    $pf86 = ${env:ProgramFiles(x86)}
    if ($pf86) {
        $candidates += (Join-Path $pf86 'Cisco\Cisco Secure Client\vpnui.exe')
        $candidates += (Join-Path $pf86 'Cisco\Cisco Secure Client\UI\vpnui.exe')
        $candidates += (Join-Path $pf86 'Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe')
    }

    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) {
            Start-Process $path | Out-Null
            return $true
        }
    }

    $cmd = Get-Command vpnui.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        Start-Process $cmd.Source | Out-Null
        return $true
    }
    return $false
}

function Open-UtorVpn {
    Write-Host "`nUTORvpn" -ForegroundColor Blue
    if (Open-VpnClient) {
        Write-Host 'Opened Cisco Secure Client.' -ForegroundColor Green
        Write-Host "Connect to: $VpnServer" -ForegroundColor Blue
        Write-Host 'Sign in with your UTORid and password.'
    } else {
        Write-Host 'Cisco Secure Client was not found on this computer.'
        Write-Host 'Opening the official U of T UTORvpn setup guide...'
        [void](Open-VpnGuide)
    }
}

function Get-NetworkState {
    $ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
    if (-not $ssh) { throw 'OpenSSH Client is not installed.' }

    $output = & $ssh.Source -o BatchMode=yes -o ConnectTimeout=6 -o ConnectionAttempts=1 $SshAlias true 2>&1
    $code = $LASTEXITCODE
    $text = ($output | Out-String)

    if ($code -eq 0) { return 'reachable' }
    if ($text -match 'Permission denied|Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED|authenticity of host') {
        return 'reachable'
    }
    if ($text -match 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused') {
        return 'network'
    }
    return 'unknown'
}

function Show-NetworkMessage {
    Write-Host "`nCan't reach the UTM lab computer." -ForegroundColor Yellow
    Write-Host @"

UTM lab machines are normally reachable only from the U of T network.
If you're at home, in a residence/off-campus network, or on public Wi-Fi,
connect to UTORvpn first, then try again.

UTORvpn uses Cisco Secure Client and the general VPN address is:
  $VpnServer
"@
}

function Wait-ForNetwork {
    while ($true) {
        $state = Get-NetworkState
        if ($state -eq 'reachable' -or $state -eq 'unknown') { return $true }

        Show-NetworkMessage
        Write-Host '  [1] Open Cisco Secure Client / UTORvpn setup'
        Write-Host '  [2] Open the official U of T VPN guide'
        Write-Host '  [r] Retry'
        Write-Host '  [q] Quit'
        $answer = Read-Host 'Choose'
        switch -Regex ($answer) {
            '^(1|)$' {
                Open-UtorVpn
                $again = Read-Host 'Connect to UTORvpn, then press Enter to retry (or q to quit)'
                if ($again -match '^[Qq]$') { return $false }
            }
            '^2$' {
                [void](Open-VpnGuide)
                $again = Read-Host 'Connect to UTORvpn, then press Enter to retry (or q to quit)'
                if ($again -match '^[Qq]$') { return $false }
            }
            '^[Rr]$' { }
            '^[Qq]$' { return $false }
            default { Write-Host 'Unknown choice.' }
        }
    }
}

if ($Probe) {
    $state = Get-NetworkState
    if ($state -eq 'reachable') { exit 0 }
    if ($state -eq 'network') { exit 2 }
    exit 1
}

if ($EnsureNetwork) {
    if (Wait-ForNetwork) { exit 0 }
    exit 2
}

switch ($Command) {
    'help' { Show-Usage; exit 0 }
    '--help' { Show-Usage; exit 0 }
    '-h' { Show-Usage; exit 0 }
    'vpn' { Open-UtorVpn; exit 0 }
    '--vpn' { Open-UtorVpn; exit 0 }
    'raw' {
        & ssh.exe $SshAlias
        exit $LASTEXITCODE
    }
    '--raw' {
        & ssh.exe $SshAlias
        exit $LASTEXITCODE
    }
    '' { }
    $null { }
    default {
        Write-Error "Unknown argument: $Command"
        Show-Usage
        exit 2
    }
}

if (-not (Wait-ForNetwork)) { exit 2 }
& ssh.exe $SshAlias
exit $LASTEXITCODE
