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

function Assert-IndexBefore {
    param(
        [string]$Text,
        [string]$First,
        [string]$Second,
        [string]$Message
    )

    $firstIndex = $Text.IndexOf($First, [StringComparison]::Ordinal)
    $secondIndex = $Text.IndexOf($Second, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -gt $secondIndex) {
        $failures.Add($Message)
    }
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

Assert-Contains "Jobs/Machinist/Burst/MachinistBurstPlanner.cs" "public static class MachinistBurstPlanner" "MCH must migrate the old 120s burst planner as HiAuRo-native pure logic"
Assert-Contains "Jobs/Machinist/Burst/MachinistBurstPlanner.cs" "public const int BurstCycleMs = 120_000" "Burst planner must use the two-minute cycle"
Assert-Contains "Jobs/Machinist/Burst/MachinistBurstPlanner.cs" "IsInBurstWindow" "Burst planner must expose burst-window checks"
Assert-Contains "Jobs/Machinist/Burst/MachinistBurstPlanner.cs" "GetTimeToNextBurstWindow" "Burst planner must expose time-to-window checks"
Assert-Contains "Jobs/Machinist/Burst/MachinistBurstPlanner.cs" "GetTimeToNextBurstAnchor" "Burst planner must expose time-to-anchor checks"

foreach ($pattern in @(
    "public static class MachinistResourcePlanner",
    "public const int CycleGcdSlots = 48",
    "public const int OpenerCycleMajorGcdSlots = 15",
    "public const int WildfireBarrelWindowSlots = 3",
    "public const int OpenerCycleFillerSlots = 30",
    "public const int HeatPerComboGcd = 5",
    "public const int PaidHyperchargeHeatCost = 50",
    "public const int PaidHyperchargeComboSlots = 3",
    "public const int PaidHyperchargePreventedHeat = PaidHyperchargeComboSlots \* HeatPerComboGcd",
    "public const int PaidHyperchargeHeatRelief = PaidHyperchargeHeatCost \+ PaidHyperchargePreventedHeat",
    "public const int OpenerCycleComboHeat = OpenerCycleFillerSlots \* HeatPerComboGcd",
    "public const int OpenerCycleHeatAfterOnePaidHypercharge = OpenerCycleComboHeat - PaidHyperchargeHeatRelief",
    "public const int OpenerCycleToolBattery = 140",
    "public const int OpenerCycleComboBattery = 90",
    "public const int OpenerCycleBattery = OpenerCycleToolBattery \+ OpenerCycleComboBattery",
    "public const int PreBurstBudgetLookaheadMs = 45_000",
    "ShouldSpendHeatBeforeBurst",
    "ShouldSpendBatteryBeforeBurst",
    "GetPaidHyperchargeCountForCycle",
    "GetProjectedHeatAtNextBurst",
    "GetProjectedBatteryAtNextBurst"
)) {
    Assert-Contains "Jobs/Machinist/Burst/MachinistResourcePlanner.cs" $pattern "MCH must migrate 120s heat/battery resource-budget planner"
}

foreach ($pattern in @(
    "WildfirePreGcdClipWindowMs = 1_000",
    "WildfireBurstPackageLookaheadMs = 40_000",
    "PreWildfireOvercapHeatThreshold = 100",
    "PreWildfireOvercapHyperchargeMinCooldownMs = 20_000",
    "PreWildfireOvercapHyperchargeMaxCooldownMs = 30_000",
    "MachinistBurstPlanner\.IsInBurstWindow",
    "MachinistBurstPlanner\.GetTimeToNextBurstAnchor",
    "MachinistBurstPlanner\.GetTimeToNextBurstWindow",
    "MachinistResourcePlanner\.ShouldSpendHeatBeforeBurst",
    "MachinistResourcePlanner\.ShouldSpendBatteryBeforeBurst",
    "MachinistResourcePlanner\.GetProjectedHeatAtNextBurst",
    "private static bool CanUseWildfireBurstPackage\(\)",
    "private static bool ShouldDelayWildfireForBurstPackageTiming\(\)",
    "private static bool ShouldDelayHyperchargeForWildfireBurstPackage\(\)",
    "private static bool CanSpendPreWildfireOvercapHypercharge",
    "private static bool ShouldPreGcdWildfireForBurstPackage\(\)",
    "public static bool ShouldHoldGcdForWildfireBurstPackage\(\)",
    "private static bool ShouldUseHyperchargeBeforeWildfirePackage\(\)",
    "private static bool ShouldReserveFullMetalWildfireWeaves\(\)",
    "private static bool HasRecentFullMetalFieldForWildfirePackage\(\)",
    "private static bool HasRecentHyperchargeForWildfirePackage\(\)",
    "private static bool ShouldSpendBatteryByBudget\(\)"
)) {
    if ($helper -notmatch $pattern) {
        $failures.Add("MachinistSpellHelper.cs missing burst migration pattern: $pattern")
    }
}

Assert-BodyContains $helper "public static Spell\? GetWildfireOffGcd\(\)" @(
    "if \(!HasTarget\(\) \|\| !CanUseWildfireBurstPackage\(\)\)",
    "ShouldDelayWildfireUntilHyperchargeForBurstPackage\(\)",
    "ShouldDelayWildfireForBurstPackageTiming\(\)",
    "!CanWeave\(\) && !ShouldPreGcdWildfireForBurstPackage\(\)"
) "GetWildfireOffGcd must support the old Wildfire package timing"

Assert-BodyContains $helper "public static Spell\? GetHyperchargeOffGcd\(\)" @(
    "if \(!CanWeave\(\)\)",
    "ShouldDelayHyperchargeForWildfireBurstPackage\(\)",
    "var shouldUseActiveWildfireHypercharge = HasActiveWildfirePackage\(\)",
    "var shouldUseFullMetalWildfireHypercharge = ShouldUseHyperchargeBeforeWildfirePackage\(\)",
    "!shouldUseFullMetalWildfireHypercharge[\s\S]*ShouldFinishCleanShotComboBeforeHypercharge\(\)",
    "!shouldUseFullMetalWildfireHypercharge[\s\S]*ShouldDelayHyperchargeForToolCooldown\(\)",
    "!shouldUseFullMetalWildfireHypercharge[\s\S]*HasStrongGcdSoon",
    "!shouldUseActiveWildfireHypercharge[\s\S]*ShouldFinishCleanShotComboBeforeHypercharge\(\)",
    "!shouldUseActiveWildfireHypercharge[\s\S]*ShouldDelayHyperchargeForToolCooldown\(\)",
    "!shouldUseActiveWildfireHypercharge[\s\S]*HasStrongGcdSoon"
) "GetHyperchargeOffGcd must reserve and execute the Wildfire Hypercharge package"

Assert-IndexBefore $helper "ShouldDelayHyperchargeForWildfireBurstPackage" "ShouldDelayHyperchargeForToolCooldown" "Hypercharge must reserve Wildfire package before generic tool-cooldown delay."

Assert-BodyContains $helper "private static bool ShouldDelayHyperchargeForWildfireBurstPackage\(\)" @(
    "TargetSpell\(ActionId\.Wildfire\)",
    "ShouldUseHyperchargeBeforeWildfirePackage\(\)",
    "HasActiveWildfirePackage\(\)",
    "IsActionUnlockedForCooldownLookahead\(ActionId\.Wildfire\)",
    "CanSpendPreWildfireOvercapHypercharge\(wildfire\)",
    "wildfire\.CooldownMs <= WildfireBurstPackageLookaheadMs",
    "IsInTwoMinuteBurstWindow\(\)",
    "GetTimeToNextTwoMinuteBurstWindow\(\) > WildfireBurstPackageLookaheadMs",
    "CanUseResourceForOvercap\(\)"
) "ShouldDelayHyperchargeForWildfireBurstPackage must match the old burst-package reservation"

Assert-BodyContains $helper "private static bool ShouldDelayWildfireUntilHyperchargeForBurstPackage\(\)" @(
    "HasRecentFullMetalFieldForWildfirePackage\(\)",
    "!HasRecentHyperchargeForWildfirePackage\(\)"
) "Wildfire must wait for the planned Hypercharge weave after Full Metal Field"

Assert-BodyContains $helper "private static bool CanSpendPreWildfireOvercapHypercharge\([^)]*\)" @(
    "HasRecentPreBurstHypercharge\(\)",
    "MachinistResourcePlanner\.ShouldSpendHeatBeforeBurst",
    "wildfire\.CooldownMs >= PreWildfireOvercapHyperchargeMinCooldownMs",
    "GetHeat\(\) < PreWildfireOvercapHeatThreshold",
    "IsInTwoMinuteBurstWindow\(\)",
    "wildfire\.CooldownMs < PreWildfireOvercapHyperchargeMinCooldownMs",
    "wildfire\.CooldownMs > PreWildfireOvercapHyperchargeMaxCooldownMs"
) "Pre-Wildfire overcap Hypercharge must be bounded"

Assert-BodyContains $helper "private static bool HasRecentPreBurstHypercharge\(\)" @(
    "_lastHyperchargePackageStartedAtMs is null",
    "IsInTwoMinuteBurstWindow\(\)",
    "MachinistResourcePlanner\.PreBurstBudgetLookaheadMs"
) "Recent pre-burst Hypercharge tracking must use resource-planner lookahead"

Assert-BodyContains $helper "private static bool ShouldDelayWildfireForBurstPackageTiming\(\)" @(
    "CanUseWildfireBurstPackage\(\)",
    "GCDHelper\.GetGCDCooldown\(\) > WildfirePreGcdClipWindowMs",
    "GetNextStrongGcdActionId\(\) == ActionId\.FullMetalField"
) "Wildfire timing must support the Full Metal Field package"

Assert-BodyContains $helper "private static bool ShouldPreGcdWildfireForBurstPackage\(\)" @(
    "CanUseWildfireBurstPackage\(\)",
    "GetNextStrongGcdActionId\(\) == ActionId\.FullMetalField",
    "GCDHelper\.GetGCDCooldown\(\) > WildfirePreGcdClipWindowMs"
) "Wildfire may pre-weave for Full Metal Field without clipping"

Assert-BodyContains $helper "public static bool ShouldHoldGcdForWildfireBurstPackage\(\)" @(
    "TargetSpell\(ActionId\.Wildfire\)",
    "CanUseWildfireBurstPackage\(\)",
    "!wildfire\.IsReadyWithCanCast\(\)",
    "wildfire\.CooldownMs <= WildfirePreGcdClipWindowMs",
    "GetNextStrongGcdActionId\(\) == ActionId\.FullMetalField"
) "GCD resolvers must be able to hold briefly for Wildfire before Full Metal Field"

Assert-BodyContains $helper "private static bool ShouldSpendBatteryByBudget\(\)" @(
    "MachinistResourcePlanner\.ShouldSpendBatteryBeforeBurst",
    "GetTimeToNextTwoMinuteBurstAnchor\(\)",
    "GetBattery\(\)"
) "Queen battery spending must use the 120s budget planner"

$gcdResolverPaths = @(
    "Jobs/Machinist/Resolvers/GCD/MachinistAoeGcdResolver.cs",
    "Jobs/Machinist/Resolvers/GCD/MachinistStrongGcdResolver.cs",
    "Jobs/Machinist/Resolvers/GCD/MachinistBaseGcdResolver.cs"
)

foreach ($path in $gcdResolverPaths) {
    Assert-Contains $path "ShouldHoldGcdForWildfireBurstPackage\(\)[\s\S]*return -3;" "GCD resolver must briefly hold for the Full Metal Wildfire package"
}

foreach ($path in @(
    "Jobs/Machinist/Burst/MachinistBurstPlanner.cs",
    "Jobs/Machinist/Burst/MachinistResourcePlanner.cs",
    "Jobs/Machinist/MachinistSpellHelper.cs"
)) {
    Assert-NotContains $path "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist" "MCH burst migration must not leak old ACR APIs or local ID catalogs"
}

foreach ($pattern in @(
    "Wildfire package",
    "Full Metal Field -> Hypercharge -> Wildfire",
    "120s resource budget",
    "one paid Hypercharge per 120s budget",
    "230 Battery"
)) {
    Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" $pattern "Development docs must record the migrated MCH burst policy"
}

if ($failures.Count -gt 0) {
    Write-Host "Machinist burst migration validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist burst migration validation passed."
