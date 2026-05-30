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
$docs = Read-File "docs/DEVELOPMENT.md"

$anchorBody = Get-Body $helper "private static int GetCurrentBurstAnchorMs\(\)" "current burst anchor"
Assert-Contains $anchorBody "_firstPostOpenerBurstAnchorMs \?\? _settings\.FirstBurstAnchorMs" "Timeline release re-anchor must remain available"

$trackBody = Get-Body $helper "private static void TrackBurstPackageAction\(uint actionId\)" "burst package tracker"
Assert-Contains $trackBody "_lastWildfirePackageStartedAtMs = _currentBattleTimeMs" "Wildfire history must still be tracked"
Assert-NotContains $trackBody "_firstPostOpenerBurstAnchorMs = _currentBattleTimeMs \+ 120_000" "Fight 4: opener Wildfire at 11.349s must not push the 120s loop Wildfire to 2:24"

$loopAnchorBody = Get-Body $helper "private static int\? GetLoopOpeningComboAnchorMs\(\)" "loop opening combo anchor"
Assert-Contains $loopAnchorBody "GetTimeToNextTwoMinuteBurstAnchor\(\)" "Loop combo still follows the rolling two-minute anchor"
Assert-Contains $loopAnchorBody "LoopOpeningComboLeadMs" "Loop combo should only add one ordinary GCD before the fixed 120s package"

$barrelBody = Get-Body $helper "public static Spell\? GetBarrelStabilizerOffGcd\(\)" "Barrel Stabilizer policy"
Assert-Contains $barrelBody "CanUseLoopBurstPackage\(\)" "Fight 4: Barrel Stabilizer must be allowed around the 120s package, not wait until 2:18"

$batteryReserveBody = Get-Body $helper "private static bool ShouldReserveBatteryForLoopAirAnchor\(\)" "loop Air Anchor battery reserve"
Assert-Contains $batteryReserveBody "LoopAirAnchorBatteryReserveLeadMs" "Fight 4: battery reserve must cover the pre-120s Queen/Rook leak"
Assert-Contains $batteryReserveBody "HasLoopAirAnchorForAnchor\(anchor\.Value\)" "Battery reserve must stop after the 120s Air Anchor lands"

Assert-Contains $docs "Fight 4" "Development docs must record the FFLogs fight 4 regression"
Assert-Contains $docs "2:24 Wildfire" "Development docs must record the delayed Wildfire symptom"
Assert-Contains $docs "2:10.*ordinary combo" "Development docs must record the ordinary combo symptom"
Assert-Contains $docs "1:40.*Queen/Rook" "Development docs must record the early Queen/Rook symptom"

if ($failures.Count -gt 0) {
    Write-Host "Machinist FFLogs fight 4 regression validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist FFLogs fight 4 regression validation passed."
