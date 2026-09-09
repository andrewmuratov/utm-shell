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
$Version = '1.6.0'
$RawBase = 'https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
$DefaultHost = 'dh2026pc08'
$Start = '# >>> utm-shell >>>'
$End = '# <<< utm-shell <<<'

function Ok([string]$m)   { Write-Host "✓ $m" -ForegroundColor Green }
function Fail([string]$m) { throw "utm-shell: $m" }

if ($Help) {
@'
utm-shell setup

Usually just run the one-line installer from the README.
Only your UTORid is needed on a new install.

Options:
  -User UTORID
  -HostName HOST
  -Alias NAME
  -KeyPath PATH
  -SkipKeyCopy
  -NoHushLogin
'@ | Write-Host
    exit 0
}

$ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
$keygen = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
if (-not $ssh -or -not $keygen) {
    try { Start-Process 'ms-settings:optionalfeatures' | Out-Null } catch { }
    Fail "OpenSSH Client is required. Windows Optional Features was opened; install OpenSSH Client, then paste the same setup command again."
}

$SshDir = Join-Path $HOME '.ssh'
$StateDir = Join-Path (Join-Path $HOME '.config') 'utm-shell'
$BinDir = Join-Path (Join-Path $HOME '.local') 'bin'
$StateFile = Join-Path $StateDir 'config.json'
$SshConfig = Join-Path $SshDir 'config'
New-Item -ItemType Directory -Force -Path $SshDir, $StateDir, $BinDir | Out-Null

function Get-SshValue([string]$Name) {
    $lines = & $ssh.Source -G $Alias 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($Name))\s+(.+)$") { return $Matches[1].Trim() }
    }
    return ''
}

# Reuse saved setup.
if (Test-Path $StateFile) {
    try {
        $previous = Get-Content $StateFile -Raw | ConvertFrom-Json
        if ([string]::IsNullOrWhiteSpace($User) -and $previous.user) { $User = [string]$previous.user }
        if ([string]::IsNullOrWhiteSpace($HostName) -and $previous.host) { $HostName = [string]$previous.host }
        if ([string]::IsNullOrWhiteSpace($KeyPath) -and $previous.keyPath -and (Test-Path $previous.keyPath)) { $KeyPath = [string]$previous.keyPath }
    } catch { }
}

