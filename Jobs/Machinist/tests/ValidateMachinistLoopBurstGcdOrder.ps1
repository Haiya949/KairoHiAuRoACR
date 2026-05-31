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
$docs = Read-File "Jobs/Machinist/docs/DEVELOPMENT.md"

Assert-NotContains $helper "LoopOpeningComboLeadMs|ShouldDelayStrongGcdForLoopOpeningCombo|TrackLoopOpeningComboAction|HasLoopOpeningComboForAnchor|_lastLoopOpeningComboAnchorMs" "Loop burst must not keep the removed first-GCD ordinary combo delay"
Assert-NotContains $helper "LoopBurstStrongGcdPriority|ShouldDelayFullMetalFieldForLoopBurst|FullMetalWildfireReadyLeadMs|TrackLoopBurstToolAction|HasLoopChainSawForAnchor|HasLoopExcavatorForAnchor" "Loop burst must not use the failed fight 9 package state machine"

Assert-InOrder $helper @(
    "private static readonly uint[] StrongGcdPriority",
    "ActionId.Excavator",
    "ActionId.FullMetalField",
    "ActionId.ChainSaw",
    "ActionId.AirAnchor",
    "ActionId.Drill"
) "Strong GCD priority must match the old ACR single priority order"

$strongBody = Get-Body $helper "public static Spell\? GetStrongGcd\(\)" "strong GCD policy"
Assert-Contains $strongBody "foreach \(var actionId in GetStrongGcdPriority\(\)\)" "Strong GCD policy must use fixed 120s priority only inside the fixed 120s package"
Assert-NotContains $strongBody "ShouldDelayStrongGcdForLoopOpeningCombo" "Strong GCD policy must not force one ordinary combo before the loop Drill"

$readyStrongBody = Get-Body $helper "private static Spell\? GetReadyStrongGcd\(uint actionId\)" "ready strong GCD policy"
Assert-NotContains $readyStrongBody "ShouldDelayFullMetalFieldForLoopBurst" "Ready strong GCD policy must not hide Full Metal Field behind loop tool markers"

$nextStrongBody = Get-Body $helper "private static uint\? GetNextStrongGcdActionId\(\)" "next strong GCD probe"
Assert-Contains $nextStrongBody "foreach \(var actionId in GetStrongGcdPriority\(\)\)" "Next strong GCD probe must use the same fixed 120s priority switch as the GCD resolver"

Assert-NotContains $docs "120s loop first GCD.*ordinary combo" "Development docs must not keep the removed first-GCD ordinary combo rule"
Assert-Contains $docs "old ACR strong GCD priority.*Excavator -> Full Metal Field -> Chain Saw -> Air Anchor -> Drill" "Development docs must record the restored old ACR strong-GCD priority"
Assert-Contains $docs "27/3=9.*90 Battery" "Development docs must record the adjusted 120s battery math"

if ($failures.Count -gt 0) {
    Write-Host "Machinist loop burst GCD-order validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist loop burst GCD-order validation passed."
