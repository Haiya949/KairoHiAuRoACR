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
$docs = Read-File "docs/DEVELOPMENT.md"

foreach ($pattern in @(
    "private static long\? _acrCombatClockStartedAtTick",
    "private static int _acrCombatClockStartedAtBattleTimeMs",
    "private static int GetAcrBattleTimeMs\(",
    "private static void StartAcrCombatClockIfNeeded\(uint actionId, long now\)",
    "private static bool ShouldStartAcrCombatClock\(uint actionId\)"
)) {
    Assert-Contains $helper $pattern "MCH must keep an ACR-owned combat clock independent from Runtime battle time"
}

$resetBody = Get-Body $helper "private static void ResetCombatTracking\(\)" "combat tracking reset"
Assert-Contains $resetBody "_acrCombatClockStartedAtTick = null" "Reset must clear the ACR combat clock"
Assert-Contains $resetBody "_acrCombatClockStartedAtBattleTimeMs = 0" "Reset must clear the ACR combat clock offset"

$recordBody = Get-Body $helper "public static void RecordCombatActionUse\(uint actionId\)" "confirmed action tracking"
Assert-Order $recordBody @(
    "var now = Environment.TickCount64;",
    "StartAcrCombatClockIfNeeded(actionId, now);",
    "var actionBattleTimeMs = GetAcrBattleTimeMs(now);",
    "TrackBurstPackageAction(actionId, actionBattleTimeMs);",
    "CombatActionLastUsedAtMs[actionId] = actionBattleTimeMs"
) "Confirmed actions must seed and use the ACR combat clock before storing action timing"

$markBody = Get-Body $helper "public static void MarkCombatActionIssued\(uint actionId\)" "issued action tracking"
Assert-Order $markBody @(
    "var now = Environment.TickCount64;",
    "StartAcrCombatClockIfNeeded(actionId, now);",
    "var actionBattleTimeMs = GetAcrBattleTimeMs(now);",
    "TrackBurstPackageAction(actionId, actionBattleTimeMs);",
    "CombatActionLastUsedAtMs[actionId] = actionBattleTimeMs"
) "Queued actions must seed and use the ACR combat clock before Runtime battle update catches up"

$startBody = Get-Body $helper "private static bool ShouldStartAcrCombatClock\(uint actionId\)" "ACR combat clock start gate"
Assert-Contains $startBody "actionId == ActionId\.Reassemble && _currentBattleTimeMs <= 0" "Prepull Reassemble must not start the ACR combat clock"

$fixedBody = Get-Body $helper "private static bool ShouldUseFixed120BurstPackage\(\)" "fixed 120 package"
Assert-Contains $fixedBody "var battleTimeMs = GetAcrBattleTimeMs\(\)" "Fixed 120 package must use the ACR combat clock"
Assert-NotContains $fixedBody "IsInBurstWindow\(\s*_currentBattleTimeMs" "Fixed 120 package must not use raw Runtime battle time"

$batteryHoldBody = Get-Body $helper "private static bool ShouldHoldBatteryForFixed120Burst\(\)" "fixed 120 battery hold"
Assert-Contains $batteryHoldBody "var battleTimeMs = GetAcrBattleTimeMs\(\)" "Fixed 120 battery hold must use the ACR combat clock"
Assert-NotContains $batteryHoldBody "GetTimeToNextBurstAnchor\(_currentBattleTimeMs" "Fixed 120 battery hold must not use raw Runtime battle time"

$anchorBody = Get-Body $helper "private static int GetCurrentFixed120BurstAnchorMs\(\)" "fixed 120 current anchor"
Assert-Contains $anchorBody "var battleTimeMs = GetAcrBattleTimeMs\(\)" "Fixed 120 current anchor must use the ACR combat clock"

Assert-Contains $docs "ACR combat clock" "Development docs must record the private MCH combat clock"
Assert-Contains $docs "Runtime.*battleTimeMs.*opener.*SlotExecutor" "Development docs must record why raw Runtime battle time is not used for fixed 120s MCH burst"

if ($failures.Count -gt 0) {
    Write-Host "Machinist ACR combat clock validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist ACR combat clock validation passed."
