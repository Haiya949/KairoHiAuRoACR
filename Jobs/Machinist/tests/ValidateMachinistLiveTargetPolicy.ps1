param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
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

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add("$Message`: $Pattern")
    }
}

function Assert-BodyContains {
    param(
        [string]$Text,
        [string]$SignaturePattern,
        [string[]]$Patterns,
        [string]$Message
    )

    $match = [regex]::Match(
        $Text,
        "$SignaturePattern\s*\{(?<body>.*?)\n    \}",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        $failures.Add("Could not find body: $Message")
        return
    }

    foreach ($pattern in $Patterns) {
        if ($match.Groups["body"].Value -notmatch $pattern) {
            $failures.Add("$Message missing pattern: $pattern")
        }
    }
}

function Assert-NotContains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -match $Pattern) {
        $failures.Add("$Message`: $Pattern")
    }
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

Assert-Contains $helper "using OmenTools\.Dalamud\.Services\.ObjectTable\.Abstractions\.ObjectKinds;" "Live target checks must use Dalamud object interfaces exposed by HiAuRo"

Assert-BodyContains $helper "private static bool HasTarget\(\)" @(
    "GetCurrentTarget\(\) is not null"
) "MCH target gate must share the live target helper"

Assert-BodyContains $helper "private static IBattleChara\? GetCurrentTarget\(\)" @(
    "global::HiAuRo\.Data\.Target\.Current is IBattleChara target",
    "target\.CurrentHp > 0",
    "target\.IsDead != true"
) "MCH target gate must reject stale/dead target objects, not only null targets"

foreach ($signature in @(
    "public static Spell\? GetAoeGcd\(\)",
    "public static Spell\? GetOverheatedGcd\(\)",
    "public static Spell\? GetStrongGcd\(\)",
    "public static Spell\? GetBaseComboGcd\(\)",
    "public static Spell\? GetWildfireOffGcd\(\)",
    "public static Spell\? GetBarrelStabilizerOffGcd\(\)",
    "public static Spell\? GetHyperchargeOffGcd\(\)",
    "public static Spell\? GetQueenOffGcd\(\)",
    "public static Spell\? GetQueenOverdriveOffGcd\(\)",
    "public static Spell\? GetReassembleOffGcd\(\)",
    "public static Spell\? GetGaussRoundOffGcd\(\)"
)) {
    Assert-BodyContains $helper $signature @(
        "!HasTarget\(\)"
    ) "All target-dependent MCH GCD/oGCD paths must share the live-target gate"
}

Assert-BodyContains $helper "private static bool CanUseBurstResource\(\)" @(
    "!HasTarget\(\)",
    "ShouldUseDumpResources\(\)",
    "IsForceBurstActive\(\)"
) "Burst and dump permission must keep the live-target gate before resource release"

Assert-BodyContains $helper "private static bool CanUseResourceForOvercap\(\)" @(
    "HasTarget\(\)"
) "Overcap spending must require a live Runtime target"

Assert-NotContains $helper "Core\\.Me\\.GetCurrTarget|TargetHelper\\.GetNearbyEnemyCount|AEAssist|MachinistActionId|MachinistStatusId" "Live-target policy must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist live target policy validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist live target policy validation passed."
