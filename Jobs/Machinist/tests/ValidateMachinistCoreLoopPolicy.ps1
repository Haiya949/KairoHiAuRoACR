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

function Assert-Order {
    param(
        [string]$Text,
        [string[]]$Tokens,
        [string]$Message
    )

    $position = -1
    foreach ($token in $Tokens) {
        $next = $Text.IndexOf($token, $position + 1, [StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message; missing or out of order token: $token")
            return
        }

        $position = $next
    }
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$opener = Read-File "Jobs/Machinist/Opener/MachinistOpener.cs"

Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "MinLevel\s*=\s*1" "MCH rotation must keep low-level support"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "public uint Level => 58;" "MCH opener should start only when Drill exists"

Assert-BodyContains $opener "private static bool CanStart\(\)" @(
    "!MachinistSpellHelper\.ShouldStopActions\(\)",
    "IsGcdUnlocked\(ActionId\.Drill\)",
    "!IsAirAnchorFirstOpenerActive\(\) \|\| IsGcdUnlocked\(ActionId\.AirAnchor\)"
) "MCH opener must not start without the first legal opener GCD"

foreach ($pattern in @(
    "ActionId\.Drill => LevelAtLeast\(58\)",
    "ActionId\.AirAnchor => LevelAtLeast\(76\)",
    "ActionId\.ChainSaw => LevelAtLeast\(90\)",
    "ActionId\.Excavator => LevelAtLeast\(96\)",
    "ActionId\.FullMetalField => LevelAtLeast\(100\)"
)) {
    if ($opener -notmatch $pattern) {
        $failures.Add("MCH opener missing low-level unlock gate: $pattern")
    }
}

foreach ($signature in @(
    "private static void BuildChainSawSlot\(Slot slot\)",
    "private static void BuildExcavatorSlot\(Slot slot\)",
    "private static void BuildFullMetalFieldSlot\(Slot slot\)"
)) {
    Assert-BodyContains $opener $signature @(
        "PrepareOpenerSlot\(slot\)",
        "AddGcdIfUnlocked\(slot,"
    ) "Locked high-level opener steps must become empty native Slots instead of custom polling"
}

Assert-BodyContains $helper "public static Spell\? GetAoeGcd\(\)" @(
    "if \(!HasTarget\(\) \|\| !QTHelper\.IsEnabled\(QTKey\.Aoe\)\)",
    "HasReassembled\(\)",
    "GetReassembledAoeGcd\(\)",
    "LevelAtLeast\(82\) \? ActionId\.Scattergun : ActionId\.SpreadShot",
    "GetEnemyCountNearTarget\(5f\) < GetAoeFillerTargetThreshold\(fillerActionId\)",
    "ActionId\.AutoCrossbow",
    "ShouldUseBioblasterOnAoe\(\)",
    "ActionId\.Bioblaster"
) "MCH AOE loop must keep target guard, Reassemble Scattergun, Auto Crossbow, Bioblaster, and filler branches"

$aoe = [regex]::Match(
    $helper,
    "public static Spell\? GetAoeGcd\(\)\s*\{(?<body>.*?)\n    \}",
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($aoe.Success) {
    Assert-Order $aoe.Groups["body"].Value @(
        "if (IsOverheated())",
        "if (ShouldUseBioblasterOnAoe())",
        "var filler = BestAoeTargetSpell(fillerActionId);"
    ) "AOE priority must prefer Auto Crossbow, then Bioblaster refresh, then filler"
}

Assert-BodyContains $helper "private static bool ShouldUseBioblasterOnAoe\(\)" @(
    "var target = GetBestAoeTarget\(ActionId\.Bioblaster\)",
    "BestAoeTargetSpell\(ActionId\.Bioblaster\)",
    "target\.HasMyAura\(StatusId\.Bioblaster\)",
    "target\.GetAuraTimeLeft\(StatusId\.Bioblaster\) <= BioblasterRefreshSeconds"
) "Bioblaster must use Helper status IDs on the selected best AOE target"

Assert-BodyContains $helper "private static int GetAoeFillerTargetThreshold\(uint actionId\)" @(
    "actionId == ActionId\.Scattergun \? 4 : 3"
) "Scattergun must use the 4-target threshold while lower AOE filler keeps 3"

Assert-BodyContains $helper "private static Spell\? GetLowLevelHotShotGcd\(\)" @(
    "if \(LevelAtLeast\(76\)\)",
    "TargetSpell\(ActionId\.HotShot\)"
) "Low-level MCH strong GCD fallback must keep Hot Shot before Air Anchor"

Assert-BodyContains $helper "private static bool CanUseBurstResource\(\)" @(
    "ShouldStopActions\(\) \|\| !HasTarget\(\) \|\| IsForbidBurstActive\(\)",
    "!QTHelper\.IsEnabled\(BuiltinQt\.Burst\)",
    "ShouldUseDumpResources\(\) \|\| IsForceBurstActive\(\)",
    "ShouldUseTwoMinuteBurstPlan\(\)",
    "IsInTwoMinuteBurstWindow\(\)"
) "Burst resource gate must respect Hold, no target, ForbidBurst, Builtin Burst, dump, force, and high-end windows"

Assert-BodyContains $helper "private static bool CanUseResourceForOvercap\(\)" @(
    "!ShouldStopActions\(\)",
    "HasTarget\(\)",
    "QTHelper\.IsEnabled\(BuiltinQt\.Burst\)",
    "!IsForbidBurstActive\(\)"
) "Overcap spending must still require a target and visible Burst permission"

Assert-BodyContains $helper "private static bool ShouldUseTwoMinuteBurstPlan\(\)" @(
    "_settings\.IsHighEndMode"
) "Two-minute burst planning must stay on the main settings mode, not a hidden timer or QT"

foreach ($signature in @(
    "public static Spell\? GetWildfireOffGcd\(\)",
    "public static Spell\? GetBarrelStabilizerOffGcd\(\)",
    "public static Spell\? GetHyperchargeOffGcd\(\)",
    "public static Spell\? GetQueenOffGcd\(\)",
    "public static Spell\? GetReassembleOffGcd\(\)",
    "public static Spell\? GetGaussRoundOffGcd\(\)"
)) {
    Assert-BodyContains $helper $signature @(
        "!HasTarget\(\)"
    ) "Targeted oGCD policy must not fire while Runtime has no target"
}

Assert-BodyContains $helper "public static Spell\? GetQueenOverdriveOffGcd\(\)" @(
    "IsRobotActive\(\)",
    "ShouldReleaseBatteryForTimeline\(\)",
    "CanWeave\(\)",
    "LevelAtLeast\(80\) \? ActionId\.QueenOverdrive : ActionId\.RookOverdrive"
) "Robot overdrive must be explicit-release only and choose Rook below 80"

Assert-BodyContains $helper "private static Spell\? BuildQueenSpell\(\)" @(
    "LevelAtLeast\(80\) \? ActionId\.AutomatonQueen : ActionId\.RookAutoturret",
    "TargetAbility\(actionId\)"
) "Battery spender must choose Rook below 80 and Queen at 80+"

Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "using ActionId = HiAuRo\.Helper\.MCHHelper\.EN\.Skills;" "MCH helper must use HiAuRo.Helper skill IDs"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "using StatusId = HiAuRo\.Helper\.MCHHelper\.EN\.Buffs;" "MCH helper must use HiAuRo.Helper status IDs"
Assert-NotContains "Jobs/Machinist" "MachinistActionId|MachinistStatusId|AEAssist|Kairo\.Machinist" "MCH core loop must not leak old ACR APIs or local ID catalogs"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "SyncTimelineManagedQt|Core\.Me\.GetCurrTarget|TargetHelper\.GetNearbyEnemyCount|DynamicTargetSpell" "MCH core loop must not keep old AEAssist target/QT helpers"

if ($failures.Count -gt 0) {
    Write-Host "Machinist core loop validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist core loop validation passed."
