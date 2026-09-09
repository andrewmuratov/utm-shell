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
$Version = '1.2.0'
$RawBase = 'https://raw.githubusercontent.com/andrewmuratov/utm-shell/main'
$Start = '# >>> utm-shell >>>'
$End = '# <<< utm-shell <<<'

function Info([string]$m) { Write-Host "• $m" -ForegroundColor Cyan }
function Ok([string]$m)   { Write-Host "✓ $m" -ForegroundColor Green }
function Fail([string]$m) { throw "utm-shell: $m" }

if ($Help) {
@'
utm-shell setup

Normal use: run it and answer two questions.

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

Write-Host "`nutm-shell $Version" -ForegroundColor Blue
Write-Host "Set up UTM lab SSH in about a minute.`n" -ForegroundColor DarkGray

$ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
$keygen = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
if (-not $ssh -or -not $keygen) {
    Fail "OpenSSH Client is required. Install 'OpenSSH Client' from Windows Optional Features, then rerun this command."
}

if ([string]::IsNullOrWhiteSpace($User)) { $User = Read-Host 'UTORid' }
if ([string]::IsNullOrWhiteSpace($HostName)) { $HostName = Read-Host 'Lab computer (example: dh2026pc08)' }

if ($User -notmatch '^[A-Za-z0-9._-]+$') { Fail 'Invalid UTORid.' }
if ($Alias -notmatch '^[A-Za-z0-9._-]+$') { Fail 'Invalid SSH alias.' }
if ($HostName -notmatch '^[A-Za-z0-9.-]+$') { Fail 'Invalid lab hostname.' }
if ($HostName -notmatch '\.') { $HostName = "$HostName.utm.utoronto.ca" }

$SshDir = Join-Path $HOME '.ssh'
$StateDir = Join-Path (Join-Path $HOME '.config') 'utm-shell'
$SshConfig = Join-Path $SshDir 'config'
New-Item -ItemType Directory -Force -Path $SshDir, $StateDir | Out-Null

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    $KeyPath = Join-Path $SshDir 'id_ed25519_utm'
}
if ($KeyPath.StartsWith('~')) { $KeyPath = Join-Path $HOME $KeyPath.Substring(1).TrimStart('/','\') }
$KeyPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($KeyPath))
$KeyCreated = $false

if (-not (Test-Path $KeyPath)) {
    Info 'Creating a dedicated SSH key'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $KeyPath) | Out-Null
    & $keygen.Source -q -t ed25519 -a 100 -N '' -f $KeyPath -C "utm-shell:$User@$HostName"
    if ($LASTEXITCODE -ne 0) { Fail 'Could not create SSH key.' }
    $KeyCreated = $true
}

if (-not (Test-Path "$KeyPath.pub")) {
    $pub = & $keygen.Source -y -f $KeyPath
    if ($LASTEXITCODE -ne 0) { Fail 'Could not rebuild public key.' }
    [IO.File]::WriteAllText("$KeyPath.pub", (($pub -join "`n").Trim() + "`n"), [Text.UTF8Encoding]::new($false))
}

$identity = $KeyPath.Replace('\','/')
$block = @"
$Start
Host $Alias
    HostName $HostName
    User $User
    IdentityFile "$identity"
    IdentitiesOnly yes
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
Ok "Created: ssh $Alias"

function Test-Key {
    & $ssh.Source -o BatchMode=yes -o ConnectTimeout=8 $Alias true *> $null
    return ($LASTEXITCODE -eq 0)
}

if (-not $SkipKeyCopy) {
    if (Test-Key) {
        Ok 'Passwordless login already works'
    } else {
        Write-Host "`nOne-time step: enter your UTORid password when SSH asks for it." -ForegroundColor Blue
        Write-Host 'If this is your first connection, SSH may also ask you to confirm the host.' -ForegroundColor DarkGray
        $pubText = ([IO.File]::ReadAllText("$KeyPath.pub")).Trim()
        $pubB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pubText))
        $remote = 'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; pub=$(printf ''%s'' ''{0}'' | base64 -d); grep -qxF "$pub" ~/.ssh/authorized_keys || printf ''%s\n'' "$pub" >> ~/.ssh/authorized_keys' -f $pubB64
        & $ssh.Source -o StrictHostKeyChecking=accept-new $Alias $remote
        if ($LASTEXITCODE -ne 0) {
            Write-Warning 'Could not log in. Make sure you are on campus Wi-Fi or UTORvpn.'
            Write-Warning 'If your password is definitely correct but UTM still says Permission denied, your UTORid may not be provisioned on the lab system yet; contact course staff.'
            exit 1
        }
        if (-not (Test-Key)) { Fail 'The key was copied, but passwordless login did not verify.' }
        Ok 'Passwordless login works'
    }
}

Info 'Installing the clean UTM shell'
$remoteText = (Invoke-WebRequest "$RawBase/remote.sh" -UseBasicParsing).Content
$remoteText = $remoteText.Replace("`r`n", "`n")
$remoteB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteText))
$hush = if ($NoHushLogin) { '0' } else { '1' }
$cmd = "printf '%s' '$remoteB64' | base64 -d | bash -s -- '$hush'"
& $ssh.Source $Alias $cmd
if ($LASTEXITCODE -ne 0) { Fail 'Remote shell setup failed.' }
Ok 'Remote shell installed'

$state = [ordered]@{
    version = $Version
    alias = $Alias
    user = $User
    host = $HostName
    keyPath = $KeyPath
    keyCreated = $KeyCreated
}
$state | ConvertTo-Json | Set-Content -Path (Join-Path $StateDir 'config.json') -Encoding UTF8

Write-Host "`nDone. From now on, just run:`n" -ForegroundColor Green
Write-Host "    ssh $Alias`n" -ForegroundColor Blue
Write-Host 'Inside UTM: utm-help' -ForegroundColor DarkGray
