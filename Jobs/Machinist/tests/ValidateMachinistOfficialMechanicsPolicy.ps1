param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function Read-File {
    param([string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $failures.Add("Missing file: $Path")
        return ""
    }

    if ((Get-Item -LiteralPath $fullPath) -is [System.IO.DirectoryInfo]) {
        $builder = New-Object System.Text.StringBuilder
        Get-ChildItem -LiteralPath $fullPath -Recurse -File |
            Where-Object { $_.Extension -eq ".cs" -and $_.FullName -notmatch '\\(docs|tests)\\' } |
            Sort-Object FullName |
            ForEach-Object {
                [void]$builder.AppendLine((Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8))
            }

        return $builder.ToString()
    }

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $text = Read-File $Path
    if ($text -notmatch $Pattern) {
        $failures.Add("$Message ($Path): $Pattern")
    }
}

function Assert-NotContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $text = Read-File $Path
    if ($text -match $Pattern) {
        $failures.Add("$Message ($Path): $Pattern")
    }
}

function Get-Body {
    param(
        [string]$Text,
        [string]$SignaturePattern,
        [string]$Message
    )

    $match = [regex]::Match(
        $Text,
        "$SignaturePattern\s*\{(?<body>.*?)\n    \}",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        $failures.Add("Could not find body: $Message")
        return ""
    }

    return $match.Groups["body"].Value
}

function Assert-BodyContains {
    param(
        [string]$Body,
        [string[]]$Patterns,
        [string]$Message
    )

    foreach ($pattern in $Patterns) {
        if ($Body -notmatch $pattern) {
            $failures.Add("$Message missing pattern: $pattern")
        }
    }
}

function Assert-BodyNotContains {
    param(
        [string]$Body,
        [string]$Pattern,
        [string]$Message
    )

    if ($Body -match $Pattern) {
        $failures.Add("$Message unexpected pattern: $Pattern")
    }
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$helperCatalog = Read-File "Helper/HiAuRo.Helper/MCHHelper.cs"

foreach ($pattern in @(
    "HotShot\s*=\s*2872",
    "Reassemble\s*=\s*2876",
    "BarrelStabilizer\s*=\s*7414",
    "Bioblaster\s*=\s*16499",
    "Scattergun\s*=\s*25786",
    "BlazingShot\s*=\s*36978",
    "DoubleCheck\s*=\s*36979",
    "Checkmate\s*=\s*36980",
    "FullMetalField\s*=\s*36982"
)) {
    if ($helperCatalog -notmatch $pattern) {
        $failures.Add("Helper MCH skill catalog missing official action ID: $pattern")
    }
}

foreach ($pattern in @(
    "Reassembled\s*=\s*851",
    "Bioblaster\s*=\s*1866",
    "ExcavatorReady\s*=\s*3865",
    "Hypercharged\s*=\s*3864",
    "FullMetalMachinist\s*=\s*3866"
)) {
    if ($helperCatalog -notmatch $pattern) {
        $failures.Add("Helper MCH buff catalog missing official status ID: $pattern")
    }
}

Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "using ActionId = HiAuRo\.Helper\.MCHHelper\.EN\.Skills;" "Official MCH mechanics must use Helper skill IDs"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "using StatusId = HiAuRo\.Helper\.MCHHelper\.EN\.Buffs;" "Official MCH mechanics must use Helper status IDs"
Assert-NotContains "Jobs/Machinist" "public const (?:uint|ushort) [A-Za-z][A-Za-z0-9_]* = \d+;|MachinistActionId|MachinistStatusId" "MCH job code must not keep local action/status ID catalogs"

$aoeBody = Get-Body $helper "public static Spell\? GetAoeGcd\(\)" "AOE official mechanics"
Assert-BodyContains $aoeBody @(
    "ActionId\.AutoCrossbow",
    "ShouldUseBioblasterOnAoe\(\)",
    "ActionId\.Bioblaster",
    "LevelAtLeast\(82\) \? ActionId\.Scattergun : ActionId\.SpreadShot"
) "AOE GCD policy must preserve official MCH AOE actions"

$bioblasterBody = Get-Body $helper "private static bool ShouldUseBioblasterOnAoe\(\)" "Bioblaster status refresh policy"
Assert-BodyContains $bioblasterBody @(
    "GetBestAoeTarget\(ActionId\.Bioblaster\)",
    "BestAoeTargetSpell\(ActionId\.Bioblaster\)",
    "target\.HasMyAura\(StatusId\.Bioblaster\)",
    "target\.GetAuraTimeLeft\(StatusId\.Bioblaster\) <= BioblasterRefreshSeconds"
) "Bioblaster refresh policy must use Helper target/status data"

$hotShotBody = Get-Body $helper "private static Spell\? GetLowLevelHotShotGcd\(\)" "low-level Hot Shot fallback"
Assert-BodyContains $hotShotBody @(
    "LevelAtLeast\(76\)",
    "TargetSpell\(ActionId\.HotShot\)",
    "spell\.IsReadyWithCanCast\(\)"
) "Low-level strong GCD fallback must use official Hot Shot before Air Anchor"

$barrelBody = Get-Body $helper "public static Spell\? GetBarrelStabilizerOffGcd\(\)" "Dawntrail Barrel Stabilizer policy"
Assert-BodyContains $barrelBody @(
    "SelfAbility\(ActionId\.BarrelStabilizer\)",
    "spell\.IsReadyWithCanCast\(\)"
) "Barrel Stabilizer policy must use the Helper action as a self ability"
Assert-BodyNotContains $barrelBody "GetHeat\(\)|50" "Barrel Stabilizer must not use the old 50 Heat requirement"

$strongStatusBody = Get-Body $helper "private static bool IsStrongGcdAvailableByStatus\(uint actionId\)" "strong GCD status gates"
Assert-BodyContains $strongStatusBody @(
    "ActionId\.Excavator => HelperRuntime\.HasStatus\(StatusId\.ExcavatorReady\)",
    "ActionId\.FullMetalField => HelperRuntime\.HasStatus\(StatusId\.FullMetalMachinist\)"
) "Dawntrail strong GCD gates must use official Helper status IDs"

$reassemblePriority = [regex]::Match(
    $helper,
    "private static readonly uint\[\] ReassembleTargetPriority\s*=\s*\[(?<body>.*?)\];",
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $reassemblePriority.Success) {
    $failures.Add("Could not find ReassembleTargetPriority")
} else {
    Assert-BodyContains $reassemblePriority.Groups["body"].Value @(
        "ActionId\.Excavator",
        "ActionId\.ChainSaw",
        "ActionId\.Drill",
        "ActionId\.AirAnchor"
    ) "Reassemble target priority must include official strong tool GCDs"
    Assert-BodyNotContains $reassemblePriority.Groups["body"].Value "ActionId\.FullMetalField" "Full Metal Field must not be a Reassemble target"
}

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Hot Shot" "Development docs must record the low-level Hot Shot fallback"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Bioblaster.*Scattergun" "Development docs must record official MCH AOE actions"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Barrel Stabilizer.*Hypercharged.*Full Metal Machinist" "Development docs must record Dawntrail Barrel Stabilizer mechanics"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Reassemble.*Full Metal Field" "Development docs must record why Full Metal Field is excluded from Reassemble targets"

if ($failures.Count -gt 0) {
    Write-Host "Machinist official mechanics validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist official mechanics validation passed."
