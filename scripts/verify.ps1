$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

Push-Location $root
try {
    git diff --check HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Whitespace verification failed.' }

    $parseFailed = $false
    Get-ChildItem scripts, tests -Recurse -File -Include *.ps1, *.psm1 | ForEach-Object {
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
    & "$root\tests\Install-TestEfi.Behavior.Tests.ps1"

    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash) {
        foreach ($file in @('scripts/build-kernel-msys2.sh', 'scripts/build-diagnostic-init.sh', 'tests/Build-Guard.Contracts.sh', 'hooks/pre-push')) {
            & $bash.Source -n $file
            if ($LASTEXITCODE -ne 0) { throw "Shell syntax verification failed: $file" }
        }
        & $bash.Source tests/Build-Guard.Contracts.sh
        if ($LASTEXITCODE -ne 0) { throw 'Build guard contract verification failed.' }
    }

    Write-Host 'Port-Station verification passed.' -ForegroundColor Green
}
finally {
    Pop-Location
}
