$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
git -C $root config core.hooksPath hooks
if ($LASTEXITCODE -ne 0) { throw 'Failed to configure repository hooks.' }
Write-Host 'Configured repository hooks from ./hooks.'
