$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$excluded = @('.git', 'build')
$patterns = @(
    ('gh' + 'o_[A-Za-z0-9_]+'),
    ('github_' + 'pat_[A-Za-z0-9_]+'),
    ('s' + 'k-[A-Za-z0-9_-]{16,}'),
    ('-----BEGIN ' + '[A-Z ]*PRIVATE KEY-----'),
    ('(?i)(api[_-]?key|access[_-]?token|client[_-]?secret|pass' + 'word)\s*[:=]\s*[^\s<]+'),
    ('(?i)C:\\' + 'Users\\'),
    ('(?i)/ho' + 'me/[^/\s]+'),
    ('(?i)recovery pass' + 'word\s*[:=]'),
    '\b\d{6}-\d{6}-\d{6}-\d{6}-\d{6}-\d{6}-\d{6}-\d{6}\b'
)

$files = Get-ChildItem $root -Recurse -File | Where-Object {
    $relative = $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    -not ($excluded | Where-Object { $relative -eq $_ -or $relative.StartsWith("$_\") -or $relative.StartsWith("$_/") })
}

$findings = foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            [pscustomobject]@{ File = $file.FullName; Pattern = $pattern }
        }
    }
}

if ($findings) {
    $findings | Format-Table -AutoSize
    throw 'Public-safety scan found prohibited content.'
}

Write-Host 'Public-safety scan passed.'
