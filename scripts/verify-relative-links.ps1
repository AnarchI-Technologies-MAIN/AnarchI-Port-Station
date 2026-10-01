$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failures = @()

Get-ChildItem $root -Recurse -Filter *.md -File | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]'
} | ForEach-Object {
    $file = $_
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($match in [regex]::Matches($content, '\[[^\]]+\]\((?!https?://|#|mailto:)([^)]+)\)')) {
        $target = [uri]::UnescapeDataString($match.Groups[1].Value.Split('#')[0])
        if (-not $target) { continue }
        $resolved = Join-Path $file.DirectoryName $target
        if (-not (Test-Path -LiteralPath $resolved)) {
            $failures += "$($file.FullName): missing $target"
        }
    }
}

if ($failures) {
    $failures | ForEach-Object { Write-Error $_ }
    throw 'Relative-link verification failed.'
}

Write-Host 'Relative-link verification passed.'
