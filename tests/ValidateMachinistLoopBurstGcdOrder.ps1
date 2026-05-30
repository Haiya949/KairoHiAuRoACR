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

function Assert-InOrder {
    param(
        [string]$Text,
        [string[]]$Tokens,
        [string]$Message
    )

    $position = -1
    foreach ($token in $Tokens) {
        $next = $Text.IndexOf($token, $position + 1, [StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message missing or out of order token: $token")
            return
        }

        $position = $next
    }
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$docs = Read-File "docs/DEVELOPMENT.md"

Assert-Contains $helper "private const int LoopOpeningComboLeadMs = 12_000" "Loop burst must define the first-GCD combo lead"
Assert-Contains $helper "private static readonly uint\[\] LoopBurstStrongGcdPriority" "Loop burst must have its own strong-GCD order"

Assert-InOrder $helper @(
    "private static readonly uint[] LoopBurstStrongGcdPriority",
    "ActionId.Drill",
    "ActionId.AirAnchor",
    "ActionId.ChainSaw",
    "ActionId.Excavator",
    "ActionId.FullMetalField"
) "Loop burst strong-GCD priority must be Drill -> Air Anchor -> Chain Saw -> Excavator -> Full Metal Field"

$strongBody = Get-Body $helper "public static Spell\? GetStrongGcd\(\)" "strong GCD policy"
Assert-Contains $strongBody "GetStrongGcdPriority\(\)" "Strong GCD policy must select loop-specific priority in the burst package"
Assert-Contains $strongBody "ShouldDelayStrongGcdForLoopOpeningCombo\(actionId\)" "Strong GCD policy must yield one base combo before the loop Drill"

$priorityBody = Get-Body $helper "private static IReadOnlyList<uint> GetStrongGcdPriority\(\)" "strong GCD priority selector"
Assert-Contains $priorityBody "CanUseLoopBurstPackage\(\)" "Strong GCD priority selector must use the loop burst package gate"
Assert-Contains $priorityBody "LoopBurstStrongGcdPriority" "Strong GCD priority selector must return the loop order during burst package"
Assert-Contains $priorityBody "StrongGcdPriority" "Strong GCD priority selector must keep the normal fallback order"

$delayBody = Get-Body $helper "private static bool ShouldDelayStrongGcdForLoopOpeningCombo\(uint actionId\)" "loop opening combo guard"
Assert-Contains $delayBody "actionId != ActionId\.Drill" "Only Drill should be delayed for the first loop combo"
Assert-Contains $delayBody "GetLoopOpeningComboAnchorMs\(\)" "Loop opening combo guard must bind the combo to one burst anchor"
Assert-Contains $delayBody "HasLoopOpeningComboForAnchor\(anchor\.Value\)" "Loop opening combo guard must stop after one ordinary combo"

$anchorBody = Get-Body $helper "private static int\? GetLoopOpeningComboAnchorMs\(\)" "loop opening combo anchor"
Assert-Contains $anchorBody "LoopOpeningComboLeadMs" "Loop opening combo anchor must use the 12s lead"
Assert-Contains $anchorBody "GetTimeToNextTwoMinuteBurstAnchor\(\)" "Loop opening combo anchor must follow the rolling two-minute anchor"

$trackBody = Get-Body $helper "private static void TrackLoopOpeningComboAction\(uint actionId\)" "loop opening combo tracker"
Assert-Contains $trackBody "IsBaseComboAction\(actionId\)" "Loop opening combo tracker must record only ordinary combo GCDs"
Assert-Contains $trackBody "_lastLoopOpeningComboAnchorMs = anchor\.Value" "Loop opening combo tracker must mark the anchor as handled"

Assert-Contains $helper "TrackLoopOpeningComboAction\(actionId\)" "Issued/combat action tracking must update the loop opening combo marker"

Assert-Contains $docs "120s loop first GCD.*ordinary combo" "Development docs must record the first-GCD ordinary combo rule"
Assert-Contains $docs "Drill -> Checkmate -> Double Check -> Air Anchor -> Barrel Stabilizer -> Queen/Rook -> Chain Saw -> Checkmate -> Reassemble -> Excavator -> Checkmate -> Double Check -> Full Metal Field -> Hypercharge -> Wildfire" "Development docs must record the user-approved loop burst order"
Assert-Contains $docs "27/3=9.*90 Battery" "Development docs must record the adjusted 120s battery math"

if ($failures.Count -gt 0) {
    Write-Host "Machinist loop burst GCD-order validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist loop burst GCD-order validation passed."
