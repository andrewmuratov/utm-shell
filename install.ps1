[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$RemainingArgs
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$localSetup = Join-Path $PSScriptRoot 'setup.ps1'
if ($PSScriptRoot -and (Test-Path $localSetup)) {
    & $localSetup @RemainingArgs
    exit $LASTEXITCODE
}

$url = 'https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.ps1'
$tmp = Join-Path $env:TEMP 'utm-shell-setup.ps1'
Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing
& $tmp @RemainingArgs
