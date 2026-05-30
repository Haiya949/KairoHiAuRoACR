$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Read-ProjectFile([string]$relativePath) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing file: $relativePath"
    }

    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

$helperCatalog = Read-ProjectFile 'Helper/HiAuRo.Helper/MCHHelper.cs'
$docs = Read-ProjectFile 'docs/DEVELOPMENT.md'
$failures = [System.Collections.Generic.List[string]]::new()

$requiredActions = [ordered]@{
    PileBunker = 16503
    ArmPunch = 16504
    RollerDash = 17206
    CrownedCollider = 25787
}

foreach ($item in $requiredActions.GetEnumerator()) {
    $pattern = "\b$($item.Key)\s*=\s*$($item.Value)\b"
    if ($helperCatalog -notmatch $pattern) {
        $failures.Add("Helper MCH skill catalog missing xivanalysis action ID: $($item.Key) = $($item.Value)")
    }
}

$requiredStatuses = [ordered]@{
    Tactician = 1951
    Hypercharged = 3864
    ExcavatorReady = 3865
    FullMetalMachinist = 3866
}

foreach ($item in $requiredStatuses.GetEnumerator()) {
    $pattern = "\b$($item.Key)\s*=\s*$($item.Value)\b"
    if ($helperCatalog -notmatch $pattern) {
        $failures.Add("Helper MCH buff catalog missing xivanalysis status ID: $($item.Key) = $($item.Value)")
    }
}

$localCatalogs = @(
    'Jobs/Machinist/Data/MachinistActionId.cs',
    'Jobs/Machinist/Data/MachinistStatusId.cs'
)

foreach ($relativePath in $localCatalogs) {
    $path = Join-Path $root $relativePath
    if (Test-Path -LiteralPath $path) {
        $failures.Add("MCH job code must not restore local action/status catalog: $relativePath")
    }
}

if ($docs -notmatch 'xivanalysis Helper catalog parity') {
    $failures.Add('Development docs must record xivanalysis Helper catalog parity for migrated MCH IDs.')
}

if ($docs -notmatch 'PileBunker' -or $docs -notmatch 'ArmPunch' -or $docs -notmatch 'CrownedCollider') {
    $failures.Add('Development docs must name the migrated MCH Helper action IDs.')
}

if ($failures.Count -gt 0) {
    throw ($failures -join [Environment]::NewLine)
}

Write-Host 'Validated Machinist Helper catalog parity and no local ID catalogs.'
