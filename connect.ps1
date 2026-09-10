[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$Command,
    [Parameter(Position=1)][string]$Value,
    [switch]$Probe,
    [switch]$EnsureNetwork
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Version = '1.7.1'
$RawBase = 'https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
$VpnGuide = 'https://security.utoronto.ca/services/vpn/usage-guide/'
$VpnDownload = 'https://uoft.me/cisco-vpn-download'
$VpnServer = 'general.vpn.utoronto.ca'
$StateDir = Join-Path (Join-Path $HOME '.config') 'utm-shell'
$AliasFile = Join-Path $StateDir 'alias'
$StateFile = Join-Path $StateDir 'config.json'
$SshAlias = 'utm'
$script:AutoInstallTried = $false

if (Test-Path $AliasFile) {
    $candidate = ([IO.File]::ReadAllText($AliasFile)).Trim()
    if ($candidate) { $SshAlias = $candidate }
}

function Show-Usage {
@'
utm — UTM lab access

  utm                 connect
  utm status          check connection
  utm vpn             connect/setup UTORvpn
  utm host [HOST]     show/change lab computer
  utm files           file-copy examples
  utm doctor          diagnose problems
  utm update          update/repair
  utm help            help
'@ | Write-Host
}

function Get-SshValue([string]$Name) {
    $lines = & ssh.exe -G $SshAlias 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    foreach ($line in $lines) { if ($line -match "^$([regex]::Escape($Name))\s+(.+)$") { return $Matches[1].Trim() } }
    return ''
}

function Get-State {
    if (-not (Test-Path $StateFile)) { return $null }
    try { return (Get-Content $StateFile -Raw | ConvertFrom-Json) } catch { return $null }
}

function Open-Url([string]$Url) { try { Start-Process $Url | Out-Null; return $true } catch { Write-Host $Url; return $false } }
function Open-VpnDownload { if (-not (Open-Url $VpnDownload)) { [void](Open-Url $VpnGuide) } }

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
    }
    foreach ($path in $candidates) { if ($path -and (Test-Path $path)) { return $path } }
    $cmd = Get-Command vpnui.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-NetworkState {
    $output = & ssh.exe -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 $SshAlias true 2>&1
    $code = $LASTEXITCODE; $text = ($output | Out-String)
    if ($code -eq 0) { return @{ State='reachable'; Output=$text } }
    if ($text -match 'Permission denied|Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED|authenticity of host') { return @{ State='reachable'; Output=$text } }
    if ($text -match 'Connection timed out|Operation timed out|No route to host|Network is unreachable|Could not resolve hostname|Name or service not known|Temporary failure in name resolution|Connection refused') { return @{ State='network'; Output=$text } }
    return @{ State='unknown'; Output=$text }
}

function Show-VpnConnectSteps {
    Write-Host "`nUTORvpn" -ForegroundColor Blue
    Write-Host "  1. Connect to $VpnServer."
    Write-Host '  2. Sign in with your UTORid and password.'
    Write-Host
}

function Show-VpnInstallSteps {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    $label = if ($arch -eq 'Arm64') { 'Windows ARM64' } else { 'Windows' }
    Write-Host "`nUTORvpn setup" -ForegroundColor Blue
    Write-Host "  1. In the page that opened, click $label."
    Write-Host '  2. Leave this PowerShell window open. utm-shell will unpack and install the VPN automatically.'
    Write-Host '  3. Approve the Windows administrator prompt when it appears.'
    Write-Host
}

function Find-CiscoMsi {
    $downloads = Join-Path $HOME 'Downloads'
    if (-not (Test-Path $downloads)) { return $null }
    $msi = Get-ChildItem $downloads -Recurse -File -Filter '*.msi' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'core-vpn' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($msi) { return $msi.FullName }
    return $null
}

function Find-CiscoZip {
    $downloads = Join-Path $HOME 'Downloads'
    if (-not (Test-Path $downloads)) { return $null }
    $zip = Get-ChildItem $downloads -File -Filter 'cisco-secure-client-win*.zip' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($zip) { return $zip.FullName }
    return $null
}

