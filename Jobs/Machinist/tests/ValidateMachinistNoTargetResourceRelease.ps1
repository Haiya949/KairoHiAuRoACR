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

Assert-BodyContains $helper "public static Spell\? GetQueenOverdriveOffGcd\(\)" @(
    "!HasTarget\(\)",
    "IsRobotActive\(\)",
    "ShouldReleaseBatteryForTimeline\(\)",
    "CanWeave\(\)",
    "LevelAtLeast\(80\) \? ActionId\.QueenOverdrive : ActionId\.RookOverdrive"
) "Robot overdrive release must still require a Runtime-selected target"

Assert-BodyContains $helper "public static Spell\? GetQueenOffGcd\(\)" @(
    "!HasTarget\(\)",
    "ShouldReleaseBatteryForTimeline\(\)",
    "BuildQueenSpell\(\)"
) "Battery release must not summon Rook/Queen without a Runtime-selected target"

Assert-BodyContains $helper "private static bool CanUseBurstResource\(\)" @(
    "!HasTarget\(\)",
    "ShouldUseDumpResources\(\)",
    "IsForceBurstActive\(\)"
) "Burst resource permission must keep no-target as the first hard gate"

Assert-BodyContains $helper "private static bool CanUseResourceForOvercap\(\)" @(
    "HasTarget\(\)"
) "Overcap spending must require a target"

Assert-BodyContains $helper "private static bool HasTarget\(\)" @(
    "GetCurrentTarget\(\) is not null"
) "No-target checks must share the live-target helper"

Assert-BodyContains $helper "private static IBattleChara\? GetCurrentTarget\(\)" @(
    "global::HiAuRo\.Data\.Target\.Current is IBattleChara target",
    "target\.CurrentHp > 0",
    "target\.IsDead != true"
) "No-target checks must use HiAuRo Runtime live-target state, not old plugin APIs"

Assert-NotContains $helper "Core\\.Me\\.GetCurrTarget|TargetHelper\\.GetNearbyEnemyCount|AEAssist|MachinistActionId|MachinistStatusId" "No-target resource-release policy must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist no-target resource release validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist no-target resource release validation passed."
