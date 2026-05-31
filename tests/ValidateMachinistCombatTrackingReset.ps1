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

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$handler = Read-File "Jobs/Machinist/MachinistRotationEventHandler.cs"

Assert-BodyContains $handler "public void OnResetBattle\(\)" @(
    "MachinistSpellHelper\.Reset\(\)"
) "MCH event handler must clear combat tracking on Runtime battle reset"

Assert-BodyContains $handler "public void OnTerritoryChanged\(\)" @(
    "MachinistSpellHelper\.Reset\(\)"
) "MCH event handler must clear combat tracking on territory change"

Assert-BodyContains $helper "public static void Reset\(\)" @(
    "_currentBattleTimeMs = 0",
    "ResetCombatTracking\(\)"
) "Full reset must preserve the battle-time reset and delegate combat state clearing"

Assert-BodyContains $helper "private static void ResetCombatTracking\(\)" @(
    "_firstPostOpenerBurstAnchorMs = null",
    "_lastWildfirePackageStartedAtMs = null",
    "_lastHyperchargePackageStartedAtMs = null",
    "_lastFullMetalFieldStartedAtMs = null",
    "_robotActiveUntilMs = 0",
    "_lastRecordedActionId = 0",
    "_lastRecordedActionAtMs = 0",
    "CombatActionLastUsedAtMs\.Clear\(\)",
    "CombatActionUseCounts\.Clear\(\)"
) "Combat tracking reset must clear every stateful action/burst estimate used by core loop policy"

Assert-BodyContains $helper "public static void UpdateBattleTime\(int battleTimeMs\)" @(
    "_currentBattleTimeMs > 5_000",
    "next <= 1_000",
    "ResetCombatTracking\(\)"
) "Battle-time rewind must clear stale action tracking without depending on framework target state"

Assert-BodyContains $helper "public static void RecordCombatActionUse\(uint actionId\)" @(
    "if \(_lastRecordedActionId == actionId && now - _lastRecordedActionAtMs < 250\)",
    "if \(ShouldResetStaleCombatTrackingOnPull\(actionId\)\)",
    "ResetCombatTracking\(\)",
    "var actionBattleTimeMs = GetAcrBattleTimeMs\(now\);",
    "TrackBurstPackageAction\(actionId, actionBattleTimeMs\)",
    "CombatActionUseCounts\[actionId\]",
    "CombatActionLastUsedAtMs\[actionId\] = actionBattleTimeMs"
) "First pull action must be able to drop stale previous-combat action tracking before recording the new action"

Assert-BodyContains $helper "private static bool ShouldResetStaleCombatTrackingOnPull\(uint actionId\)" @(
    "_currentBattleTimeMs > 2_000",
    "actionId != ActionId\.Reassemble",
    "CombatActionUseCounts\.Count > 0",
    "CombatActionLastUsedAtMs\.Count > 0",
    "_firstPostOpenerBurstAnchorMs is not null",
    "_lastWildfirePackageStartedAtMs is not null",
    "_lastHyperchargePackageStartedAtMs is not null",
    "_lastFullMetalFieldStartedAtMs is not null",
    "_robotActiveUntilMs > 0"
) "Early Reassemble may reset stale previous-pull state only before the ACR combat clock has started"

Assert-Contains $helper "ActionId\.Reassemble" "Stale opener reset must use the Helper action alias, not a local ID catalog"
Assert-Contains $helper "if \(_acrCombatClockStartedAtTick is not null\)\s*return false;" "Active opener combat clock must prevent Reassemble stale-reset"
Assert-Contains (Read-File "docs/DEVELOPMENT.md") "opener second Reassemble must not reset ACR combat clock" "Development docs must record the opener Reassemble reset guard"

if ($failures.Count -gt 0) {
    Write-Host "Machinist combat tracking reset validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist combat tracking reset validation passed."
