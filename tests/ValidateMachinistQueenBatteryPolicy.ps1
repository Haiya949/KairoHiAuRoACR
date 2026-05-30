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

Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "BatteryBurstSpendThreshold\s*\{\s*get;\s*set;\s*\}\s*=\s*50" "MCH battery policy must keep the 50 gauge summon floor"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "BatteryOvercapSpendThreshold\s*\{\s*get;\s*set;\s*\}\s*=\s*90" "MCH battery policy must keep the 90 gauge overcap pressure line"

Assert-BodyContains $helper "public static Spell\? GetQueenOffGcd\(\)" @(
    "if \(!HasTarget\(\) \|\| IsRobotActive\(\) \|\| !LevelAtLeast\(40\)\)",
    "GetBattery\(\) < _settings\.BatteryBurstSpendThreshold",
    "IsForbidBurstActive\(\)",
    "ShouldReleaseBatteryForTimeline\(\)",
    "ShouldHoldBatteryForTimeline\(\)",
    "var shouldSpendBatteryAfterLoopAirAnchor = ShouldSpendBatteryAfterLoopAirAnchor\(\)",
    "var shouldSpendBatteryByBudget = ShouldSpendBatteryByBudget\(\)",
    "var minWeaveMs = shouldSpendBatteryAfterLoopAirAnchor \|\| shouldSpendBatteryByBudget \? 650 : 800",
    "ShouldReserveBatteryForLoopAirAnchor\(\)",
    "ShouldReserveFullMetalWildfireWeaves\(\)",
    "ShouldUseDumpResources\(\) \|\| IsForceBurstActive\(\) \|\| shouldSpendBatteryAfterLoopAirAnchor \|\| shouldSpendBatteryByBudget \|\| CanUseBurstResource\(\)"
) "Queen summon must follow HiAuRo battery, burst, hold, dump, and weave-reserve policy"

$queen = [regex]::Match(
    $helper,
    "public static Spell\? GetQueenOffGcd\(\)\s*\{(?<body>.*?)\n    \}",
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($queen.Success) {
    $body = $queen.Groups["body"].Value
    Assert-Order $body @(
        "if (IsForbidBurstActive())",
        "if (ShouldReleaseBatteryForTimeline())",
        "var shouldSpendBatteryAfterLoopAirAnchor = ShouldSpendBatteryAfterLoopAirAnchor();",
        "var shouldSpendBatteryByBudget = ShouldSpendBatteryByBudget();",
        "if (ShouldHoldBatteryForTimeline())",
        "if (ShouldReserveBatteryForLoopAirAnchor())",
        "if (ShouldReserveFullMetalWildfireWeaves())"
    ) "Queen policy must respect ForbidBurst first, timeline release second, then battery pressure before hold and Full Metal reserve"
}

Assert-BodyContains $helper "private static bool ShouldSpendBatteryByBudget\(\)" @(
    "GetBattery\(\) >= _settings\.BatteryOvercapSpendThreshold",
    "MachinistResourcePlanner\.ShouldSpendBatteryBeforeBurst",
    "GetTimeToNextTwoMinuteBurstAnchor\(\)"
) "Battery budget must use overcap pressure and the migrated 120s resource planner"

Assert-BodyContains $helper "private static bool ShouldSpendBatteryAfterLoopAirAnchor\(\)" @(
    "GetLoopOpeningComboAnchorMs\(\)",
    "HasLoopAirAnchorForAnchor\(anchor\.Value\)"
) "Battery policy must spend the saved battery after the loop Air Anchor"

Assert-BodyContains $helper "public static Spell\? GetQueenOverdriveOffGcd\(\)" @(
    "IsRobotActive\(\)",
    "ShouldReleaseBatteryForTimeline\(\)",
    "CanWeave\(\)",
    "LevelAtLeast\(80\) \? ActionId\.QueenOverdrive : ActionId\.RookOverdrive",
    "SelfAbility\(actionId\)"
) "Queen/Rook overdrive must only fire during explicit release/dump windows and support low levels"

Assert-BodyContains $helper "private static Spell\? BuildQueenSpell\(\)" @(
    "LevelAtLeast\(80\) \? ActionId\.AutomatonQueen : ActionId\.RookAutoturret",
    "TargetAbility\(actionId\)",
    "spell\.IsReadyWithCanCast\(\)"
) "Queen summon must use Helper action IDs and support Rook below level 80"

Assert-Contains "Jobs/Machinist/Burst/MachinistResourcePlanner.cs" "public static bool ShouldSpendBatteryBeforeBurst" "Battery policy must keep the migrated resource planner"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "MachinistActionId|MachinistStatusId|Kairo\.Machinist|AEAssist" "Queen battery policy must not leak old ACR APIs or local ID catalogs"

if ($failures.Count -gt 0) {
    Write-Host "Machinist Queen battery validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist Queen battery validation passed."
