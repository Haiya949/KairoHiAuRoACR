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

$gaussBody = Get-Body $helper "public static Spell\? GetGaussRoundOffGcd\(\)" "Checkmate/Double Check policy"
Assert-NotContains $gaussBody "ShouldHoldCheckmateDoubleCheckForLoopBurst" "Checkmate/Double Check must not use a hidden loop-burst hold"
Assert-Contains $gaussBody "spell\.Charges >= 2" "Checkmate/Double Check must keep the original natural release at two charges"
Assert-Order $gaussBody @(
    "if (ShouldDumpCheckmateDoubleCheckForTimeline())",
    "if (ShouldReserveFullMetalWildfireWeaves())",
    "if (IsOverheated() || ShouldUseDumpResources() || spell.Charges >= 2)"
) "Checkmate/Double Check should keep timeline dump and Full Metal weave reserve before the natural two-charge release"

Assert-Contains $helper "private const int LoopAirAnchorBatteryReserveLeadMs = 30_000" "Loop battery reserve must cover the 1:40 pre-120s Queen/Rook leak"
Assert-Contains $helper "_lastLoopAirAnchorAnchorMs" "Loop battery reserve must track Air Anchor per two-minute anchor"
Assert-Contains $helper "TrackLoopAirAnchorAction\(actionId\)" "Issued/combat action tracking must update the Air Anchor marker"

$trackAirAnchorBody = Get-Body $helper "private static void TrackLoopAirAnchorAction\(uint actionId\)" "loop Air Anchor tracker"
Assert-Contains $trackAirAnchorBody "actionId != ActionId\.AirAnchor" "Loop Air Anchor tracker must only record Air Anchor"
Assert-Contains $trackAirAnchorBody "GetLoopOpeningComboAnchorMs\(\)" "Loop Air Anchor tracker must bind to the rolling two-minute anchor"
Assert-Contains $trackAirAnchorBody "_lastLoopAirAnchorAnchorMs = anchor\.Value" "Loop Air Anchor tracker must mark the anchor as Air Anchor handled"

$reserveBatteryBody = Get-Body $helper "private static bool ShouldReserveBatteryForLoopAirAnchor\(\)" "loop Air Anchor battery reserve"
Assert-Contains $reserveBatteryBody "GetLoopOpeningComboAnchorMs\(\)" "Battery reserve must follow the loop opening anchor"
Assert-Contains $reserveBatteryBody "HasLoopAirAnchorForAnchor\(anchor\.Value\)" "Battery reserve must stop after Air Anchor lands"
Assert-Contains $reserveBatteryBody "ActionId\.AirAnchor" "Battery reserve must specifically wait for Air Anchor"
Assert-Contains $reserveBatteryBody "LoopAirAnchorBatteryReserveLeadMs" "Battery reserve must use the Air Anchor reserve lead"

$spendBatteryBody = Get-Body $helper "private static bool ShouldSpendBatteryAfterLoopAirAnchor\(\)" "post-Air Anchor battery spender"
Assert-Contains $spendBatteryBody "GetLoopOpeningComboAnchorMs\(\)" "Post-Air Anchor spend must follow the loop opening anchor"
Assert-Contains $spendBatteryBody "HasLoopAirAnchorForAnchor\(anchor\.Value\)" "Post-Air Anchor spend must require Air Anchor for that anchor"

$queenBody = Get-Body $helper "public static Spell\? GetQueenOffGcd\(\)" "Queen/Rook battery policy"
Assert-Order $queenBody @(
    "var shouldSpendBatteryAfterLoopAirAnchor = ShouldSpendBatteryAfterLoopAirAnchor();",
    "var shouldSpendBatteryByBudget = ShouldSpendBatteryByBudget();",
    "if (ShouldHoldBatteryForTimeline())",
    "if (ShouldReserveBatteryForLoopAirAnchor())",
    "if (ShouldReserveFullMetalWildfireWeaves())",
    "if (ShouldUseDumpResources() || IsForceBurstActive() || shouldSpendBatteryAfterLoopAirAnchor || shouldSpendBatteryByBudget || CanUseBurstResource())"
) "Queen/Rook policy must reserve battery until loop Air Anchor, then spend after Air Anchor before normal burst-resource fallback"

Assert-Contains $docs "Checkmate / Double Check.*Charges >= 2" "Development docs must record the natural Checkmate/Double Check release"
Assert-Contains $docs "1:40.*Queen/Rook" "Development docs must record the 1:40 pre-120s Queen/Rook leak guard"
Assert-Contains $docs "120s Air Anchor.*Queen/Rook" "Development docs must record Queen/Rook after the 120s Air Anchor"
Assert-Contains $docs "maximize.*Battery" "Development docs must record the post-Air Anchor max battery intent"

if ($failures.Count -gt 0) {
    Write-Host "Machinist loop battery/ammo validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist loop battery/ammo validation passed."