function Try-AutoInstallCisco {
    if ($script:AutoInstallTried) { return $false }
    $msi = Find-CiscoMsi
    $work = $null
    if (-not $msi) {
        $zip = Find-CiscoZip
        if (-not $zip) { return $false }
        $work = Join-Path $env:TEMP ("utm-shell-cisco-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work -Force | Out-Null
        Write-Host "`r✓ Cisco download found. Extracting...                 " -ForegroundColor Green
        Expand-Archive -LiteralPath $zip -DestinationPath $work -Force
        $found = Get-ChildItem $work -Recurse -File -Filter '*.msi' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'core-vpn' } |
            Select-Object -First 1
        if ($found) { $msi = $found.FullName }
    }
    if (-not $msi) { if ($work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }; return $false }

    $script:AutoInstallTried = $true
    Write-Host 'Installing Cisco Secure Client automatically.' -ForegroundColor Blue
    Write-Host 'Approve the Windows administrator prompt once.' -ForegroundColor DarkGray
    try {
        $args = "/i `"$msi`" /passive /norestart"
        $p = Start-Process msiexec.exe -Verb RunAs -Wait -PassThru -ArgumentList $args
        if ($p.ExitCode -notin @(0,3010)) { throw "Installer exited with code $($p.ExitCode)." }
    } finally {
        if ($work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
    }
    return [bool](Get-VpnClientPath)
}

function Wait-ForVpn {
    $spin = @('|','/','-','\')
    Write-Host -NoNewline 'Waiting for UTORvpn... '
    for ($i = 0; $i -lt 150; $i++) {
        $probe = Get-NetworkState
        if ($probe.State -ne 'network') { Write-Host "`r✓ UTM network ready.                         " -ForegroundColor Green; return $true }
        Write-Host -NoNewline "`rWaiting for UTORvpn... $($spin[$i % 4])"; Start-Sleep -Seconds 2
    }
    Write-Host "`rStill offline.                              " -ForegroundColor Yellow; return $false
}

