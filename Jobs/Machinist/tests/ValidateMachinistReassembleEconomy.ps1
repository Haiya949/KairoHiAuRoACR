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
    "private const int ReassembleChargePressureMs = 8_000",
    "private const int ReassembleRechargeMs = 55_000",
    "private const int ReassembleBurstSafetyMs = 3_000",
    "private const int ReassembleSequenceLookaheadPaddingMs = 250",
    "private static bool ShouldSpendReassembleForChargePressure\(\)",
    "private static bool CanRecoverReassembleBeforeNextBurstWindow\(\)",
    "private static bool ShouldReserveReassembleForCurrentBurstDrill\(uint actionId, int lookaheadMs\)",
    "private static uint\? GetReassembleAoeTargetActionId\(int lookaheadMs, bool shouldForceSpend\)",
    "private static bool ShouldUseReassembleOnScattergun\(int lookaheadMs, bool shouldForceSpend\)",
    "private static Spell\? GetReassembledAoeGcd\(\)"
)) {
    if ($helper -notmatch $pattern) {
        $failures.Add("MachinistSpellHelper.cs missing Reassemble economy pattern: $pattern")
    }
}

Assert-BodyContains $helper "public static Spell\? GetAoeGcd\(\)" @(
    "HasReassembled\(\)",
    "GetReassembledAoeGcd\(\)"
) "AOE GCD policy must consume Reassemble on legal Scattergun before normal AOE choices"

Assert-BodyContains $helper "public static Spell\? GetReassembleOffGcd\(\)" @(
    "GetReassembleSequenceTargetActionId\(\)",
    "WillNextGcdConsumeReassembleTarget\(targetActionId\.Value\)"
) "OffGCD Reassemble must pre-weave only for the next consuming GCD"

Assert-BodyContains $helper "private static uint\? GetReassembleTargetActionId\(int lookaheadMs\)" @(
    "var shouldForceSpend = ShouldSpendReassembleForChargePressure\(\)",
    "var hasExcavatorTarget = IsReadyForReassembleTarget\(ActionId\.Excavator\)",
    "if \(hasExcavatorTarget\)[\s\S]*return ActionId\.Excavator;",
    "!shouldForceSpend && !ShouldDumpReassembleDrillForTimeline\(\) && ShouldReserveReassembleForNextBurstWindow\(\)",
    "!shouldForceSpend && !ShouldDumpReassembleDrillForTimeline\(\) && ShouldReserveReassembleForExcavator\(\)",
    "GetReassembleAoeTargetActionId\(lookaheadMs, shouldForceSpend\)"
) "Reassemble target selection must preserve burst Drill, protect odd-minute Excavator, and allow legal AOE spend"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "ShouldReserveReassembleForCurrentBurstDrill\(ActionId\.Drill, lookaheadMs\)" "Reassemble selector must not short-circuit burst Drill protection by passing Drill into the candidate-action guard"

Assert-BodyContains $helper "private static uint\? GetReassembleTargetActionId\(int lookaheadMs\)" @(
    "foreach \(var actionId in ReassembleTargetPriority\)",
    "!shouldForceSpend && !ShouldDumpReassembleDrillForTimeline\(\) && ShouldReserveReassembleForCurrentBurstDrill\(actionId, lookaheadMs\)",
    "continue;",
    "if \(IsReadyForReassembleTarget\(actionId\) \|\| IsReassembleTargetWithin\(actionId, lookaheadMs\)\)",
    "return actionId;"
) "Reassemble selector must protect current-burst Drill while considering each non-Drill candidate"

Assert-BodyContains $helper "private static bool ShouldReserveReassembleForExcavator\(\)" @(
    "CanRecoverReassembleBeforeNextBurstWindow\(\)",
    "ActionId\.ChainSaw",
    "ReassembleExcavatorReserveMs"
) "Odd-minute Excavator hold must release when Reassemble can recover before the next burst"

Assert-BodyContains $helper "private static bool ShouldReserveReassembleForNextBurstWindow\(\)" @(
    "IsInTwoMinuteBurstWindow\(\)",
    "GetTimeToNextTwoMinuteBurstWindow\(\)",
    "ReassembleRechargeMs \+ ReassembleBurstSafetyMs"
) "Next-burst Reassemble reserve must use the visible burst window, not the later anchor only"

Assert-BodyContains $helper "private static bool ShouldReserveReassembleForCurrentBurstDrill\(uint actionId, int lookaheadMs\)" @(
    "IsInTwoMinuteBurstWindow\(\)",
    "HasActiveWildfirePackage\(\)",
    "actionId == ActionId\.Drill",
    "IsReadyForReassembleTarget\(ActionId\.Drill\)",
    "IsReassembleTargetWithin\(ActionId\.Drill, lookaheadMs\)"
) "Current burst must preserve Reassemble for the burst Drill until Wildfire is active"

Assert-BodyContains $helper "private static bool CanRecoverReassembleBeforeNextBurstWindow\(\)" @(
    "IsInTwoMinuteBurstWindow\(\)",
    "GetTimeToNextTwoMinuteBurstWindow\(\)",
    "ReassembleRechargeMs \+ ReassembleBurstSafetyMs"
) "Reassemble recovery helper must compare against the next burst window"

Assert-BodyContains $helper "private static bool ShouldUseReassembleOnScattergun\(int lookaheadMs, bool shouldForceSpend\)" @(
    "QTHelper\.IsEnabled\(QTKey\.Aoe\)",
    "LevelAtLeast\(82\)",
    "GetEnemyCountNearTarget\(5f\)",
    "GetAoeFillerTargetThreshold\(ActionId\.Scattergun\)",
    "!shouldForceSpend && !ShouldDumpReassembleDrillForTimeline\(\)",
    "IsReadyForReassembleTarget\(ActionId\.Scattergun\)"
) "Reassemble may be spent on Scattergun only for explicit AOE pressure or timeline dump"

Assert-BodyContains $helper "private static Spell\? GetReassembledAoeGcd\(\)" @(
    "ActionId\.Scattergun",
    "GetAoeFillerTargetThreshold\(ActionId\.Scattergun\)",
    "TargetSpell\(ActionId\.Scattergun\)"
) "Reassembled AOE GCD must choose Scattergun explicitly"

Assert-BodyContains $helper "private static bool WillNextGcdConsumeReassembleTarget\(uint actionId\)" @(
    "ActionId\.Scattergun",
    "GetReassembledAoeGcd\(\)"
) "Reassemble preweave must recognize Scattergun as a consuming next GCD"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist" "Reassemble migration must not leak old ACR APIs or local ID catalogs"

if ($failures.Count -gt 0) {
    Write-Host "Machinist Reassemble economy validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist Reassemble economy validation passed."
