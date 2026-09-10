[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$Command,
    [Parameter(Position=1)][string]$Value,
    [switch]$Probe,
    [switch]$EnsureNetwork
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Version = '1.7.0'
$RawBase = 'https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
$VpnGuide = 'https://security.utoronto.ca/services/vpn/usage-guide/'
$VpnDownload = 'https://uoft.me/cisco-vpn-download'
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
utm — UTM lab access

  utm                 connect
  utm status          check connection
  utm vpn             open/setup UTORvpn
  utm host [HOST]     show/change lab computer
  utm files           file-copy examples
  utm doctor          diagnose problems
  utm update          update/repair
  utm help            show this help
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

function Get-State {
    if (-not (Test-Path $StateFile)) { return $null }
    try { return (Get-Content $StateFile -Raw | ConvertFrom-Json) }
    catch { return $null }
}

function Open-Url([string]$Url) {
    try { Start-Process $Url | Out-Null; return $true }
    catch { Write-Host $Url; return $false }
}

function Open-VpnDownload {
    if (-not (Open-Url $VpnDownload)) { [void](Open-Url $VpnGuide) }
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
    foreach ($path in $candidates) { if ($path -and (Test-Path $path)) { return $path } }
    $cmd = Get-Command vpnui.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-NetworkState {
    $output = & ssh.exe -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 $SshAlias true 2>&1
    $code = $LASTEXITCODE
    $text = ($output | Out-String)
    if ($code -eq 0) { return @{ State='reachable'; Output=$text } }
    if ($text -match 'Permission denied|Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED|authenticity of host') { return @{ State='reachable'; Output=$text } }
    if ($text -match 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused') { return @{ State='network'; Output=$text } }
    return @{ State='unknown'; Output=$text }
}

function Show-VpnConnectSteps {
    Write-Host "`nUTORvpn" -ForegroundColor Blue
    Write-Host '  1. Cisco Secure Client opened.'
    Write-Host "  2. Enter $VpnServer and select Connect."
    Write-Host '  3. Sign in with your UTORid and password.'
    Write-Host
}

function Show-VpnInstallSteps {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    $label = if ($arch -eq 'Arm64') { 'Windows ARM64' } else { 'Windows' }
    Write-Host "`nUTORvpn setup" -ForegroundColor Blue
    Write-Host "  1. Download the $label Cisco Secure Client from the page that opened."
    Write-Host '  2. Extract the ZIP if needed.'
    Write-Host '  3. Run the .msi whose name contains core-vpn.'
    Write-Host '  4. Approve the installer. Leave this PowerShell window open.'
    Write-Host
}

function Wait-ForVpn {
    $spin = @('|','/','-','\')
    Write-Host -NoNewline 'Waiting for UTORvpn... '
    for ($i = 0; $i -lt 150; $i++) {
        $probe = Get-NetworkState
        if ($probe.State -ne 'network') {
            Write-Host "`r✓ UTM network ready.                         " -ForegroundColor Green
            return $true
        }
        Write-Host -NoNewline "`rWaiting for UTORvpn... $($spin[$i % 4])"
        Start-Sleep -Seconds 2
    }
    Write-Host "`rStill offline.                              " -ForegroundColor Yellow
    return $false
}

function Wait-ForVpnClient {
    $spin = @('|','/','-','\')
    Write-Host -NoNewline 'Waiting for Cisco Secure Client... '
    for ($i = 0; $i -lt 900; $i++) {
        $client = Get-VpnClientPath
        if ($client) {
            Write-Host "`r✓ Cisco Secure Client installed.             " -ForegroundColor Green
            Start-Process $client | Out-Null
            Show-VpnConnectSteps
            return (Wait-ForVpn)
        }
        Write-Host -NoNewline "`rWaiting for Cisco Secure Client... $($spin[$i % 4])"
        Start-Sleep -Seconds 2
    }
    Write-Host "`rStill waiting for Cisco Secure Client.       " -ForegroundColor Yellow
    return $false
}

function Open-UtorVpn {
    $probe = Get-NetworkState
    if ($probe.State -ne 'network') { Write-Host '✓ UTM is already reachable.' -ForegroundColor Green; return $true }
    $client = Get-VpnClientPath
    if ($client) { Start-Process $client | Out-Null; Show-VpnConnectSteps; return (Wait-ForVpn) }
    Open-VpnDownload
    Show-VpnInstallSteps
    return (Wait-ForVpnClient)
}

function Wait-ForNetwork {
    $probe = Get-NetworkState
    if ($probe.State -ne 'network') { return $true }
    $client = Get-VpnClientPath
    if ($client) { Start-Process $client | Out-Null; Show-VpnConnectSteps; return (Wait-ForVpn) }
    Open-VpnDownload
    Show-VpnInstallSteps
    return (Wait-ForVpnClient)
}

function Show-Status {
    $hostName = Get-SshValue 'hostname'
    $userName = Get-SshValue 'user'
    $probe = Get-NetworkState
    Write-Host -NoNewline "$userName@$hostName — "
    switch ($probe.State) {
        'reachable' { Write-Host 'ready' -ForegroundColor Green }
        'network' { Write-Host 'UTORvpn/network needed' -ForegroundColor Yellow }
        default { Write-Host 'check failed' -ForegroundColor Yellow; if ($probe.Output) { Write-Host $probe.Output.Trim() -ForegroundColor DarkGray } }
    }
}

function Set-LabHost([string]$NewHost) {
    if ([string]::IsNullOrWhiteSpace($NewHost)) { Write-Host (Get-SshValue 'hostname'); return }
    if ($NewHost -notmatch '^[A-Za-z0-9.-]+$') { throw 'Invalid host.' }
    if ($NewHost -notmatch '\.') { $NewHost = "$NewHost.utm.utoronto.ca" }
    $config = Join-Path (Join-Path $HOME '.ssh') 'config'
    if (-not (Test-Path $config)) { throw 'Run setup again.' }
    $lines = [IO.File]::ReadAllText($config) -split "`r?`n"
    $inside = $false
    $updated = foreach ($line in $lines) {
        if ($line -eq '# >>> utm-shell >>>') { $inside = $true; $line; continue }
        if ($line -eq '# <<< utm-shell <<<') { $inside = $false; $line; continue }
        if ($inside -and $line -match '^\s*HostName\s+') { "    HostName $NewHost" } else { $line }
    }
    [IO.File]::WriteAllText($config, (($updated -join "`r`n").TrimEnd() + "`r`n"), [Text.UTF8Encoding]::new($false))
    if (Test-Path $StateFile) {
        try { $state = Get-Content $StateFile -Raw | ConvertFrom-Json; $state.host = $NewHost; $state | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8 } catch { }
    }
    Write-Host $NewHost -ForegroundColor Green
}

function Show-Files {
@"
scp FILE ${SshAlias}:~/             # computer -> UTM
scp ${SshAlias}:~/FILE .             # UTM -> computer
scp -r FOLDER ${SshAlias}:~/         # folder -> UTM
"@ | Write-Host
}

function Run-Doctor {
    $path = Join-Path $env:TEMP 'utm-shell-doctor.ps1'
    Invoke-WebRequest "$RawBase/doctor.ps1" -OutFile $path -UseBasicParsing
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path $SshAlias
    return $LASTEXITCODE
}

function Run-Update {
    $state = Get-State
    if (-not $state) { throw 'Run setup again.' }
    $path = Join-Path $env:TEMP 'utm-shell-setup.ps1'
    Invoke-WebRequest "$RawBase/setup.ps1" -OutFile $path -UseBasicParsing
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$path,'-User',[string]$state.user,'-HostName',[string]$state.host)
    if ($state.keyPath) { $args += @('-KeyPath', [string]$state.keyPath) }
    & powershell.exe @args
    return $LASTEXITCODE
}

if ($Probe) {
    $probe = Get-NetworkState
    if ($probe.State -eq 'reachable') { exit 0 }
    if ($probe.State -eq 'network') { exit 2 }
    exit 1
}
if ($EnsureNetwork) { if (Wait-ForNetwork) { exit 0 }; exit 2 }

switch ($Command) {
    'help' { Show-Usage; exit 0 }
    '--help' { Show-Usage; exit 0 }
    '-h' { Show-Usage; exit 0 }
    'status' { Show-Status; exit 0 }
    'vpn' { if (Open-UtorVpn) { exit 0 } else { exit 2 } }
    '--vpn' { if (Open-UtorVpn) { exit 0 } else { exit 2 } }
    'guide' { [void](Open-Url $VpnGuide); exit 0 }
    'host' { Set-LabHost $Value; exit 0 }
    'files' { Show-Files; exit 0 }
    'doctor' { $rc = Run-Doctor; exit $rc }
    'update' { $rc = Run-Update; exit $rc }
    'repair' { $rc = Run-Update; exit $rc }
    'raw' { & ssh.exe $SshAlias; exit $LASTEXITCODE }
    '--raw' { & ssh.exe $SshAlias; exit $LASTEXITCODE }
    '' { }
    $null { }
    default { Write-Error 'Unknown command. Try `utm help`.'; exit 2 }
}

$state = Get-State
if ($state -and ((-not ($state.PSObject.Properties.Name -contains 'complete')) -or -not [bool]$state.complete)) {
    Write-Host 'Finishing setup...' -ForegroundColor Blue
    $rc = Run-Update
    exit $rc
}

if (-not (Wait-ForNetwork)) {
    Write-Host 'Type utm again whenever the VPN/network is ready.' -ForegroundColor Yellow
    exit 2
}

& ssh.exe $SshAlias
exit $LASTEXITCODE