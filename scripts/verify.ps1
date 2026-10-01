$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

Push-Location $root
try {
    git diff --check
    if ($LASTEXITCODE -ne 0) { throw 'Whitespace verification failed.' }

    $parseFailed = $false
    Get-ChildItem scripts -Filter *.ps1 | ForEach-Object {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $_.FullName,
            [ref]$null,
            [ref]$errors
        ) | Out-Null
        if ($errors) {
            $errors | Format-List
            $parseFailed = $true
        }
    }
    if ($parseFailed) { throw 'PowerShell parsing failed.' }

    & "$PSScriptRoot\verify-public-safety.ps1"
    & "$PSScriptRoot\verify-relative-links.ps1"

    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash) {
        & $bash.Source -n scripts/build-kernel-msys2.sh
        & $bash.Source -n scripts/build-diagnostic-init.sh
        & $bash.Source -n hooks/pre-push
        if ($LASTEXITCODE -ne 0) { throw 'Shell syntax verification failed.' }
    }

    Write-Host 'Port-Station verification passed.' -ForegroundColor Green
}
finally {
    Pop-Location
}
