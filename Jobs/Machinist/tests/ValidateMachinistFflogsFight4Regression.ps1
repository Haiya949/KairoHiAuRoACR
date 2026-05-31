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

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add("$Message missing pattern: $Pattern")
    }
}

function Assert-NotContains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -match $Pattern) {
        $failures.Add("$Message unexpected pattern: $Pattern")
    }
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$docs = Read-File "Jobs/Machinist/docs/DEVELOPMENT.md"

$anchorBody = Get-Body $helper "private static int GetCurrentBurstAnchorMs\(\)" "current burst anchor"
Assert-Contains $anchorBody "_firstPostOpenerBurstAnchorMs \?\? _settings\.FirstBurstAnchorMs" "Timeline release re-anchor must remain available"

$trackBody = Get-Body $helper "private static void TrackBurstPackageAction\(uint actionId, int actionBattleTimeMs\)" "burst package tracker"
Assert-Contains $trackBody "_lastWildfirePackageStartedAtMs = actionBattleTimeMs" "Wildfire history must still be tracked"
Assert-NotContains $trackBody "_firstPostOpenerBurstAnchorMs = _currentBattleTimeMs \+ MachinistBurstPlanner\.BurstCycleMs" "Fight 11: opener Wildfire must not shift the fixed 120s loop anchor"

Assert-NotContains $helper "LoopOpeningComboLeadMs|ShouldDelayStrongGcdForLoopOpeningCombo|TrackLoopOpeningComboAction|ShouldDelayFullMetalFieldForLoopBurst|GetCurrentBurstWindowAnchor" "Fight 10: loop burst must not use package-state rules that can block Wildfire"

$barrelBody = Get-Body $helper "public static Spell\? GetBarrelStabilizerOffGcd\(\)" "Barrel Stabilizer policy"
Assert-Contains $barrelBody "CanUseBurstResource\(\)" "Barrel Stabilizer should use the old ACR burst-resource gate"
Assert-NotContains $barrelBody "ShouldPrioritizeBarrelAfterLoopAirAnchor|CanUseLoopBurstPackage" "Barrel Stabilizer must not depend on loop Air Anchor package state"

$queenBody = Get-Body $helper "public static Spell\? GetQueenOffGcd\(\)" "Queen/Rook policy"
Assert-NotContains $queenBody "ShouldPrioritizeBarrelAfterLoopAirAnchor|ShouldReserveBatteryForLoopAirAnchor|ShouldSpendBatteryAfterLoopAirAnchor" "Queen/Rook should not use loop Air Anchor package state after reverting to old ACR model"

$reassembleBody = Get-Body $helper "public static Spell\? GetReassembleOffGcd\(\)" "Reassemble policy"
Assert-NotContains $reassembleBody "ShouldPrioritizeBarrelAfterLoopAirAnchor" "Reassemble should not use loop Air Anchor package state after reverting to old ACR model"

$nextStrongBody = Get-Body $helper "private static uint\? GetNextStrongGcdActionId\(\)" "next strong GCD probe"
Assert-Contains $nextStrongBody "foreach \(var actionId in GetStrongGcdPriority\(\)\)" "Timing probes must use fixed 120s priority during the fixed package and old priority elsewhere"

Assert-Contains $docs "Fight 4" "Development docs must record the FFLogs fight 4 regression"
Assert-Contains $docs "2:24 Wildfire" "Development docs must record the delayed Wildfire symptom"
Assert-Contains $docs "2:10.*ordinary combo" "Development docs must record the ordinary combo symptom"
Assert-Contains $docs "Fight 10" "Development docs must record the FFLogs fight 10 regression"
Assert-Contains $docs "loop-package state machine" "Development docs must record why the loop-package state machine was removed"
Assert-Contains $docs "1:40.*Queen/Rook" "Development docs must record the early Queen/Rook symptom"

if ($failures.Count -gt 0) {
    Write-Host "Machinist FFLogs fight 4 regression validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist FFLogs fight 4 regression validation passed."
