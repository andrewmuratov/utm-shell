[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$Command,
    [Parameter(Position=1)][string]$Value,
    [switch]$Probe,
    [switch]$EnsureNetwork
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Version = '1.4.0'
$RawBase = 'https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
$VpnGuide = 'https://security.utoronto.ca/services/vpn/usage-guide/'
$VpnServer = 'general.vpn.utoronto.ca'
$StateDir = Join-Path (Join-Path $HOME '.config') 'utm-shell'
$AliasFile = Join-Path $StateDir 'alias'
$StateFile = Join-Path $StateDir 'config.json'
$SshAlias = 'utm'
if (Test-Path $AliasFile) {
    $candidate = ([IO.File]::ReadAllText($AliasFile)).Trim()
    if ($candidate) { $SshAlias = $candidate }
}

function Show-Usage {
@'
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
'@ | Write-Host
}

function Get-SshValue([string]$Name) {
    $lines = & ssh.exe -G $SshAlias 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($Name))\s+(.+)$") { return $Matches[1].Trim() }
    }
    return ''
}

function Open-VpnGuide {
    try { Start-Process $VpnGuide | Out-Null; return $true }
    catch { Write-Host "Official guide: $VpnGuide"; return $false }
}

function Get-VpnClientPath {
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
        if ($path -and (Test-Path $path)) { return $path }
    }
    $cmd = Get-Command vpnui.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Open-UtorVpn {
    Write-Host "`nUTORvpn" -ForegroundColor Blue
    $client = Get-VpnClientPath
    if ($client) {
        Start-Process $client | Out-Null
        Write-Host 'Opened Cisco Secure Client.' -ForegroundColor Green
        Write-Host "Server: $VpnServer" -ForegroundColor Blue
        Write-Host 'Group:  UofT Default'
        Write-Host 'Sign in with your UTORid and password, then return here.'
    } else {
        Write-Host 'Cisco Secure Client is not installed yet.'
        Write-Host 'Opening the official U of T install/connect guide...'
        [void](Open-VpnGuide)
        Write-Host "`nAfter installing Cisco Secure Client, connect to:"
        Write-Host "  $VpnServer" -ForegroundColor Blue
    }
}

function Get-NetworkState {
    $output = & ssh.exe -o BatchMode=yes -o ConnectTimeout=6 -o ConnectionAttempts=1 $SshAlias true 2>&1
    $code = $LASTEXITCODE
    $text = ($output | Out-String)

    if ($code -eq 0) { return @{ State='reachable'; Output=$text } }
    if ($text -match 'Permission denied|Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED|authenticity of host') {
        return @{ State='reachable'; Output=$text }
    }
    if ($text -match 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused') {
        return @{ State='network'; Output=$text }
    }
    return @{ State='unknown'; Output=$text }
}

function Show-NetworkMessage {
    Write-Host "`nUTM is not reachable from this network." -ForegroundColor Yellow
    Write-Host @"

This is normal if you're at home, off campus, in residence on a non-U of T
network, or on public Wi-Fi. UTM lab computers normally require either:

  • the U of T campus network, or
  • UTORvpn

This usually is not a password problem.
UTORvpn server: $VpnServer
"@
}

function Wait-ForNetwork {
    while ($true) {
        $probe = Get-NetworkState
        if ($probe.State -eq 'reachable' -or $probe.State -eq 'unknown') { return $true }

        Show-NetworkMessage
        Write-Host 'Press Enter to open/setup UTORvpn, or choose:'
        Write-Host '  [g] official U of T VPN guide'
        Write-Host '  [r] retry'
        Write-Host '  [q] quit'
        $answer = Read-Host 'Choice [Enter]'
        switch -Regex ($answer) {
            '^$|^[Vv]$' {
                Open-UtorVpn
                $again = Read-Host 'Connect to UTORvpn, then press Enter to retry (q to quit)'
                if ($again -match '^[Qq]$') { return $false }
            }
            '^[Gg]$' {
                [void](Open-VpnGuide)
                $again = Read-Host 'Connect to UTORvpn, then press Enter to retry (q to quit)'
                if ($again -match '^[Qq]$') { return $false }
            }
            '^[Rr]$' { }
            '^[Qq]$' { return $false }
            default { Write-Host 'Unknown choice.' }
        }
    }
}

