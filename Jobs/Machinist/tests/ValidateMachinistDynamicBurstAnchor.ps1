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

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

foreach ($pattern in @(
    "private static int\? _firstPostOpenerBurstAnchorMs",
    "private static int\? _lastWildfirePackageStartedAtMs",
    "private static int\? _lastHyperchargePackageStartedAtMs",
    "private static int\? _lastFullMetalFieldStartedAtMs",
    "public static void ReanchorBurstCycleToCurrentTime\(\)",
    "private static void TrackBurstPackageAction\(uint actionId, int actionBattleTimeMs\)",
    "private static int GetCurrentBurstAnchorMs\(\)",
    "private static int GetTimeToNextTwoMinuteBurstAnchor\(\)",
    "private static int GetTimeToNextTwoMinuteBurstWindow\(\)"
)) {
    if ($helper -notmatch $pattern) {
        $failures.Add("MachinistSpellHelper.cs missing dynamic burst-anchor pattern: $pattern")
    }
}

Assert-BodyContains $helper "public static void RecordCombatActionUse\(uint actionId\)" @(
    "var actionBattleTimeMs = GetAcrBattleTimeMs\(now\);",
    "TrackBurstPackageAction\(actionId, actionBattleTimeMs\)",
    "CombatActionLastUsedAtMs\[actionId\] = actionBattleTimeMs"
) "Confirmed combat action tracking must seed burst-anchor state"

Assert-BodyContains $helper "public static void MarkCombatActionIssued\(uint actionId\)" @(
    "var actionBattleTimeMs = GetAcrBattleTimeMs\(now\);",
    "TrackBurstPackageAction\(actionId, actionBattleTimeMs\)",
    "CombatActionLastUsedAtMs\[actionId\] = actionBattleTimeMs"
) "Queued opener actions must also seed burst-anchor state before event confirmation"

Assert-BodyContains $helper "private static void ResetCombatTracking\(\)" @(
    "_firstPostOpenerBurstAnchorMs = null",
    "_lastWildfirePackageStartedAtMs = null",
    "_lastHyperchargePackageStartedAtMs = null",
    "_lastFullMetalFieldStartedAtMs = null"
) "Battle reset must clear dynamic burst-anchor and package tracking"

Assert-BodyContains $helper "public static void ReanchorBurstCycleToCurrentTime\(\)" @(
    "var battleTimeMs = GetAcrBattleTimeMs\(\)",
    "battleTimeMs <= 0",
    "_firstPostOpenerBurstAnchorMs = battleTimeMs"
) "Delayed-burst release must re-anchor later two-minute planning to the release time"

Assert-BodyContains $helper "private static void TrackBurstPackageAction\(uint actionId, int actionBattleTimeMs\)" @(
    "actionId == ActionId\.Wildfire",
    "_lastWildfirePackageStartedAtMs = actionBattleTimeMs",
    "actionId == ActionId\.Hypercharge",
    "_lastHyperchargePackageStartedAtMs = actionBattleTimeMs",
    "actionId == ActionId\.FullMetalField",
    "_lastFullMetalFieldStartedAtMs = actionBattleTimeMs"
) "Wildfire should only track package history; fixed 120s planning must not be shifted by opener Wildfire"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "_firstPostOpenerBurstAnchorMs = _currentBattleTimeMs \+ MachinistBurstPlanner\.BurstCycleMs" "Opener Wildfire must not shift the fixed 120s loop anchor"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "GetCurrentBurstWindowAnchor|ShouldDelayFullMetalFieldForLoopBurst" "Dynamic burst-anchor policy must not reintroduce the loop-package state machine that blocked fight 10 Wildfire"

Assert-BodyContains $helper "private static int GetCurrentBurstAnchorMs\(\)" @(
    "_firstPostOpenerBurstAnchorMs \?\? _settings\.FirstBurstAnchorMs"
) "Burst window helpers must use opener-derived anchor before the fallback setting"

Assert-BodyContains $helper "private static int GetTimeToNextTwoMinuteBurstAnchor\(\)" @(
    "MachinistBurstPlanner\.GetTimeToNextBurstAnchor",
    "GetCurrentBurstAnchorMs\(\)"
) "Resource budgets must use dynamic two-minute anchor"

Assert-BodyContains $helper "private static int GetTimeToNextTwoMinuteBurstWindow\(\)" @(
    "MachinistBurstPlanner\.GetTimeToNextBurstWindow",
    "GetCurrentBurstAnchorMs\(\)",
    "_settings\.BurstWindowLeadMs",
    "_settings\.BurstWindowTailMs"
) "Burst window checks must use dynamic two-minute anchor"

Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "MachinistSpellHelper\.ReanchorBurstCycleToCurrentTime\(\)" "Delayed burst release trigger must re-anchor the cycle"

Assert-Contains "docs/DEVELOPMENT.md" "opener Wildfire.*must not shift.*120s" "Development docs must record the fixed 120s anchor model"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "MachinistActionId|MachinistStatusId|Kairo\.Machinist|AEAssist" "Dynamic burst-anchor policy must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist dynamic burst-anchor validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist dynamic burst-anchor validation passed."