function Wait-ForVpnClient {
    $spin = @('|','/','-','\')
    Write-Host -NoNewline 'Waiting for Cisco Secure Client... '
    for ($i = 0; $i -lt 900; $i++) {
        $client = Get-VpnClientPath
        if (-not $client) {
            try { [void](Try-AutoInstallCisco) } catch { Write-Host "`nAutomatic VPN install failed: $($_.Exception.Message)" -ForegroundColor Yellow }
            $client = Get-VpnClientPath
        }
        if ($client) {
            Write-Host "`r✓ Cisco Secure Client ready.                 " -ForegroundColor Green
            Start-Process $client | Out-Null; Show-VpnConnectSteps; return (Wait-ForVpn)
        }
        Write-Host -NoNewline "`rWaiting for Cisco Secure Client... $($spin[$i % 4])"; Start-Sleep -Seconds 2
    }
    Write-Host "`rStill waiting for Cisco Secure Client.       " -ForegroundColor Yellow; return $false
}

function Wait-ForNetwork {
    $probe = Get-NetworkState
    if ($probe.State -ne 'network') { return $true }
    $client = Get-VpnClientPath
    if ($client) { Start-Process $client | Out-Null; Show-VpnConnectSteps; return (Wait-ForVpn) }
    try {
        if (Try-AutoInstallCisco) {
            $client = Get-VpnClientPath; if ($client) { Start-Process $client | Out-Null; Show-VpnConnectSteps; return (Wait-ForVpn) }
        }
    } catch { Write-Host "Automatic VPN install failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    Open-VpnDownload; Show-VpnInstallSteps; return (Wait-ForVpnClient)
}

function Show-Status {
    $hostName = Get-SshValue 'hostname'; $userName = Get-SshValue 'user'; $probe = Get-NetworkState
    Write-Host -NoNewline "$userName@$hostName — "
    switch ($probe.State) {
        'reachable' { Write-Host 'ready' -ForegroundColor Green }
        'network' { Write-Host 'UTORvpn needed' -ForegroundColor Yellow }
        default { Write-Host 'check failed' -ForegroundColor Yellow; if ($probe.Output) { Write-Host $probe.Output.Trim() -ForegroundColor DarkGray } }
    }
}

function Set-LabHost([string]$NewHost) {
    if ([string]::IsNullOrWhiteSpace($NewHost)) { Write-Host (Get-SshValue 'hostname'); return }
    if ($NewHost -notmatch '^[A-Za-z0-9.-]+$') { throw 'Invalid host.' }
    if ($NewHost -notmatch '\.') { $NewHost = "$NewHost.utm.utoronto.ca" }
    $config = Join-Path (Join-Path $HOME '.ssh') 'config'; if (-not (Test-Path $config)) { throw 'Run setup again.' }
    $lines = [IO.File]::ReadAllText($config) -split "`r?`n"; $inside = $false
    $updated = foreach ($line in $lines) {
        if ($line -eq '# >>> utm-shell >>>') { $inside = $true; $line; continue }
        if ($line -eq '# <<< utm-shell <<<') { $inside = $false; $line; continue }
        if ($inside -and $line -match '^\s*HostName\s+') { "    HostName $NewHost" } else { $line }
    }
    [IO.File]::WriteAllText($config, (($updated -join "`r`n").TrimEnd() + "`r`n"), [Text.UTF8Encoding]::new($false)); Write-Host $NewHost -ForegroundColor Green
}

function Show-Files { @"
scp FILE ${SshAlias}:~/             # computer -> UTM
scp ${SshAlias}:~/FILE .             # UTM -> computer
scp -r FOLDER ${SshAlias}:~/         # folder -> UTM
"@ | Write-Host }

function Run-Doctor { $path = Join-Path $env:TEMP 'utm-shell-doctor.ps1'; Invoke-WebRequest "$RawBase/doctor.ps1" -OutFile $path -UseBasicParsing; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path $SshAlias; return $LASTEXITCODE }
function Run-Update {
    $state = Get-State; if (-not $state) { throw 'Run setup again.' }
    $path = Join-Path $env:TEMP 'utm-shell-setup.ps1'; Invoke-WebRequest "$RawBase/setup.ps1" -OutFile $path -UseBasicParsing
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$path,'-User',[string]$state.user,'-HostName',[string]$state.host)
    if ($state.keyPath) { $args += @('-KeyPath', [string]$state.keyPath) }
    & powershell.exe @args; return $LASTEXITCODE
}

if ($Probe) { $p=Get-NetworkState; if($p.State -eq 'reachable'){exit 0}; if($p.State -eq 'network'){exit 2}; exit 1 }
if ($EnsureNetwork) { if (Wait-ForNetwork) { exit 0 }; exit 2 }

switch ($Command) {
    'help' { Show-Usage; exit 0 }; '--help' { Show-Usage; exit 0 }; '-h' { Show-Usage; exit 0 }
    'status' { Show-Status; exit 0 }; 'vpn' { if(Wait-ForNetwork){exit 0}else{exit 2} }; '--vpn' { if(Wait-ForNetwork){exit 0}else{exit 2} }
    'guide' { [void](Open-Url $VpnGuide); exit 0 }; 'host' { Set-LabHost $Value; exit 0 }; 'files' { Show-Files; exit 0 }
    'doctor' { exit (Run-Doctor) }; 'update' { exit (Run-Update) }; 'repair' { exit (Run-Update) }
    'raw' { & ssh.exe $SshAlias; exit $LASTEXITCODE }; '--raw' { & ssh.exe $SshAlias; exit $LASTEXITCODE }
    '' { }; $null { }; default { Write-Error 'Unknown command. Try `utm help`.'; exit 2 }
}

$state = Get-State
if ($state -and ((-not ($state.PSObject.Properties.Name -contains 'complete')) -or -not [bool]$state.complete)) { Write-Host 'Finishing setup...' -ForegroundColor Blue; exit (Run-Update) }
if (-not (Wait-ForNetwork)) { Write-Host 'Type utm again whenever the VPN/network is ready.' -ForegroundColor Yellow; exit 2 }
& ssh.exe $SshAlias; exit $LASTEXITCODE