function Show-Status {
    $hostName = Get-SshValue 'hostname'
    $userName = Get-SshValue 'user'
    Write-Host "`nutm-shell $Version" -ForegroundColor Blue
    Write-Host "User: $userName"
    Write-Host "Host: $hostName"
    if (Get-VpnClientPath) { Write-Host 'Cisco Secure Client: installed' }
    else { Write-Host 'Cisco Secure Client: not detected' }
    Write-Host -NoNewline 'Checking UTM network... '
    $probe = Get-NetworkState
    switch ($probe.State) {
        'reachable' { Write-Host 'reachable' -ForegroundColor Green }
        'network' { Write-Host 'not reachable - use `utm vpn` off campus' -ForegroundColor Yellow }
        default {
            Write-Host 'uncertain' -ForegroundColor Yellow
            if ($probe.Output) { Write-Host $probe.Output.Trim() -ForegroundColor DarkGray }
        }
    }
}

function Set-LabHost([string]$NewHost) {
    if ([string]::IsNullOrWhiteSpace($NewHost)) {
        Write-Host (Get-SshValue 'hostname')
        return
    }
    if ($NewHost -notmatch '^[A-Za-z0-9.-]+$') { throw 'Invalid lab hostname.' }
    if ($NewHost -notmatch '\.') { $NewHost = "$NewHost.utm.utoronto.ca" }

    $config = Join-Path (Join-Path $HOME '.ssh') 'config'
    if (-not (Test-Path $config)) { throw 'SSH config not found. Run setup again.' }
    $text = [IO.File]::ReadAllText($config)
    $lines = $text -split "`r?`n"
    $inside = $false
    $updated = foreach ($line in $lines) {
        if ($line -eq '# >>> utm-shell >>>') { $inside = $true; $line; continue }
        if ($line -eq '# <<< utm-shell <<<') { $inside = $false; $line; continue }
        if ($inside -and $line -match '^\s*HostName\s+') { "    HostName $NewHost" } else { $line }
    }
    [IO.File]::WriteAllText($config, (($updated -join "`r`n").TrimEnd() + "`r`n"), [Text.UTF8Encoding]::new($false))

    if (Test-Path $StateFile) {
        try {
            $state = Get-Content $StateFile -Raw | ConvertFrom-Json
            $state.host = $NewHost
            $state | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8
        } catch { }
    }
    Write-Host "Switched UTM host to: $NewHost" -ForegroundColor Green
}

function Show-Files {
@"

Copy files from your own computer:

  computer -> UTM
    scp FILE ${SshAlias}:~/

  UTM -> computer
    scp ${SshAlias}:~/FILE .

  whole folder -> UTM
    scp -r FOLDER ${SshAlias}:~/
"@ | Write-Host
}

function Run-Doctor {
    $path = Join-Path $env:TEMP 'utm-shell-doctor.ps1'
    Invoke-WebRequest "$RawBase/doctor.ps1" -OutFile $path -UseBasicParsing
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path $SshAlias
    return $LASTEXITCODE
}

function Run-Update {
    if (-not (Test-Path $StateFile)) { throw 'Saved setup information is missing. Run the README setup command again.' }
    $state = Get-Content $StateFile -Raw | ConvertFrom-Json
    $path = Join-Path $env:TEMP 'utm-shell-setup.ps1'
    Invoke-WebRequest "$RawBase/setup.ps1" -OutFile $path -UseBasicParsing
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$path,'-User',[string]$state.user,'-HostName',[string]$state.host)
    if ($state.keyPath) { $args += @('-KeyPath',[string]$state.keyPath) }
    & powershell.exe @args
    return $LASTEXITCODE
}

if ($Probe) {
    $probe = Get-NetworkState
    if ($probe.State -eq 'reachable') { exit 0 }
    if ($probe.State -eq 'network') { exit 2 }
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
    'status' { Show-Status; exit 0 }
    'vpn' { Open-UtorVpn; exit 0 }
    '--vpn' { Open-UtorVpn; exit 0 }
    'guide' { [void](Open-VpnGuide); exit 0 }
    'host' { Set-LabHost $Value; exit 0 }
    'files' { Show-Files; exit 0 }
    'doctor' { Run-Doctor; exit $LASTEXITCODE }
    'update' { Run-Update; exit $LASTEXITCODE }
    'repair' { Run-Update; exit $LASTEXITCODE }
    'raw' { & ssh.exe $SshAlias; exit $LASTEXITCODE }
    '--raw' { & ssh.exe $SshAlias; exit $LASTEXITCODE }
    '' { }
    $null { }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 2
    }
}

if (-not (Wait-ForNetwork)) { exit 2 }
& ssh.exe $SshAlias
exit $LASTEXITCODE
