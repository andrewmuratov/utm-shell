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

$argsForSetup = @{}
if ($PSBoundParameters.ContainsKey('User')) { $argsForSetup.User = $User }
if ($PSBoundParameters.ContainsKey('HostName')) { $argsForSetup.HostName = $HostName }
if ($PSBoundParameters.ContainsKey('Alias')) { $argsForSetup.Alias = $Alias }
if ($PSBoundParameters.ContainsKey('KeyPath')) { $argsForSetup.KeyPath = $KeyPath }
if ($SkipKeyCopy) { $argsForSetup.SkipKeyCopy = $true }
if ($NoHushLogin) { $argsForSetup.NoHushLogin = $true }
if ($Help) { $argsForSetup.Help = $true }

$localSetup = Join-Path $PSScriptRoot 'setup.ps1'
if ($PSScriptRoot -and (Test-Path $localSetup)) {
    & $localSetup @argsForSetup
    exit $LASTEXITCODE
}

$url = 'https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1'
$tmp = Join-Path $env:TEMP 'utm-shell-setup.ps1'
Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing
& $tmp @argsForSetup
