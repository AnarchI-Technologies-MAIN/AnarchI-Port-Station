$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
git -C $root config core.hooksPath hooks
Write-Host 'Configured repository hooks from ./hooks.'