# Adopt an older/manual Host utm configuration when possible.
if ([string]::IsNullOrWhiteSpace($HostName)) {
    $existingHost = Get-SshValue 'hostname'
    if ($existingHost -like '*.utm.utoronto.ca') {
        $HostName = $existingHost
        if ([string]::IsNullOrWhiteSpace($User)) { $User = Get-SshValue 'user' }
        if ([string]::IsNullOrWhiteSpace($KeyPath)) {
            $identities = & $ssh.Source -G $Alias 2>$null | Where-Object { $_ -match '^identityfile\s+' }
            foreach ($line in $identities) {
                $candidate = ($line -replace '^identityfile\s+','').Trim().Trim('"')
                if ($candidate.StartsWith('~')) { $candidate = Join-Path $HOME $candidate.Substring(1).TrimStart('/','\') }
                if (Test-Path $candidate) { $KeyPath = $candidate; break }
            }
        }
    }
}

Write-Host "`nutm-shell $Version" -ForegroundColor Blue
if ([string]::IsNullOrWhiteSpace($User)) { $User = Read-Host 'UTORid' }
if ([string]::IsNullOrWhiteSpace($HostName)) { $HostName = $DefaultHost }

if ($User -notmatch '^[A-Za-z0-9._-]+$') { Fail 'Invalid UTORid.' }
if ($Alias -notmatch '^[A-Za-z0-9._-]+$') { Fail 'Invalid SSH alias.' }
if ($HostName -notmatch '^[A-Za-z0-9.-]+$') { Fail 'Invalid lab hostname.' }
if ($HostName -notmatch '\.') { $HostName = "$HostName.utm.utoronto.ca" }

if ([string]::IsNullOrWhiteSpace($KeyPath) -or -not (Test-Path $KeyPath)) { $KeyPath = Join-Path $SshDir 'id_ed25519_utm' }
if ($KeyPath.StartsWith('~')) { $KeyPath = Join-Path $HOME $KeyPath.Substring(1).TrimStart('/','\') }
$KeyPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($KeyPath))
$KeyCreated = $false

if (-not (Test-Path $KeyPath)) {
    & $keygen.Source -q -t ed25519 -a 100 -N '' -f $KeyPath -C "utm-shell:$User@$HostName"
    if ($LASTEXITCODE -ne 0) { Fail 'Could not create SSH key.' }
    $KeyCreated = $true
}
if (-not (Test-Path "$KeyPath.pub")) {
    $pub = & $keygen.Source -y -f $KeyPath
    if ($LASTEXITCODE -ne 0) { Fail 'Could not rebuild public key.' }
    [IO.File]::WriteAllText("$KeyPath.pub", (($pub -join "`n").Trim() + "`n"), [Text.UTF8Encoding]::new($false))
}

function Write-SshConfig {
    $identity = $KeyPath.Replace('\','/')
    $block = @"
$Start
Host $Alias
    HostName $HostName
    User $User
    IdentityFile "$identity"
    IdentitiesOnly yes
    ConnectTimeout 5
    ConnectionAttempts 1
    ServerAliveInterval 60
    ServerAliveCountMax 3
$End
"@
    $current = if (Test-Path $SshConfig) { [IO.File]::ReadAllText($SshConfig) } else { '' }
    $pattern = '(?ms)^# >>> utm-shell >>>\r?\n.*?^# <<< utm-shell <<<\r?\n?'
    $current = [regex]::Replace($current, $pattern, '').TrimEnd()
    $newConfig = if ($current) { "$current`r`n`r`n$block`r`n" } else { "$block`r`n" }
    [IO.File]::WriteAllText($SshConfig, $newConfig, [Text.UTF8Encoding]::new($false))
    & $ssh.Source -G $Alias *> $null
    if ($LASTEXITCODE -ne 0) { Fail 'Generated SSH config is invalid.' }
}

function Save-State {
    $state = [ordered]@{
        version = $Version
        alias = $Alias
        user = $User
        host = $HostName
        keyPath = $KeyPath
        keyCreated = $KeyCreated
    }
    $state | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8
}

Write-SshConfig
[IO.File]::WriteAllText((Join-Path $StateDir 'alias'), "$Alias`n", [Text.UTF8Encoding]::new($false))
$ConnectPath = Join-Path $StateDir 'connect.ps1'
$connectText = (Invoke-WebRequest "$RawBase/connect.ps1" -UseBasicParsing).Content
[IO.File]::WriteAllText($ConnectPath, $connectText, [Text.UTF8Encoding]::new($false))
$CmdPath = Join-Path $BinDir 'utm.cmd'
$cmdText = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\.config\utm-shell\connect.ps1`" %*`r`n"
[IO.File]::WriteAllText($CmdPath, $cmdText, [Text.ASCIIEncoding]::new())

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = if ($userPath) { $userPath -split ';' } else { @() }
if ($parts -notcontains $BinDir) {
    [Environment]::SetEnvironmentVariable('Path', $(if ([string]::IsNullOrWhiteSpace($userPath)) { $BinDir } else { "$BinDir;$userPath" }), 'User')
}
if (($env:Path -split ';') -notcontains $BinDir) { $env:Path = "$BinDir;$env:Path" }
Save-State
Ok 'Local setup'

function Test-Key {
    & $ssh.Source -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 $Alias true *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-KeyPath([string]$Candidate) {
    & $ssh.Source -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o ConnectionAttempts=1 -i $Candidate "$User@$HostName" true *> $null
    return ($LASTEXITCODE -eq 0)
}

function Find-AuthorizedKey {
    $candidates = @(
        (Join-Path $SshDir 'id_ed25519'),
        (Join-Path $SshDir 'id_ecdsa'),
        (Join-Path $SshDir 'id_rsa')
    )
    Get-ChildItem -Path $SshDir -Filter '*.pub' -ErrorAction SilentlyContinue | ForEach-Object {
        $candidate = $_.FullName.Substring(0, $_.FullName.Length - 4)
        if (Test-Path $candidate) { $candidates += $candidate }
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path $candidate) -or $candidate -eq $KeyPath) { continue }
        if (Test-KeyPath $candidate) {
            $script:KeyPath = $candidate
            $script:KeyCreated = $false
            Write-SshConfig
            Save-State
            Ok 'Reused existing authorized SSH key'
            return $true
        }
    }
    return $false
}

if (-not $SkipKeyCopy) {
    if (-not (Test-Key)) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ConnectPath -EnsureNetwork
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Setup saved. Connect UTORvpn, then run this setup command again.' -ForegroundColor Yellow
            exit 2
        }

        if (-not (Find-AuthorizedKey)) {
            Write-Host "`nPassword once: enter your UTORid password if SSH asks." -ForegroundColor Blue
            $pubText = ([IO.File]::ReadAllText("$KeyPath.pub")).Trim()
            $pubB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pubText))
            $remote = 'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; pub=$(printf ''%s'' ''{0}'' | base64 -d); grep -qxF "$pub" ~/.ssh/authorized_keys || printf ''%s\n'' "$pub" >> ~/.ssh/authorized_keys' -f $pubB64
            & $ssh.Source -o StrictHostKeyChecking=accept-new $Alias $remote *> $null
            if ($LASTEXITCODE -ne 0) { Fail 'Login failed. Check UTORvpn/UTORid and retry.' }
            if (-not (Test-Key)) { Fail 'Passwordless login could not be verified.' }
            Ok 'Passwordless login'
        }
    } else {
        Ok 'Passwordless login'
    }
}

$remoteText = (Invoke-WebRequest "$RawBase/remote.sh" -UseBasicParsing).Content.Replace("`r`n", "`n")
$remoteB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteText))
$hush = if ($NoHushLogin) { '0' } else { '1' }
& $ssh.Source $Alias "printf '%s' '$remoteB64' | base64 -d | bash -s -- '$hush'" *> $null
if ($LASTEXITCODE -ne 0) { Fail 'Remote shell setup failed.' }
Ok 'Remote shell'

Write-Host "`nReady. Type: utm" -ForegroundColor Green
